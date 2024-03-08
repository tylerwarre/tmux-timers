#!/usr/bin/env bash
TIMER_DIR="/tmp/tmux-timer/$TIMER_SELECTION"
DEBUG_FILE=/tmp/timer-debug.log

get_tmux_option() {
    local option=$1
    local default_value=$2
    option_value=$(tmux show-option -gqv "$option")
    if [ -z "$option_value" ]; then
        echo "$default_value"
    else
        echo "$option_value"
    fi
}

set_tmux_option() {
    local option="$1"
    local value="$2"
    tmux set-option -g "$option" "$value"
}

read_file() {
    local file=$1
    if [ -f "$1" ]; then
        cat "$1"
    else
        echo -1
    fi
}

remove_file() {
    local file=$1
    rm $file
}

write_to_file() {
    local data=$1
    local file=$2
    echo "$data" > "$file"
}

debug() {
    debugging=$(get_tmux_option "@timers_debug" false)
    if [ "$debugging" = true ]; then
        local data=$1
        local file=$2
        echo "$data" >> "$file"
    fi
}
