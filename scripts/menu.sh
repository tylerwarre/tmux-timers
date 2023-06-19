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
	timers=$(ls -1 $TIMERS_DIR | sed 's/\.sh//g')

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
	#set_tmux_option "@timer_selection" "-1"
	timer_menu_position=$(get_tmux_option @timer_menu_position "R")
	export timer_menu_position
	
	# Dynamic option population
	#printf $(get_menu_options) | sed 's/\.sh//g' \
	#| awk 'BEGIN {ORS=" "} {print $1, NR, "\" set -g @timer_selection", $1 "\""}' \
	#| xargs tmux display-menu -y S -x R -T "Timers"
	
	tmux display-menu -y S -x "$timer_menu_position" -T " Timers " \
		"pomodoro" "" "set -g @timer_selection pomodoro; run-shell '$CURRENT_DIR/timers.sh toggle'" \
		"password-spray" "" "set -g @timer_selection password-spray; run-shell '$CURRENT_DIR/timers.sh toggle'"

	#$CURRENT_DIR/timers.sh toggle

	# source $TIMERS_DIR/$timer_selection.sh
	# echo $timer_type

	# tmux display-menu -y S -x "$timer_menu_position" -T "$TIMER_SELECTED" \
	# 	"$(get_timer_status)" "" "set -g @pomodoro_mins 15; run-shell 'echo 15 > $POMODORO_MINS_FILE'" \
	# 	"$(get_timer_state)" "" "run-shell \"$CURRENT_DIR/toggle_timer_state.sh $TIMER_SELECTED $(get_timer_state)\"" \
	# 	"Cancel" "" "set -g @pomodoro_mins 20; run-shell 'echo 20 > $POMODORO_MINS_FILE'" \
	# 	"Configure" "" "set -g @pomodoro_mins 25; run-shell 'echo 25 > $POMODORO_MINS_FILE'"
}

main() {
	timer_menu	
}

main "$@"
