#!/usr/bin/python3

import os
import argparse
import subprocess

# TODO Change color of status bar during tmux notification to make it clear if windows are covering the center of the terminal

def menu_add_option(name, key, cmd):
    entry = [name, key, cmd]

    return entry

def get_terminal_size():
    term_height = subprocess.run(["/usr/local/bin/tmux", "display-message", "-p", "#{window_height}"], capture_output=True)
    term_width = subprocess.run(["/usr/local/bin/tmux", "display-message", "-p", "#{window_width}"], capture_output=True)

    term_height = term_height.stdout.rstrip()
    term_height = int(term_height)
    term_width = term_width.stdout.rstrip()
    term_width = int(term_width)

    return term_height, term_width


def popup_create(title, msg):
    term_height, term_width = get_terminal_size()
    if term_height % 2 == 0:
        term_height += 1

    if term_width %2 == 0:
        term_width += 1

    term_height = int(term_height/2) + 1
    term_width = int(term_width/2) + 1
    vert_padding = '\n'*(int((term_height/2)) - 1)

    cmd = f"/usr/local/bin/tmux display-popup -S fg=#d79921,align=centre -h {term_height} -w {term_width} -T"
    cmd = cmd.split(' ')
    cmd.append(f"{title}")
    cmd.append(f"echo -n '{vert_padding}{msg.center(term_width)}'")

    subprocess.run(cmd)

    return 0


def menu_create(title, pos_x, pos_y, options):
    cmd = f"/usr/local/bin/tmux display-menu -y {pos_y} -x {pos_x} -T {title}"
    cmd = cmd.split(' ')

    for option in options:
        cmd += option

    subprocess.run(cmd)

def menu_create_timer():
    timers = os.listdir(f"{os.path.dirname(os.path.realpath(__file__))}/../timers/")
    timers = sorted(timers, key=len)
    options = []
    for timer in timers:
        timer = timer.split('.')[0]
        name = timer
        key = ""
        cmd = f"set -g @timer_selection {timer}; run-shell '/home/m83393/.tmux/plugins/tmux-timers/scripts/timers.sh toggle'"
        options.append(menu_add_option(name, key, cmd))

    menu_create("Timers", "R", "S", options)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('menu_type', help="Specify the type of menu you would like to created (eg. timers)")
    parser.add_argument('--msg', help="Specify the message you would like to display")
    parser.add_argument('--title', help="Specify the title for the display object")
    args = parser.parse_args()

    if args.menu_type == "timers":
        menu_create_timer()
    elif args.menu_type == "popup":
        if args.msg == None or args.title == None:
            raise Exception("Please specify a message and title for the popup")

        popup_create(args.title, args.msg)
    else:
        raise Exception("Menu type does not exist")

    return 0

if __name__ == '__main__':
    main()
