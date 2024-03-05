#!/usr/bin/env bash
# ______________________________________________________________| locals |__ ;
TIMER_SELECTION=$(get_timer_selection)
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMER_DIR="/tmp/tmux-timer/$TIMER_SELECTION"
TIMER_FILE="$TIMER_DIR/time.txt"
TIMER_STATUS_FILE="$TIMER_DIR/status.txt"
TIMER_MINS_FILE="$TIMER_DIR/user_mins.txt"
CONFIG_DIR="$CURRENT_DIR/../timers"
TIMER_CONFIG="$CONFIG_DIR/$TIMER_SELECTION"

timer_selection="@timer_selection"
# _____________________________________________________________| methods |__ ;

source "$CURRENT_DIR/helpers.sh"

update_dirs() {
	if [ -z "$1" ]; then
		TIMER_SELECTION=$(get_timer_selection)
	else
		TIMER_SELECTION="$1"
	fi
	TIMER_DIR="/tmp/tmux-timer/$TIMER_SELECTION"
	TIMER_FILE="$TIMER_DIR/timer.txt"
	TIMER_STATUS_FILE="$TIMER_DIR/status.txt"
	TIMER_MINS_FILE="$TIMER_DIR/user_mins.txt"
	TIMER_CONFIG="$CURRENT_DIR/../timers/$TIMER_SELECTION.sh"
}

get_timer_selection() {
	get_tmux_option $timer_selection "-1"
}

get_seconds() {
	date +%s
}

minutes_to_seconds() {
	local minutes=$1
	echo $((minutes * 60))
}

format_seconds() {
	local total_seconds=$1
	local minutes=$((total_seconds / 60))
	local seconds=$((total_seconds % 60))

	if [ "$(get_timer_granularity)" == 'on' ]; then
		# Pad minutes and seconds with zeros if necessary
		# Formats seconds to MM:SS format
		# Example 1: 0  sec => 00:00
		# Example 2: 59 sec => 00:59
		# Example 3: 60 sec => 01:00
		printf "%02d:%02d\n" $minutes $seconds
	else
		local minutes_rounded=$(((total_seconds + 59) / 60))
		# Shows minutes only
		# Example 1: 0  sec => 0m
		# Example 2: 59 sec => 1m
		# Example 3: 60 sec => 1m
		printf "%sm" "$((minutes_rounded))"
	fi
}

if_inside_tmux() {
	test -n "${TMUX}"
}

send_notification() {
    debug "$(date): notification" "$DEBUG_FILE"
    if [ "$timer_notifications" == 'true' ]; then
        local title=$1
        local message=$2
        case "$OSTYPE" in
            linux* | *bsd*)
                if [[ $(uname -r) =~ "WSL" ]]; then
                    tmux display-popup -T "$title" -S "fg=#d79921" -h 20 -w 80 "echo $message"
                else
                    sound=$(get_sound)
                    notify-send -t 8000 "$title" "$message"
                    if [[ "$sound" == "on" ]]; then
                        beep -D 1500
                    fi
                fi
            ;;
            darwin*)
                    if [[ "$sound" == "off" ]]; then
                            osascript -e 'display notification "'"$message"'" with title "'"$title"'"'
                    else
                            osascript -e 'display notification "'"$message"'" with title "'"$title"'" sound name "'"$sound"'"'
                    fi
            ;;
        esac
    fi
}

clean_env() {
	remove_file "$TIMER_FILE"
	remove_file "$TIMER_STATUS_FILE"
}

timer_toggle() {
	# if [[ $TIMER_SELECTION -eq "-1" ]]
	# then
	# 	return 0
	# fi	

	if [ -f "$TIMER_FILE" ]; then
		if [[ $(cat $TIMER_STATUS_FILE) == "done" ]]; then
			timer_start
			return 0
		fi
		timer_cancel
		return 0
	fi

	timer_start
}

timer_start() {
	mkdir -p $TIMER_DIR
	timer_start_time=$(read_file "$TIMER_FILE")
	export timer_start_time

	debug "$(date): start" "$DEBUG_FILE"
	if [ $timer_start_completed == "true" ] && [ "$timer_start_time" -eq -1 ]; then
		clean_env
		write_to_file "done" "$TIMER_STATUS_FILE"
		write_to_file "$((get_seconds + $(minutes_to_seconds timer_duration_minutes)))" "$TIMER_FILE"
	else
		clean_env
		write_to_file "working" "$TIMER_STATUS_FILE"
		write_to_file "$(get_seconds)" "$TIMER_FILE"
	fi

	send_notification "🕓 $TIMER_SELECTION" "Your Timer is underway"
	if_inside_tmux && tmux refresh-client -S
	return 0
}

