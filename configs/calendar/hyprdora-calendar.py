#!/usr/bin/python3
"""Calendar events of Nextcloud accounts over CalDAV, and of the offline calendar, for the shell.

The app password of each account comes from the keyring, where the shell's online accounts
keep it, so it never passes through the shell. Repeating events are expanded by the server.

The offline calendar is kept on this computer only, one iCalendar file per event in
$XDG_DATA_HOME/hyprdora/calendars/local, a directory only its owner may open; other programs
that read such directories, and files copied in by hand, work with it. Its repeating events are
expanded here. It is named by "local" in place of SERVER LOGIN, and has no attendees, as no
server sends invitations.

Usage:
  hyprdora-calendar events START END [SERVER LOGIN ...] [local]
      prints {"calendars": [...], "events": [...], "failed": [...]} for dates START..END
      (YYYY-MM-DD, END exclusive); an unreachable account is listed in "failed"
  hyprdora-calendar create SERVER LOGIN CALENDAR < event.json
  hyprdora-calendar create local < event.json
      adds an event: {"summary", "location", "description", "start", "end", "allDay",
      "repeat": {"freq", "interval", "until"}, "attendees": [address, ...],
      "reminders": [minutes before the start, ...]}
  hyprdora-calendar delete SERVER LOGIN HREF ETAG [OCCURRENCE]
  hyprdora-calendar delete local HREF ETAG [OCCURRENCE]
      removes an event, or one occurrence of a repeating one, if it has not changed since read

Exit codes: 0 success, 2 usage, 3 rejected password, 4 server unreachable, 5 other failure.
"""

import base64
import datetime
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET
from zoneinfo import ZoneInfo

import icalendar
from dateutil import rrule

DAV = "DAV:"
CALDAV = "urn:ietf:params:xml:ns:caldav"
APPLE = "http://apple.com/ns/ical/"
NS = {"d": DAV, "c": CALDAV, "a": APPLE}
TIMEOUT = 15
XML = "application/xml; charset=utf-8"
LOCAL = "local:"


class CalendarError(Exception):
    """A failure with the exit code that describes it."""

    def __init__(self, code: int, message: str) -> None:
        super().__init__(message)
        self.code = code


