"""What every calendar source shares: errors, the local time zone, events built from the shell's form,
iCalendar events turned into what the shell shows, and repeating events expanded by hand for the sources
whose server does not do it."""

import datetime
import os
from zoneinfo import ZoneInfo

import icalendar
from dateutil import rrule


class CalendarError(Exception):
    """A failure with the exit code that describes it."""

    def __init__(self, code: int, message: str) -> None:
        super().__init__(message)
        self.code = code


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