timer_cancel() {
	clean_env
	debug "$(date): cancel" "$DEBUG_FILE"
	if [[ -z $1 ]]; then
		send_notification "🕓 $TIMER_SELECTION" "Your Timer has been cancelled"
	fi
	if_inside_tmux && tmux refresh-client -S
	return 0
}

timer_status() {
	local status=" "
	local cnt=0
	for timer in $(ls -1 $CONFIG_DIR)
	do
		source $CONFIG_DIR/$timer
		update_dirs $(echo $timer | sed "s/\.sh//g")
		debug "$cnt-$TIMER_SELECTION" "$DEBUG_FILE"

		timer_start_time=$(read_file "$TIMER_FILE")
		export timer_start_time
		debug "$TIMER_FILE" "$DEBUG_FILE"

		timer_status=$(read_file "$TIMER_STATUS_FILE")
		export timer_status

		current_time=$(get_seconds)
		export current_time

		local difference=$((current_time - timer_start_time))
		# Timer workflow
		if [ $timer_type == "timer" ]; then
			if [ "$timer_start_time" -eq -1 ]; then
				debug "idle" "$DEBUG_FILE"
				status="${status}"
			elif [ $difference -ge "$(minutes_to_seconds "$timer_duration_minutes")" ]; then
				debug "done" "$DEBUG_FILE"
				if [ "$timer_status" == 'working' ]; then
					send_notification "🕑 $TIMER_SELECTION" "Password spray read!"
					write_to_file "done" "$TIMER_STATUS_FILE"
				fi

				status="${status} $timer_complete "
			else
				debug "working" "$DEBUG_FILE"
				timer_duration_secs=$(minutes_to_seconds "$timer_duration_minutes")
				time_left_formatted=$(format_seconds $((timer_duration_secs - difference)))

				status="${status}$timer_on $time_left_formatted "
			fi
		# Pomdoro workflow
		else
			if [ "$timer_start_time" -eq -1 ]; then
				debug "idle" "$DEBUG_FILE"
				status="${status}"
			elif [ $difference -ge "$(minutes_to_seconds $(($timer_duration_minutes + $timer_break_minutes)))" ]; then
				timer_start_time=-1
				status="${status}"
				if [ "$timer_status" == 'on_break' ]; then
					send_notification "🕑 $TIMER_SELECTION" "Get back to work"
					write_to_file "break_complete" "$TIMER_STATUS_FILE"
					if [ "$timer_auto_restart" = true ]; then
						timer_start
					else
						# Cancel the pomodoro and silence any notifications
						timer_cancel true
					fi
				fi
			elif [ $difference -ge "$(minutes_to_seconds "$timer_duration_minutes")" ]; then
				if [ "$timer_status" == "working" ]; then
					send_notification "🕑 $TIMER_SELECTION" "Take a quick break!"
					write_to_file "on_break" "$TIMER_STATUS_FILE"
				fi

				timer_duration_secs=$(minutes_to_seconds "$timer_duration_minutes")
				break_duration_seconds=$(minutes_to_seconds "$timer_break_minutes")
				time_left_seconds=$((-(difference - timer_duration_secs - break_duration_seconds)))
				time_left_formatted=$(format_seconds $time_left_seconds)

				status="${status}$timer_complete $time_left_formatted "
			else
				timer_duration_secs=$(minutes_to_seconds "$timer_duration_minutes")
				time_left_formatted=$(format_seconds $((timer_duration_secs - difference)))
				status="${status}$timer_on $time_left_formatted "
			fi
		fi
		cnt=$((cnt+1))
	done
	echo $status
}

main() {
	cmd=$1
	shift

	if [ "$cmd" = "toggle" ]; then
		timer_toggle
	elif [ "$cmd" = "start" ]; then
		timer_start
	elif [ "$cmd" = "menu" ]; then
		timer_menu
	else
		timer_status
	fi
}

update_dirs
source $TIMER_CONFIG
main "$@"