class Account:
    """A Nextcloud account and its app password from the keyring."""

    def __init__(self, server: str, login: str) -> None:
        self.server = server.rstrip("/")
        self.login = login
        key = f"nextcloud:{login}@{self.server}"
        result = subprocess.run(
            ["secret-tool", "lookup", "application", "hyprdora", "account", key],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0 or not result.stdout:
            raise CalendarError(3, f"{key}: no password in the keyring")
        token = base64.b64encode(f"{login}:{result.stdout}".encode()).decode()
        self.auth = f"Basic {token}"

    def url(self, href: str) -> str:
        """Returns the absolute address of a path on the server."""
        return urllib.parse.urljoin(self.server + "/", href)

    def request(
        self,
        method: str,
        href: str,
        body: bytes | None = None,
        headers: dict[str, str] | None = None,
    ) -> tuple[int, bytes, dict[str, str]]:
        """Sends a request and returns the status, body and headers."""
        request = urllib.request.Request(
            self.url(href),
            data=body,
            method=method,
            headers={
                "Authorization": self.auth,
                "User-Agent": "HyprDora",
                **(headers or {}),
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                return response.status, response.read(), dict(response.headers)
        except urllib.error.HTTPError as error:
            if error.code == 401:
                raise CalendarError(
                    3, "the server rejected the app password"
                ) from error
            raise CalendarError(5, f"{method} {href}: HTTP {error.code}") from error
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            raise CalendarError(4, f"{self.server}: {error}") from error

    def calendars(self) -> list[dict]:
        """Lists the account's calendars that hold events."""
        body = b"""<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:a="http://apple.com/ns/ical/">
  <d:prop><d:resourcetype/><d:displayname/><a:calendar-color/>
    <c:supported-calendar-component-set/><d:current-user-privilege-set/></d:prop>
</d:propfind>"""
        home = f"remote.php/dav/calendars/{urllib.parse.quote(self.login)}/"
        _, reply, _ = self.request(
            "PROPFIND",
            home,
            body,
            {"Depth": "1", "Content-Type": "application/xml; charset=utf-8"},
        )
        result = []
        for response in ET.fromstring(reply).findall("d:response", NS):
            prop = response.find("d:propstat/d:prop", NS)
            if prop is None or prop.find("d:resourcetype/c:calendar", NS) is None:
                continue
            components = [
                c.get("name")
                for c in prop.findall("c:supported-calendar-component-set/c:comp", NS)
            ]
            if components and "VEVENT" not in components:
                continue
            privileges = {
                p.tag.split("}")[-1]
                for p in prop.findall("d:current-user-privilege-set/d:privilege/*", NS)
            }
            color = (prop.findtext("a:calendar-color", "", NS) or "")[:7]
            result.append(
                {
                    "href": response.findtext("d:href", "", NS),
                    "name": prop.findtext("d:displayname", "", NS) or "",
                    "color": color,
                    "writable": bool(privileges & {"write", "write-content", "all"}),
                    "account": f"{self.login}@{self.server}",
                }
            )
        return result

    def events(
        self, calendar: dict, start: datetime.datetime, end: datetime.datetime
    ) -> list[dict]:
        """Reads a calendar's events in a range, with repeating events expanded by the server."""
        stamp = "%Y%m%dT%H%M%SZ"
        begin = start.astimezone(datetime.UTC).strftime(stamp)
        finish = end.astimezone(datetime.UTC).strftime(stamp)
        body = f"""<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data><c:expand start="{begin}" end="{finish}"/></c:calendar-data></d:prop>
  <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT">
    <c:time-range start="{begin}" end="{finish}"/></c:comp-filter></c:comp-filter></c:filter>
</c:calendar-query>""".encode()
        _, reply, _ = self.request(
            "REPORT",
            calendar["href"],
            body,
            {"Depth": "1", "Content-Type": "application/xml; charset=utf-8"},
        )
        result = []
        for response in ET.fromstring(reply).findall("d:response", NS):
            data = response.findtext("d:propstat/d:prop/c:calendar-data", "", NS)
            if not data:
                continue
            href = response.findtext("d:href", "", NS)
            etag = response.findtext("d:propstat/d:prop/d:getetag", "", NS)
            for event in icalendar.Calendar.from_ical(data).walk("VEVENT"):
                result.append(describe(event, calendar, href, etag))
        return result

    def organizer(self) -> str:
        """Returns the account's own e-mail address, which invitations are sent from."""
        body = b"""<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-user-address-set/></d:prop>
</d:propfind>"""
        principal = f"remote.php/dav/principals/users/{urllib.parse.quote(self.login)}/"
        _, reply, _ = self.request(
            "PROPFIND", principal, body, {"Depth": "0", "Content-Type": XML}
        )
        for href in ET.fromstring(reply).iterfind(
            ".//c:calendar-user-address-set/d:href", NS
        ):
            if (href.text or "").lower().startswith("mailto:"):
                return href.text
        raise CalendarError(5, "the account has no e-mail address for invitations")

    def create(self, calendar: str, event: dict) -> None:
        """Adds an event, with an optional description, repetition and attendees.

        Times are written in the local time zone, so a repeating event keeps its hour across
        daylight saving changes. With attendees, the account is the organizer and Nextcloud
        sends the invitations.
        """
        uid = str(uuid.uuid4())
        entry = new_event(uid, event)
        attendees = event.get("attendees") or []
        if attendees:
            entry.add("organizer", self.organizer())
            for address in attendees:
                entry.add(
                    "attendee",
                    f"mailto:{address}",
                    parameters={
                        "ROLE": "REQ-PARTICIPANT",
                        "PARTSTAT": "NEEDS-ACTION",
                        "RSVP": "TRUE",
                    },
                )
        href = calendar.rstrip("/") + f"/{uid}.ics"
        self.request(
            "PUT",
            href,
            document_of(entry),
            {"Content-Type": "text/calendar; charset=utf-8", "If-None-Match": "*"},
        )

    def delete(self, href: str, etag: str, occurrence: str = "") -> None:
        """Removes an event, or one occurrence of a repeating one, unless it changed since it was read.

        An occurrence is removed by an exception date on the series, given as its original start
        (an ISO date, or date and time in UTC).
        """
        if not occurrence:
            self.request("DELETE", href, None, {"If-Match": etag} if etag else {})
            return
        _, body, headers = self.request("GET", href)
        current = headers.get("ETag") or headers.get("Etag") or etag
        document = icalendar.Calendar.from_ical(body)
        without_occurrence(document, occurrence)
        self.request(
            "PUT",
            href,
            document.to_ical(),
            {"Content-Type": "text/calendar; charset=utf-8", "If-Match": current},
        )


def new_event(uid: str, event: dict) -> icalendar.Event:
    """Builds an event from the shell's form, without attendees.

    Times are written in the local time zone, so a repeating event keeps its hour across daylight
    saving changes.
    """
    entry = icalendar.Event()
    entry.add("uid", uid)
    entry.add("dtstamp", datetime.datetime.now(datetime.UTC))
    entry.add("summary", event["summary"])
    for key in ("location", "description"):
        if event.get(key):
            entry.add(key, event[key])
    if event.get("allDay"):
        entry.add("dtstart", datetime.date.fromisoformat(event["start"][:10]))
        entry.add("dtend", datetime.date.fromisoformat(event["end"][:10]))
    else:
        zone = local_zone()
        for key in ("start", "end"):
            entry.add(
                f"dt{key}",
                datetime.datetime.fromisoformat(event[key]).replace(tzinfo=zone),
            )
    repeat = event.get("repeat")
    if repeat:
        rule = {"freq": repeat["freq"]}
        if repeat.get("interval", 1) > 1:
            rule["interval"] = repeat["interval"]
        if repeat.get("until"):
            # The last day counts whole, so the rule runs to its end.
            rule["until"] = datetime.datetime.combine(
                datetime.date.fromisoformat(repeat["until"]),
                datetime.time(23, 59, 59),
            ).astimezone(datetime.UTC)
        entry.add("rrule", rule)
    for minutes in event.get("reminders") or []:
        alarm = icalendar.Alarm()
        alarm.add("action", "DISPLAY")
        alarm.add("description", event["summary"])
        alarm.add("trigger", -datetime.timedelta(minutes=minutes))
        entry.add_component(alarm)
    return entry


def document_of(entry: icalendar.Event) -> bytes:
    """Wraps an event in a calendar document with its time zones."""
    document = icalendar.Calendar()
    document.add("prodid", "-//HyprDora//Calendar//EN")
    document.add("version", "2.0")
    document.add_component(entry)
    document.add_missing_timezones()
    return document.to_ical()


def without_occurrence(document: icalendar.Calendar, occurrence: str) -> None:
    """Removes one occurrence of a repeating event, given by its original start, with an exception date."""
    when = (
        datetime.date.fromisoformat(occurrence)
        if len(occurrence) == 10
        else datetime.datetime.fromisoformat(occurrence).astimezone(datetime.UTC)
    )
    for component in list(document.subcomponents):
        if component.name != "VEVENT":
            continue
        if "recurrence-id" in component:
            # A changed copy of that occurrence goes too.
            if component.decoded("recurrence-id") == when:
                document.subcomponents.remove(component)
        else:
            component.add("exdate", when)


class LocalCalendar:
    """The offline calendar: one iCalendar file per event, kept on this computer only."""

    def __init__(self) -> None:
        base = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
        self.directory = os.path.join(base, "hyprdora", "calendars", "local")
        os.makedirs(self.directory, mode=0o700, exist_ok=True)
        os.chmod(self.directory, 0o700)

    @staticmethod
    def calendar() -> dict:
        """The calendar as the shell lists it."""
        return {
            "href": LOCAL,
            "name": "Offline",
            "color": "#2fcf5e",
            "writable": True,
            "account": "local",
        }

    def path(self, href: str) -> str:
        """The file of an event; only a plain file name in the directory is accepted."""
        name = href.removeprefix(LOCAL)
        if (
            not name.endswith(".ics")
            or os.path.basename(name) != name
            or name.startswith(".")
        ):
            raise CalendarError(2, f"not an offline calendar event: {href}")
        return os.path.join(self.directory, name)

    @staticmethod
    def etag(path: str) -> str:
        """A version of a file, so a change made meanwhile is not overwritten."""
        info = os.stat(path)
        return f"{info.st_mtime_ns}-{info.st_size}"

    def events(self, start: datetime.datetime, end: datetime.datetime) -> list[dict]:
        """Reads the events in a range, with repeating ones expanded."""
        calendar = self.calendar()
        result = []
        for name in sorted(os.listdir(self.directory)):
            if not name.endswith(".ics") or name.startswith("."):
                continue
            path = os.path.join(self.directory, name)
            try:
                with open(path, "rb") as file:
                    document = icalendar.Calendar.from_ical(file.read())
                etag = self.etag(path)
            except (OSError, ValueError):
                continue
            for event in occurrences(document, start, end):
                result.append(describe(event, calendar, LOCAL + name, etag))
        return result

    def write(self, path: str, data: bytes) -> None:
        """Replaces a file in one step, readable by its owner only."""
        temporary = f"{path}.{os.getpid()}.tmp"
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "wb") as file:
            file.write(data)
        os.replace(temporary, path)

    def create(self, event: dict) -> None:
        """Adds an event; attendees are left out, as nothing would send the invitations."""
        uid = str(uuid.uuid4())
        self.write(
            os.path.join(self.directory, f"{uid}.ics"),
            document_of(new_event(uid, event)),
        )

    def delete(self, href: str, etag: str, occurrence: str = "") -> None:
        """Removes an event, or one occurrence of a repeating one, unless it changed since it was read."""
        path = self.path(href)
        if not os.path.exists(path):
            raise CalendarError(5, "the event is gone")
        if etag and self.etag(path) != etag:
            raise CalendarError(5, "the event changed meanwhile")
        if not occurrence:
            os.remove(path)
            return
        with open(path, "rb") as file:
            document = icalendar.Calendar.from_ical(file.read())
        without_occurrence(document, occurrence)
        self.write(path, document.to_ical())


def occurrences(
    document: icalendar.Calendar, start: datetime.datetime, end: datetime.datetime
) -> list[icalendar.Event]:
    """The events of a document that overlap a range, a repeating one as one copy per occurrence.

    A copy carries its original start as RECURRENCE-ID, as a server's expansion does, and a changed
    occurrence kept in the document under its RECURRENCE-ID replaces the plain one.
    """
    masters, changed = [], {}
    for event in document.walk("VEVENT"):
        if "dtstart" not in event:
            continue
        if "recurrence-id" in event:
            changed[
                (str(event.get("uid")), comparable(event.decoded("recurrence-id")))
            ] = event
        else:
            masters.append(event)
    result = []
    for event in masters:
        first = event.decoded("dtstart")
        length = span(event)
        if "rrule" not in event:
            if overlaps(first, first + length, start, end):
                result.append(event)
            continue
        uid = str(event.get("uid"))
        excluded = {comparable(when) for when in exception_dates(event)}
        for when in expand(event, first, start - length, end):
            key = comparable(when)
            if key in excluded:
                continue
            copy = changed.pop((uid, key), None)
            if copy is None:
                copy = icalendar.Event(event)
                for name in (
                    "dtstart",
                    "dtend",
                    "duration",
                    "rrule",
                    "exdate",
                    "rdate",
                ):
                    copy.pop(name, None)
                copy.add("dtstart", when)
                copy.add("dtend", when + length)
                copy.add("recurrence-id", when)
            if overlaps(
                copy.decoded("dtstart"),
                copy.decoded("dtstart") + span(copy),
                start,
                end,
            ):
                result.append(copy)
    # Changed occurrences moved into the range from a start outside it.
    for event in changed.values():
        if overlaps(
            event.decoded("dtstart"), event.decoded("dtstart") + span(event), start, end
        ):
            result.append(event)
    return result


def span(event: icalendar.Event) -> datetime.timedelta:
    """How long an event lasts."""
    first = event.decoded("dtstart")
    if "dtend" in event:
        return event.decoded("dtend") - first
    if "duration" in event:
        return event.decoded("duration")
    return datetime.timedelta(days=1 if not isinstance(first, datetime.datetime) else 0)


def exception_dates(event: icalendar.Event) -> list:
    """The starts a repeating event skips."""
    found = event.get("exdate", [])
    if not isinstance(found, list):
        found = [found]
    return [item.dt for group in found for item in group.dts]


def comparable(value: object) -> object:
    """A date, or a date and time in UTC, to compare starts written in different zones."""
    if isinstance(value, datetime.datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=local_zone())
        return value.astimezone(datetime.UTC)
    return value


def expand(
    event: icalendar.Event,
    first: object,
    start: datetime.datetime,
    end: datetime.datetime,
) -> list:
    """The starts of a repeating event between two moments."""
    rule = dict(event.get("rrule"))
    all_day = not isinstance(first, datetime.datetime)
    origin = datetime.datetime.combine(first, datetime.time()) if all_day else first
    if "UNTIL" in rule:
        until = rule["UNTIL"][0]
        if not isinstance(until, datetime.datetime):
            until = datetime.datetime.combine(until, datetime.time(23, 59, 59))
        # dateutil wants the end in the same kind of time as the start.
        if origin.tzinfo is None:
            until = until.astimezone().replace(tzinfo=None) if until.tzinfo else until
        elif until.tzinfo is None:
            until = until.replace(tzinfo=origin.tzinfo)
        rule["UNTIL"] = [until]
    text = icalendar.vRecur(rule).to_ical().decode()
    starts = rrule.rrulestr(text, dtstart=origin)
    if origin.tzinfo is None:
        low, high = (
            start.astimezone().replace(tzinfo=None),
            end.astimezone().replace(tzinfo=None),
        )
    else:
        low, high = start, end
    found = starts.between(low, high, inc=True)
    return [when.date() for when in found] if all_day else found


def overlaps(
    first: object, last: object, start: datetime.datetime, end: datetime.datetime
) -> bool:
    """Whether an event from first to last falls in a range; a whole day counts in local time."""

    def moment_of(value: object) -> datetime.datetime:
        if isinstance(value, datetime.datetime):
            return value if value.tzinfo else value.replace(tzinfo=local_zone())
        return datetime.datetime.combine(value, datetime.time(), tzinfo=local_zone())

    begin, finish = moment_of(first), moment_of(last)
    if finish == begin:
        return start <= begin < end
    return begin < end and finish > start


def local_zone() -> ZoneInfo:
    """Returns the system time zone, from the /etc/localtime link."""
    target = os.path.realpath("/etc/localtime")
    marker = "/zoneinfo/"
    if marker in target:
        return ZoneInfo(target.split(marker, 1)[1])
    return ZoneInfo("UTC")


def moment(value: object) -> tuple[str, bool]:
    """Returns a local ISO date or date and time, and whether it is a whole day."""
    if isinstance(value, datetime.datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=datetime.UTC)
        return value.astimezone().replace(tzinfo=None).isoformat(
            timespec="minutes"
        ), False
    return value.isoformat(), True


def describe(event: icalendar.Event, calendar: dict, href: str, etag: str) -> dict:
    """Turns an expanded event into what the shell shows."""
    start, all_day = moment(event.decoded("dtstart"))
    if "dtend" in event:
        end, _ = moment(event.decoded("dtend"))
    else:
        duration = (
            event.decoded("duration")
            if "duration" in event
            else datetime.timedelta(days=1 if all_day else 0)
        )
        end, _ = moment(event.decoded("dtstart") + duration)
    alarms = []
    for alarm in event.walk("VALARM"):
        trigger = alarm.decoded("trigger") if "trigger" in alarm else None
        if isinstance(trigger, datetime.timedelta) and trigger <= datetime.timedelta(0):
            alarms.append(int(-trigger.total_seconds() // 60))
    return {
        "uid": str(event.get("uid", "")),
        "href": href,
        "etag": etag,
        "summary": str(event.get("summary", "")),
        "location": str(event.get("location", "")),
        "start": start,
        "end": end,
        "allDay": all_day,
        "recurring": "recurrence-id" in event or "rrule" in event,
        "occurrence": occurrence_of(event),
        "description": str(event.get("description", "")),
        "attendees": attendees_of(event),
        "calendar": calendar["href"],
        "calendarName": calendar["name"],
        "color": calendar["color"],
        "writable": calendar["writable"],
        "alarms": alarms,
    }


def occurrence_of(event: icalendar.Event) -> str:
    """Returns the original start of an occurrence of a repeating event, for deleting just it."""
    if "recurrence-id" not in event:
        return ""
    value = event.decoded("recurrence-id")
    if isinstance(value, datetime.datetime):
        if value.tzinfo is None:
            value = value.replace(tzinfo=datetime.UTC)
        return value.astimezone(datetime.UTC).isoformat()
    return value.isoformat()


def attendees_of(event: icalendar.Event) -> list[dict]:
    """Lists the attendees with their answer: accepted, declined, tentative or needs-action."""
    found = event.get("attendee", [])
    if not isinstance(found, list):
        found = [found]
    return [
        {
            "address": str(attendee).removeprefix("mailto:").removeprefix("MAILTO:"),
            "name": str(attendee.params.get("CN", "")),
            "status": str(attendee.params.get("PARTSTAT", "NEEDS-ACTION")).lower(),
        }
        for attendee in found
    ]


def accounts_from(args: list[str]) -> list[tuple[str, str]]:
    """Pairs SERVER LOGIN arguments."""
    if len(args) % 2:
        raise CalendarError(2, __doc__)
    return list(zip(args[::2], args[1::2], strict=True))


def run(args: list[str]) -> int:
    """Runs one command."""
    if not args:
        raise CalendarError(2, __doc__)
    command = args[0]
    if command == "events" and len(args) >= 3:
        start = datetime.datetime.fromisoformat(args[1]).astimezone()
        end = datetime.datetime.fromisoformat(args[2]).astimezone()
        calendars, events, failed = [], [], []
        rest = args[3:]
        if "local" in rest:
            rest = [arg for arg in rest if arg != "local"]
            local = LocalCalendar()
            calendars.append(local.calendar())
            events.extend(local.events(start, end))
        for server, login in accounts_from(rest):
            try:
                account = Account(server, login)
                for calendar in account.calendars():
                    calendars.append(calendar)
                    events.extend(account.events(calendar, start, end))
            except CalendarError as error:
                failed.append(
                    {
                        "account": f"{login}@{server}",
                        "code": error.code,
                        "message": str(error),
                    }
                )
        events.sort(key=lambda e: (e["start"], e["summary"]))
        json.dump(
            {"calendars": calendars, "events": events, "failed": failed},
            sys.stdout,
            ensure_ascii=False,
        )
        return 0
    if command == "create" and args[1:] == ["local"]:
        LocalCalendar().create(json.load(sys.stdin))
        return 0
    if command == "delete" and len(args) in {4, 5} and args[1] == "local":
        LocalCalendar().delete(args[2], args[3], args[4] if len(args) == 5 else "")
        return 0
    if command == "create" and len(args) == 4:
        Account(args[1], args[2]).create(args[3], json.load(sys.stdin))
        return 0
    if command == "delete" and len(args) in {5, 6}:
        Account(args[1], args[2]).delete(
            args[3], args[4], args[5] if len(args) == 6 else ""
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


if __name__ == "__main__":
    sys.exit(main())
