#!/usr/bin/env python3
"""Set the computer's name through systemd-hostnamed.

Arguments: the pretty name, such as "HyprDora", and the network name made
from it, such as hyprdora. Both go through one process, so the polkit
agent asks for the administrator password once (hostnamed allows auth_admin_keep).

Exit status 0 on success; otherwise the reason is on stderr.
"""

import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib


def main():
    if len(sys.argv) != 3 or not sys.argv[2]:
        print("usage: set-hostname.py PRETTY STATIC", file=sys.stderr)
        return 2
    pretty, static = sys.argv[1], sys.argv[2]
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
        for method, value in (("SetStaticHostname", static), ("SetPrettyHostname", pretty)):
            bus.call_sync(
                "org.freedesktop.hostname1",
                "/org/freedesktop/hostname1",
                "org.freedesktop.hostname1",
                method,
                GLib.Variant("(sb)", (value, True)),
                None,
                Gio.DBusCallFlags.ALLOW_INTERACTIVE_AUTHORIZATION,
                120000,
                None,
            )
    except GLib.Error as error:
        print(Gio.DBusError.get_remote_error(error) or error.message, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
