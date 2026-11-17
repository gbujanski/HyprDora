"""The calendar helper's command line, the same for every source.

Each account is one JSON argument:
  {"kind": "local"}                                       the offline calendar
  {"kind": "nextcloud", "server": URL, "login": LOGIN}    app password from the keyring

Usage:
  calendar events START END ACCOUNT...
      prints {"calendars": [...], "events": [...], "failed": [...]} for dates START..END
      (YYYY-MM-DD, END exclusive); an account that could not be read is listed in "failed"
  calendar create ACCOUNT CALENDAR < event.json
      adds an event: {"summary", "location", "description", "start", "end", "allDay",
      "repeat": {"freq", "interval", "until"}, "attendees": [address, ...],
      "reminders": [minutes before the start, ...]}
  calendar delete ACCOUNT HREF ETAG [OCCURRENCE]
      removes an event, or one occurrence of a repeating one, if it has not changed since read

Exit codes: 0 success, 2 usage, 3 rejected sign-in, 4 server unreachable, 5 other failure.
"""

import datetime
import json
import sys

from .core import CalendarError


def account_of(argument: str) -> dict:
    """Reads an account argument."""
    try:
        account = json.loads(argument)
    except json.JSONDecodeError as error:
        raise CalendarError(2, f"not an account: {argument}") from error
    if not isinstance(account, dict) or account.get("kind") not in {
        "local",
        "nextcloud",
    }:
        raise CalendarError(2, f"not an account: {argument}")
    return account


def key_of(account: dict) -> str:
    """The key the shell keeps an account's calendars under, as each source sets it."""
    kind = account["kind"]
    if kind == "local":
        return "local"
    return f"{account['login']}@{account['server'].rstrip('/')}"


def source_of(account: dict):
    """Opens a source; each module is loaded only when one of its accounts is used."""
    kind = account["kind"]
    if kind == "local":
        from .local import LocalCalendar

        return LocalCalendar()
    from .nextcloud import Nextcloud

    return Nextcloud(account["server"], account["login"])


def events(start_day: str, end_day: str, arguments: list[str]) -> dict:
    """Reads every account's calendars and events in a range."""
    start = datetime.datetime.fromisoformat(start_day).astimezone()
    end = datetime.datetime.fromisoformat(end_day).astimezone()
    calendars, found, failed = [], [], []
    for argument in arguments:
        account = account_of(argument)
        try:
            source = source_of(account)
            for calendar in source.calendars():
                calendars.append(calendar)
                found.extend(source.events(calendar, start, end))
        except CalendarError as error:
            failed.append(
                {"account": key_of(account), "code": error.code, "message": str(error)}
            )
    found.sort(key=lambda e: (e["start"], e["summary"]))
    return {"calendars": calendars, "events": found, "failed": failed}


def run(args: list[str]) -> int:
    """Runs one command."""
    command = args[0] if args else ""
    if command == "events" and len(args) >= 3:
        json.dump(events(args[1], args[2], args[3:]), sys.stdout, ensure_ascii=False)
        return 0
    if command == "create" and len(args) == 3:
        source_of(account_of(args[1])).create(args[2], json.load(sys.stdin))
        return 0
    if command == "delete" and len(args) in {4, 5}:
        source_of(account_of(args[1])).delete(
            args[2], args[3], args[4] if len(args) == 5 else ""
        )
        return 0
    raise CalendarError(2, __doc__)


def main() -> int:
    """Runs the command line and turns failures into exit codes."""
    try:
        return run(sys.argv[1:])
    except CalendarError as error:
        print(error, file=sys.stderr)
        return error.code
