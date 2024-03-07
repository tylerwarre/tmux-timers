#!/bin/bash
# ______________________________________________________________| locals |__ ;
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMER_DIR="/tmp/tmux-timer/$TIMER_SELECTION"
TIMER_FILE="$TIMER_DIR/time.txt"
TIMER_STATUS_FILE="$TIMER_DIR/status.txt"
TIMER_MINS_FILE="$TIMER_DIR/user_mins.txt"
CONFIG_DIR="$CURRENT_DIR/../timers"
TIMER_CONFIG="$CONFIG_DIR/$TIMER_SELECTION"
# _____________________________________________________________| methods |__ ;

source "$CURRENT_DIR/helpers.sh"

get_timer_state() {
    if [[ $(read_file $TIMER_STATE_FILE | grep -c -P "$TIMER_SELECTED") -eq 1 ]]
    then	
        echo "Disable"
    else
        echo "Enable"
    fi
}

get_timer_status() {
    if [[ $(read_file $STATE_DIR/$TIMER_SELECTED/status.txt | grep -c -P "working") -eq 1 ]]
    then	
        echo "Stop"
    else
        echo "Start"
    fi
}

toggle_timer_state() {
    local timer="$1"
    local state="$2"
    if [[ $state == "Disable" ]]
    then
        echo "Removing timer from state file"
        sed -i "/$timer/d" $TIMER_STATE_FILE
    else
        echo "Adding timer to state file"
        echo "$timer" >> $TIMER_STATE_FILE
    fi
}

get_menu_options() {
    timers=$(ls -1 "$CONFIG_DIR" | sed 's/\.sh//g')

    if [[ $timers == "-1" ]]
    then
        tmux display-message "No timer files found!"
        return 0
    fi

    local options
    for timer in $timers
    do
        if [[ $(grep -c "$timer" $TIMER_STATE_FILE) -eq 1 ]]
        then
            options="${options}$timer\n"
        else
            options="${options}$timer\n"
        fi
    done

    echo $options
}

timer_menu() {	
    timer_menu_position=$(get_tmux_option @timer_menu_position "R")
    export timer_menu_position

    "$CURRENT_DIR/menu-helper.py" "timers"
}

main() {
    debug "$(date): menu.sh init" $DEBUG_FILE
    timer_menu	
}

main "$@"
