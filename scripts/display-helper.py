#!/usr/bin/python3

import re
import os
#import logging
#import requests
#import urllib3
import argparse
#import datetime
#import traceback
import subprocess
from enum import Enum

# TODO Change color of status bar during tmux notification to make it clear if windows are covering the center of the terminal


#################################
##       Global Variables       #
#################################
#JIRA_BASE_API_URL = "https://jira.sde.sp.gc1.myngc.com/rest/api/2/"
#JIRA_BASE_URL = "https://jira.sde.sp.gc1.myngc.com/browse/"
#_DEBUG = False
#
#
#################################
##         Enumerations         #
#################################
#class JiraFields(Enum):
#    def __str__(self):
#        return str(self.value)
#
#    CRITICALITY = "customfield_11248"
#    CREATED = "created"
#    DUE_DATE = "duedate"
#    EVENT_DATE = "customfield_13321"
#    FEATURE = "customfield_10100"
#    JIRA_ISSUE_TYPE = "issuetype"
#    CDR_ISSUE_TYPE = "customfield_13323"
#    STATUS = "status"
#    COMPONENTS = "component"
#    ASSIGNEE = "assignee"
#    HISTORIES = "histories"
#    CHANGELOG = "changelog"
#
#
#################################
##           Logging            #
#################################
#def init_logging(log_level=logging.INFO):
#    """init_logging
#    Summary: Initalizaes program logging. Outputs to file and STDERR and exits the 
#        process if a ERROR or CRITICAL message is logged
#    """
#    if os.path.exists("./logs") != True:
#        os.mkdir("./logs")
#
#    cleanup_logs()
#
#    logfile = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
#    logFormatter = logging.Formatter("[%(levelname)-8s]\t%(message)s")
#
#    rootLogger = logging.getLogger()
#    rootLogger.setLevel(log_level)
#
#    fileHandler = logging.FileHandler(f"./logs/{logfile}.log")
#    fileHandler.setFormatter(logFormatter)
#    rootLogger.addHandler(fileHandler)
#
#    consoleHandler = ExitOnExceptionHandler()
#    consoleHandler.setFormatter(logFormatter)
#    rootLogger.addHandler(consoleHandler)
#
#    logging.info(f"Logging started {datetime.datetime.now()}")
#
#
#def cleanup_logs():
#    threshold = datetime.datetime.now().date() - datetime.timedelta(days=7)
#    for file in reversed(os.listdir('./logs/')):
#        filedate = datetime.datetime.fromtimestamp(os.path.getctime(f"./logs/{file}")).date()
#        if filedate < threshold:
#            os.remove(f"./logs/{file}")
#
#################################
##        Error Handlers        #
#################################
#class ExitOnExceptionHandler(logging.StreamHandler):
#    def emit(self, record):
#        """emit
#        Summary: Handles all messages logged to console and exits on ERROR or CRITIAL log
#        
#        Arguments:
#            record (LogRecord) - Stores the log object passed to the handler
#        """
#        super().emit(record)
#        if record.levelno in (logging.ERROR, logging.CRITICAL):
#            logging.info(f"Logging ended {datetime.datetime.now()}")
#            raise SystemExit(-1)
#
#
#def handle_sanitization_err(e, tickets, index, field):
#    """handle_sanitization_err
#    Summary: Handles sanitization errors
#    
#    Arguments:
#        e (Exception) - Exception option caught
#    Arguments:
#        tickets (list) - list of dictionaries containing tickets
#    Arguments:
#        index (int) - index of ticket that through the error
#    Arguments:
#        field (str) - The field in which the error originated from
#    """
#
#    trace = ''.join(traceback.format_tb(e.__traceback__))
#    logging.critical(f"Error when sanitizing {field} of ticket[{index}]\nTickets: {tickets}\n{trace}")
#
#
#def handle_jira_err(url, status_code, payload=""):
#    """handle_jira_err
#    Summary: Handles jira API errors
#    
#    Arguments:
#        url (str) - URL of API request
#    Arguments:
#        status_code (int) - API request http code
#    """
#
#    if status_code == 200:
#        return
#    # Email successfully sent
#    if status_code == 204:
#        return
#    elif status_code == 400:
#        logging.warning(f"({status_code}) Invalid input when accessing {url}.\nPayload: {payload}")
#    elif status_code == 401:
#        logging.critical(f"({status_code}) Unauthorized when accessing {url}. Access token expired?\nPayload: {payload}")
#    elif status_code == 403:
#        logging.critical(f"({status_code}) Outgoing emails are disabled or no SMTP server is defined.")
#    elif status_code == 404:
#        logging.critical(f"({status_code}) Object at {url} does not exist.\nPayload: {payload}")
#    else:
#        logging.critical(f"({status_code}) Error assessing {url}\nPayload: {payload}")


