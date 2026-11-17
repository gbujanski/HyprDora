"""The offline calendar: one iCalendar file per event, kept on this computer only.

The files are in $XDG_DATA_HOME/hyprdora/calendars/local, a directory only its owner may open; other
programs that read such directories, and files copied in by hand, work with it. Repeating events are
expanded here. It has no attendees, as no server sends invitations.
"""

import datetime
import os
import uuid

import icalendar

from .core import (
    CalendarError,
    describe,
    document_of,
    new_event,
    occurrences,
    without_occurrence,
)

LOCAL = "local:"


class LocalCalendar:
    """The offline calendar: one iCalendar file per event, kept on this computer only."""

    def __init__(self) -> None:
        base = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
        self.directory = os.path.join(base, "hyprdora", "calendars", "local")
        os.makedirs(self.directory, mode=0o700, exist_ok=True)
        os.chmod(self.directory, 0o700)

    def calendars(self) -> list[dict]:
        """The one offline calendar."""
        return [self.calendar()]

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

    def events(
        self, calendar: dict, start: datetime.datetime, end: datetime.datetime
    ) -> list[dict]:
        """Reads the events in a range, with repeating ones expanded."""
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

    def create(self, calendar: str, event: dict) -> None:
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
