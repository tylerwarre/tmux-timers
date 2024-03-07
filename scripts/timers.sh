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
    if [ "$timer_notifications" == 'true' ]; then
        local title=$1
        local message=$2
        case "$OSTYPE" in
            linux* | *bsd*)
                if [[ $(uname -r) =~ "WSL" ]]; then
                    "$CURRENT_DIR/display-helper.py" popup --title "${title}" --msg "${message}"
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
    debug "$(date): Cleaning env" $DEBUG_FILE
    remove_file "$TIMER_DIR/timer.txt"
    remove_file "$TIMER_DIR/status.txt"
}

timer_toggle() {
    status=$(read_file "$TIMER_STATUS_FILE")
    if [[ $timer_start_completed == "true" && $status -eq "-1" ]]; then
        timer_start "done" "$timer_duration_minutes"
    elif [[ $status -eq "-1" ]]; then
        timer_start "working" "$timer_duration_minutes"
        return 0
    elif [[ $status == "done" ]]; then
        timer_start "working" "$timer_duration_minutes"
    else
        timer_cancel
        return 0
    fi
}

timer_start() {
    local status=$1
    local duration=$2

    mkdir -p "$TIMER_DIR"

    clean_env
    write_to_file "$status" "$TIMER_STATUS_FILE"
    write_to_file "$(get_seconds)" "$TIMER_FILE"
    debug "$(date): $TIMER_SELECTION, $status, $duration" $DEBUG_FILE

    if_inside_tmux && tmux refresh-client -S
    return 0
}

timer_cancel() {
    debug "$(date): Cancled timer" $DEBUG_FILE
    clean_env
    remove_file "$TIMER_DIR/iterations.txt"
    send_notification "🕓 $TIMER_SELECTION" "Your timer has been cancelled"
    if_inside_tmux && tmux refresh-client -S
    return 0
}

timer_status() {
    # Timer inactive
    if [[ $status -eq -1 ]]; then
        status_line="${status_line}"
    # Currently working
    elif [[ $status == "working" ]]; then
        debug "$(date): Currently working" $DEBUG_FILE
        # Check if the timer finished
        if [[ $difference -ge "$(minutes_to_seconds "$timer_duration_minutes")" ]]; then
            send_notification "🕑 $TIMER_SELECTION" "Timer finished"
            write_to_file "done" "$TIMER_STATUS_FILE"
            status_line="${status_line} $timer_complete"
        # Still working
        else
            timer_duration_secs=$(minutes_to_seconds "$timer_duration_minutes")
            time_left_formatted=$(format_seconds $((timer_duration_secs - difference)))
            status_line="${status_line}$timer_on $time_left_formatted"
        fi
    # Timer is currently done
    elif [[ $status == "done" ]]; then
        status_line="${status_line} $timer_complete"
    else
        debug "$(date): No status selected!" $DEBUG_FILE
    fi
}

pomodoro_status() {
    # Timer inactive
    if [[ $status -eq -1 ]]; then
        status_line="${status_line}"
    # Currently working
    elif [[ $status == "working" ]]; then
        debug "$(date): Currently working" $DEBUG_FILE

        iterations=$(read_file "$TIMER_DIR/iterations.txt")
        if [[ $iterations -eq -1 ]]; then
            write_to_file "1" "$TIMER_DIR/iterations.txt"
            iterations=1
        fi

        # Check if we should go to a break
        if [[ $difference -ge "$(minutes_to_seconds "$timer_duration_minutes")" ]]; then
            # Update iterations
            iterations=$((iterations + 1))
            write_to_file "$iterations" "$TIMER_DIR/iterations.txt"

            # Long break
            if [[ $iterations -gt $timer_sessions ]]; then
                send_notification "🕑 $TIMER_SELECTION" "Take a long break"
                write_to_file "1" "$TIMER_DIR/iterations.txt"
                timer_duration_secs=$(minutes_to_seconds "$timer_long_break_minutes")
                timer_start "long_break" "$timer_long_break_minutes"
            # Short break
            else
                send_notification "🕑 $TIMER_SELECTION" "Take a short break"
                timer_duration_secs=$(minutes_to_seconds "$timer_short_break_minutes")
                timer_start "short_break" "$timer_long_break_minutes"
            fi
            time_left_formatted=$(format_seconds "$timer_duration_secs")
            status_line="${status_line}$timer_complete $time_left_formatted"
        # Still working
        else
            timer_duration_secs=$(minutes_to_seconds "$timer_duration_minutes")
            time_left_formatted=$(format_seconds $((timer_duration_secs - difference)))
            status_line="${status_line}$timer_on ${iterations}/${timer_sessions} $time_left_formatted"
        fi
    # Currently taking a long break
    elif [[ $status == "long_break" ]]; then
        debug "$(date): Currently on a long break" $DEBUG_FILE
        # Check if long break is over
        if [[ $difference -ge "$(minutes_to_seconds "$timer_long_break_minutes")" ]]; then
            send_notification "🕑 $TIMER_SELECTION" "Break over. Get back to work"
            timer_start "working" "$timer_duration_minutes"
            timer_duration_secs=$(minutes_to_seconds "$timer_duration_minutes")
            time_left_formatted=$(format_seconds "$timer_duration_secs")
            status_line="${status_line}$timer_on $time_left_formatted"
        # Still on long break
        else
            timer_duration_secs=$(minutes_to_seconds "$timer_long_break_minutes")
            time_left_formatted=$(format_seconds $((timer_duration_secs - difference)))
            status_line="${status_line}$timer_complete $time_left_formatted"
        fi
    # Currently taking a short break
    elif [[ $status == "short_break" ]]; then
        debug "$(date): Currently on a short break" $DEBUG_FILE
        # Check if short break is over
        if [[ $difference -ge "$(minutes_to_seconds "$timer_short_break_minutes")" ]]; then
            send_notification "🕑 $TIMER_SELECTION" "Break over. Get back to work"
            timer_start "working" "$timer_duration_minutes"
            timer_duration_secs=$(minutes_to_seconds "$timer_duration_minutes")
            time_left_formatted=$(format_seconds "$timer_duration_secs")
            status_line="${status_line}$timer_on $time_left_formatted"
        # Still on short break
        else
            timer_duration_secs=$(minutes_to_seconds "$timer_short_break_minutes")
            time_left_formatted=$(format_seconds $((timer_duration_secs - difference)))
            status_line="${status_line}$timer_complete $time_left_formatted"
        fi
    else
        debug "$(date): No status selected!" $DEBUG_FILE
    fi
}

get_status() {
    local status_line=" "
    local cnt=0
    for timer in $(ls -1 "$CONFIG_DIR");
    do
        source "$CONFIG_DIR/$timer"
        update_dirs $(echo "$timer" | sed "s/\.sh//g")

        local timer_start_time=$(read_file "$TIMER_FILE")
        local status=$(read_file "$TIMER_STATUS_FILE")
        local current_time=$(get_seconds)
        local difference=$((current_time - timer_start_time))

        # Timer workflow
        if [ "$timer_type" == "timer" ]; then
            timer_status
            # Pomdoro workflow
        else
            pomodoro_status
        fi
        cnt=$((cnt+1))
    done
    echo "$status_line"
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
        get_status
    fi
}

debug "$(date): timers.sh init" $DEBUG_FILE
update_dirs
source "$TIMER_CONFIG"
main "$@"
