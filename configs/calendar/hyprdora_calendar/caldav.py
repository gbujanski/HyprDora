"""A CalDAV client for any server: calendars, events in a range, adding and deleting.

The source gives the address, the Authorization header and how its calendars are found; a server that
expands repeating events itself is asked to, others get them expanded here.
"""

import datetime
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

import icalendar

from .core import (
    CalendarError,
    describe,
    document_of,
    occurrences,
    without_occurrence,
)

DAV = "DAV:"
CALDAV = "urn:ietf:params:xml:ns:caldav"
APPLE = "http://apple.com/ns/ical/"
NS = {"d": DAV, "c": CALDAV, "a": APPLE}
TIMEOUT = 15
XML = "application/xml; charset=utf-8"
ICS = "text/calendar; charset=utf-8"


class CalDAV:
    """Requests to one CalDAV server for one account."""

    def __init__(
        self, base: str, authorization: str, account: str, rejected: str
    ) -> None:
        """
        base           the server's address; paths are resolved against it
        authorization  the Authorization header
        account        the account's key, which the shell keeps calendars under
        rejected       the message for a refused login
        """
        self.base = base.rstrip("/") + "/"
        self.authorization = authorization
        self.account = account
        self.rejected = rejected

    def url(self, href: str) -> str:
        """Returns the absolute address of a path on the server."""
        return urllib.parse.urljoin(self.base, href)

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
                "Authorization": self.authorization,
                "User-Agent": "HyprDora",
                **(headers or {}),
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
                return response.status, response.read(), dict(response.headers)
        except urllib.error.HTTPError as error:
            if error.code == 401:
                raise CalendarError(3, self.rejected) from error
            raise CalendarError(5, f"{method} {href}: HTTP {error.code}") from error
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            raise CalendarError(4, f"{self.base}: {error}") from error

    def calendars(self, home: str) -> list[dict]:
        """Lists the calendars in a home that hold events."""
        body = b"""<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:a="http://apple.com/ns/ical/">
  <d:prop><d:resourcetype/><d:displayname/><a:calendar-color/>
    <c:supported-calendar-component-set/><d:current-user-privilege-set/></d:prop>
</d:propfind>"""
        _, reply, _ = self.request(
            "PROPFIND", home, body, {"Depth": "1", "Content-Type": XML}
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
                    "account": self.account,
                }
            )
        return result

    def events(
        self,
        calendar: dict,
        start: datetime.datetime,
        end: datetime.datetime,
        server_expands: bool,
    ) -> list[dict]:
        """Reads a calendar's events in a range, with repeating events expanded by the server or here."""
        stamp = "%Y%m%dT%H%M%SZ"
        begin = start.astimezone(datetime.UTC).strftime(stamp)
        finish = end.astimezone(datetime.UTC).strftime(stamp)
        expand = f'<c:expand start="{begin}" end="{finish}"/>' if server_expands else ""
        body = f"""<?xml version="1.0"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:getetag/><c:calendar-data>{expand}</c:calendar-data></d:prop>
  <c:filter><c:comp-filter name="VCALENDAR"><c:comp-filter name="VEVENT">
    <c:time-range start="{begin}" end="{finish}"/></c:comp-filter></c:comp-filter></c:filter>
</c:calendar-query>""".encode()
        _, reply, _ = self.request(
            "REPORT", calendar["href"], body, {"Depth": "1", "Content-Type": XML}
        )
        result = []
        for response in ET.fromstring(reply).findall("d:response", NS):
            data = response.findtext("d:propstat/d:prop/c:calendar-data", "", NS)
            if not data:
                continue
            href = response.findtext("d:href", "", NS)
            etag = response.findtext("d:propstat/d:prop/d:getetag", "", NS)
            document = icalendar.Calendar.from_ical(data)
            found = (
                document.walk("VEVENT")
                if server_expands
                else occurrences(document, start, end)
            )
            for event in found:
                result.append(describe(event, calendar, href, etag))
        return result

    def put(self, calendar: str, uid: str, entry: icalendar.Event) -> None:
        """Adds an event to a calendar, failing rather than replacing one with the same name."""
        href = calendar.rstrip("/") + f"/{uid}.ics"
        self.request(
            "PUT",
            href,
            document_of(entry),
            {"Content-Type": ICS, "If-None-Match": "*"},
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
            "PUT", href, document.to_ical(), {"Content-Type": ICS, "If-Match": current}
        )

    def addresses(self, principal: str) -> list[str]:
        """The principal's own addresses, such as mailto:someone@example.com."""
        body = b"""<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-user-address-set/></d:prop>
</d:propfind>"""
        _, reply, _ = self.request(
            "PROPFIND", principal, body, {"Depth": "0", "Content-Type": XML}
        )
        return [
            href.text or ""
            for href in ET.fromstring(reply).iterfind(
                ".//c:calendar-user-address-set/d:href", NS
            )
        ]


def add_attendees(entry: icalendar.Event, organizer: str, attendees: list[str]) -> None:
    """Makes the account the organizer and invites the attendees; the server sends the invitations."""
    entry.add("organizer", organizer)
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