################################
#         Jira Methods         #
################################
#def get_tickets():
#    """get_tickets
#    Summary: Retrives all open NS stories, tasks, and subtasks that are due today or in the future
#    
#    Returns:
#        (list) - List of dictionaries containing all tickets returned
#    """
#
#    page = 0
#    total = 1
#    issues = []
#    
#    query = f"assignee = 'M83393' and status != 'Done' and project = 'MDT' and Sprint in openSprints()"
#
#    url = JIRA_BASE_API_URL + "search"
#    while (page < total):
#
#        payload = json.dumps({
#            "jql": query,
#            "startAt": page,
#            "maxResults": 100,
#            "expand":[
#                "changelog",
#                "history"
#            ],
#            "fields": [
#                f"{JiraFields.DUE_DATE}",
#                f"{JiraFields.ASSIGNEE}",
#                f"{JiraFields.JIRA_ISSUE_TYPE}",
#                f"{JiraFields.STATUS}",
#                
#            ]
#        })
#
#        if _DEBUG:
#            api_key = keyring.get_password("jira-api", "M83393")
#        else:
#            api_key = keyring.get_password("jira-api", "yy-cdr-metrics")
#
#        try:
#            headers = {
#                'Content-Type': 'application/json',
#                'Authorization': 'Bearer ' + api_key
#            }
#        except TypeError as e:
#            logging.critical("Jira API key missing from credential manager")
#
#        try:
#            response = requests.request("POST", url, headers=headers, data=payload, verify=False)
#        except Exception as e:
#            handle_jira_err(url, None, payload=payload)
#
#        api_key = None
#        handle_jira_err(url, response.status_code, payload=payload)
#        response = response.json()
#
#        try:
#            if response['total'] == 0:
#                logging.warning(f"No issues found")
#                issues = None
#                break
#            else:
#                issues += response['issues']
#                total = response["total"]
#                page += 100
#        except KeyError:
#            handle_jira_err(url, None, payload=payload)
#
#    if issues == None:
#        return None
#    else:
#        return issues


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
    cmd = f"/usr/local/bin/tmux display-menu -y {pos_y} -x {pos_x} -T"
    cmd = cmd.split(' ')
    cmd.append(title)

    for option in options:
        cmd += option

    subprocess.run(cmd)


def get_plugin_dir():
    path = os.path.dirname(os.path.realpath(__file__))
    path = path.split('/')[:-1]
    path = '/'.join(path)

    return path


def get_status_dir():
    with open(f"{get_plugin_dir()}/scripts/helpers.sh", "r") as f:
        lines = f.read()

    dir = re.findall(f"(?<=^TIMER_DIR=\").*$", lines, re.MULTILINE)

    if dir == None:
        raise Exception("Unable to get TIMER_DIR")

    dir = dir[0]
    dir = dir.split('/')[:-1]
    dir = '/'.join(dir)

    return dir


def get_timer_property(timer, property):
    with open(f"{get_plugin_dir()}/timers/{timer}.sh", "r") as f:
        lines = f.read()

    dir = re.findall(f"(?<=^{property}=\").*$", lines, re.MULTILINE)

    if dir == None:
        raise Exception("Unable to get TIMER_DIR")

    dir = dir[0]
    dir = dir.replace('"', "")

    return dir


def is_timer_enabled(timer):
    if os.path.exists(f"{get_status_dir()}/{timer}/status.txt") == False:
        return "  "
    else:
        with open(f"{get_status_dir()}/{timer}/status.txt") as f:
            status = f.read().rstrip()
        
        if status in ["working", "long_break", "short_break"]:
            return "* "
        else:
            return "  "


def menu_timers():
    timers = os.listdir(f"{get_plugin_dir()}/timers/")
    timers = sorted(timers, key=len)
    options = []
    for timer in timers:
        timer = timer.split('.')[0]
        is_enabled = is_timer_enabled(timer)
        name = is_enabled + timer
        key = ""
        timer_type = get_timer_property(timer, 'timer_type')
        if timer_type == "pomodoro-jira":
            if is_enabled == "* ":
                cmd = f"set -g @timer_selection {timer}; run-shell '{get_plugin_dir()}/scripts/display-helper.py jira-timer'"
            else:
                cmd = f"set -g @timer_selection {timer}; run-shell '{get_plugin_dir()}/scripts/display-helper.py jira-tickets'"
        elif timer_type in ["pomodoro", "timer"]:
            cmd = f"set -g @timer_selection {timer}; run-shell '{get_plugin_dir()}/scripts/timers.sh toggle'"
        else:
            raise Exception("Invalid timer_type")

        options.append(menu_add_option(name, key, cmd))

    menu_create("Timers", "R", "S", options)


def menu_jira_tickets():
    timers = os.listdir(f"{get_plugin_dir()}/timers/")
    timers = sorted(timers, key=len)
    options = []
    tickets = ["MDT-123", "MDT-1234", "MDT-456"]
    for ticket in tickets:
        name = ticket
        key = ""
        cmd = ""

        options.append(menu_add_option(name, key, cmd))

    menu_create("Jira Tickets", "C", "C", options)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('display_type', help="Specify the type of menu you would like to created (eg. timers)")
    parser.add_argument('--msg', help="Specify the message you would like to display")
    parser.add_argument('--title', help="Specify the title for the display object")
    args = parser.parse_args()

    if args.display_type == "timers":
        menu_timers()
    elif args.display_type == "popup":
        if args.msg == None or args.title == None:
            raise Exception("Please specify a message and title for the popup")

        popup_create(args.title, args.msg)
    elif args.display_type == "jira-timer":
        print("test timer")
    elif args.display_type == "jira-tickets":
        menu_jira_tickets()
    else:
        raise Exception("Menu type does not exist")

    return 0

if __name__ == '__main__':
    main()
