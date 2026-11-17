"""Nextcloud calendars over CalDAV.

The app password comes from the keyring, where the shell's online accounts keep it after Nextcloud's
Login Flow, so it never passes through the shell. Nextcloud expands repeating events itself and sends
the invitations of events with attendees.
"""

import base64
import datetime
import subprocess
import urllib.parse
import uuid

from .caldav import CalDAV, add_attendees
from .core import CalendarError, new_event


class Nextcloud:
    """A Nextcloud account."""

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
        self.dav = CalDAV(
            self.server,
            f"Basic {token}",
            f"{login}@{self.server}",
            "the server rejected the app password",
        )

    def calendars(self) -> list[dict]:
        """The account's calendars that hold events."""
        return self.dav.calendars(
            f"remote.php/dav/calendars/{urllib.parse.quote(self.login)}/"
        )

    def events(
        self, calendar: dict, start: datetime.datetime, end: datetime.datetime
    ) -> list[dict]:
        """A calendar's events in a range."""
        return self.dav.events(calendar, start, end, server_expands=True)

    def create(self, calendar: str, event: dict) -> None:
        """Adds an event; with attendees, the account is the organizer."""
        uid = str(uuid.uuid4())
        entry = new_event(uid, event)
        attendees = event.get("attendees") or []
        if attendees:
            add_attendees(entry, self.organizer(), attendees)
        self.dav.put(calendar, uid, entry)

    def delete(self, href: str, etag: str, occurrence: str = "") -> None:
        """Removes an event, or one occurrence of a repeating one."""
        self.dav.delete(href, etag, occurrence)

    def organizer(self) -> str:
        """The account's own e-mail address, which invitations are sent from."""
        principal = f"remote.php/dav/principals/users/{urllib.parse.quote(self.login)}/"
        for address in self.dav.addresses(principal):
            if address.lower().startswith("mailto:"):
                return address
        raise CalendarError(5, "the account has no e-mail address for invitations")
