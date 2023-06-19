#!/usr/bin/env bash
# ______________________________________________________________| locals |__ ;

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMER_MINS_FILE="$CURRENT_DIR/scripts/user_mins.txt"

default_start_timer="t"
start_timer="@timer_start"

timer_status="#($CURRENT_DIR/scripts/timers.sh)"
timer_status_interpolation_string="\#{timer_status}"

# _____________________________________________________________| methods |__ ;

source "$CURRENT_DIR/scripts/helpers.sh"

sync_timers() {
	pomodoro_mins_exists=$(tmux show-option -gqv "@pomodoro_mins")
	export pomodoro_mins_exists

	if [ "$pomodoro_mins_exists" != "" ]; then
		remove_file "$POMODORO_MINS_FILE"
		remove_file "$POMODORO_BREAK_MINS_FILE"

	elif [ -f "$POMODORO_MINS_FILE" ] &&
		[ -f "$POMODORO_BREAK_MINS_FILE" ]; then
		set_tmux_option "@pomodoro_mins $(read_file "$POMODORO_MINS_FILE")"
		set_tmux_option "@pomodoro_break_mins $(read_file "$POMODORO_BREAK_MINS_FILE")"
	fi
}

set_bindings() {
	start_binding=$(get_tmux_option "$start_timer" "$default_start_timer")
	export start_binding

	for key in $start_binding; do
		tmux bind-key "$key" run-shell "$CURRENT_DIR/scripts/menu.sh"
	done
}

do_interpolation() {
	local string="$1"
	local interpolated="${string/$timer_status_interpolation_string/$timer_status}"
	echo "$interpolated"
}

update_tmux_option() {
	local option="$1"

	option_value="$(get_tmux_option "$option")"
	export option_value

	new_option_value="$(do_interpolation "$option_value")"
	export new_option_value

	set_tmux_option "$option" "$new_option_value"
}

main() {
	echo -n '' > $DEBUG_FILE
	debug "$(date): init" "$DEBUG_FILE"

	sync_timers
	set_bindings
	update_tmux_option "status-right"
	update_tmux_option "status-left"
}
main
