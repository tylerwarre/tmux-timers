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
		sound=$(get_sound)
		export sound
		case "$OSTYPE" in
		linux* | *bsd*)
			notify-send -t 8000 "$title" "$message"
      if [[ "$sound" == "on" ]]; then
        beep -D 1500
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
	clean_env
	mkdir -p $TIMER_DIR
	debug "$(date): start" "$DEBUG_FILE"
	write_to_file "$(get_seconds)" "$TIMER_FILE"
	write_to_file "working" "$TIMER_STATUS_FILE"

	send_notification "🕓 Timer started!" "Your Timer is underway"
	if_inside_tmux && tmux refresh-client -S
	return 0
}

timer_cancel() {
	clean_env
	debug "$(date): cancel" "$DEBUG_FILE"
	if [[ -z $1 ]]; then
		send_notification "🍅 Timer cancelled!" "Your Timer has been cancelled"
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

		if [ "$timer_start_time" -eq -1 ]; then
			debug "idle" "$DEBUG_FILE"
			status="${status}"
		elif [ $difference -ge "$(minutes_to_seconds "$timer_duration_minutes")" ]; then
			debug "done" "$DEBUG_FILE"
			if [ "$timer_status" == 'working' ]; then
				send_notification "🍅 Timer completed!" "Your Timer has now completed"
				write_to_file "done" "$TIMER_STATUS_FILE"
			fi

			#printf "$(get_tmux_option "$timer_complete" "$timer_complete_default")"
			status="${status} $timer_complete "
		else
			debug "working" "$DEBUG_FILE"
			timer_duration_secs=$(minutes_to_seconds "$timer_duration_minutes")
			time_left_formatted=$(format_seconds $((timer_duration_secs - difference)))
			#printf "$(get_tmux_option "$timer_on" "$timer_on_default")$time_left_formatted "
			status="${status}$timer_on $time_left_formatted "
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
