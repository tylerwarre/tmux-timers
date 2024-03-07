#!/usr/bin/python3

import os
import argparse
import subprocess

def add_arg(name, key, cmd):
    entry = [name, key, cmd]

    return entry

def create_menu(title, pos_x, pos_y, options):
    cmd = f"/usr/local/bin/tmux display-menu -y {pos_y} -x {pos_x} -T {title}"
    cmd = cmd.split(' ')

    for option in options:
        cmd += option

    f = open("test.log", "a")
    f.write(f"{cmd}")
    f.close()

    subprocess.run(cmd)

def create_timer_menu():
    timers = os.listdir(f"{os.path.dirname(os.path.realpath(__file__))}/../timers/")
    timers = sorted(timers, key=len)
    options = []
    for timer in timers:
        timer = timer.split('.')[0]
        name = timer
        key = ""
        cmd = f"set -g @timer_selection {timer}; run-shell '/home/m83393/.tmux/plugins/tmux-timers/scripts/timers.sh toggle'"
        options.append(add_arg(name, key, cmd))

    create_menu("Timers", "R", "S", options)


def main():
    f = open("test.log", "w+")
    f.write("init")
    f.close()
    parser = argparse.ArgumentParser()
    parser.add_argument('menu_type', help="Specify the type of menu you would like to created (eg. timers)")
    args = parser.parse_args()

    if args.menu_type == "timers":
        create_timer_menu()
    else:
        f = open("test.log", "a")
        f.write("exception")
        f.close()
        raise Exception("Menu type does not exist")

    return 0

if __name__ == '__main__':
    main()
