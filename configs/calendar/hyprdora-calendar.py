#!/usr/bin/python3
"""Calendar events of Nextcloud accounts over CalDAV, for the shell's calendar.

The app password of each account comes from the keyring, where the shell's online accounts
keep it, so it never passes through the shell. Repeating events are expanded by the server.

Usage:
  hyprdora-calendar events START END SERVER LOGIN [SERVER LOGIN ...]
      prints {"calendars": [...], "events": [...], "failed": [...]} for dates START..END
      (YYYY-MM-DD, END exclusive); an unreachable account is listed in "failed"
  hyprdora-calendar create SERVER LOGIN CALENDAR < event.json
      adds an event: {"summary", "location", "description", "start", "end", "allDay",
      "repeat": {"freq", "interval", "until"}, "attendees": [address, ...],
      "reminders": [minutes before the start, ...]}
  hyprdora-calendar delete SERVER LOGIN HREF ETAG [OCCURRENCE]
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

DAV = "DAV:"
CALDAV = "urn:ietf:params:xml:ns:caldav"
APPLE = "http://apple.com/ns/ical/"
NS = {"d": DAV, "c": CALDAV, "a": APPLE}
TIMEOUT = 15
XML = "application/xml; charset=utf-8"


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
        document = icalendar.Calendar()
        document.add("prodid", "-//HyprDora//Calendar//EN")
        document.add("version", "2.0")
        document.add_component(entry)
        document.add_missing_timezones()
        href = calendar.rstrip("/") + f"/{uid}.ics"
        self.request(
            "PUT",
            href,
            document.to_ical(),
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
        self.request(
            "PUT",
            href,
            document.to_ical(),
            {"Content-Type": "text/calendar; charset=utf-8", "If-Match": current},
        )


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
    if not args or len(args) % 2:
        raise CalendarError(2, __doc__)
    return list(zip(args[::2], args[1::2], strict=True))


def run(args: list[str]) -> int:
    """Runs one command."""
    if not args:
        raise CalendarError(2, __doc__)
    command = args[0]
    if command == "events" and len(args) >= 5:
        start = datetime.datetime.fromisoformat(args[1]).astimezone()
        end = datetime.datetime.fromisoformat(args[2]).astimezone()
        calendars, events, failed = [], [], []
        for server, login in accounts_from(args[3:]):
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
