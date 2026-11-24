#!/usr/bin/python3
"""HyprDora's portal backend: the wallpaper, and the accent color.

xdg-desktop-portal forwards org.freedesktop.portal.Wallpaper calls here, for example from
"Set as Background" in Nautilus or Loupe. The image goes to the shell, which shows and keeps it.

It also answers the accent color for org.freedesktop.portal.Settings, which libadwaita applications read
their accent from, Flatpaks among them. xdg-desktop-portal-gtk gives the dark style but no accent, so without
this they stay blue. The accent is GNOME's setting, org.gnome.desktop.interface accent-color, green in
HyprDora; libadwaita takes the nearest of its own accents, so it is given as GNOME draws it. Every other
setting comes from xdg-desktop-portal-gtk. The service exits when idle, so a change of the accent reaches
applications started after it.

QML cannot export a D-Bus object, so this small service does it.
"""

import os
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

from gi.repository import Gio, GLib

BUS_NAME = "org.freedesktop.impl.portal.desktop.hyprdora"
OBJECT_PATH = "/org/freedesktop/portal/desktop"
INTERFACE = """
<node>
  <interface name="org.freedesktop.impl.portal.Settings">
    <method name="ReadAll">
      <arg type="as" name="namespaces" direction="in"/>
      <arg type="a{sa{sv}}" name="value" direction="out"/>
    </method>
    <method name="Read">
      <arg type="s" name="namespace" direction="in"/>
      <arg type="s" name="key" direction="in"/>
      <arg type="v" name="value" direction="out"/>
    </method>
    <signal name="SettingChanged">
      <arg type="s" name="namespace"/>
      <arg type="s" name="key"/>
      <arg type="v" name="value"/>
    </signal>
    <property name="version" type="u" access="read"/>
  </interface>
  <interface name="org.freedesktop.impl.portal.Wallpaper">
    <method name="SetWallpaperURI">
      <arg type="o" name="handle" direction="in"/>
      <arg type="s" name="app_id" direction="in"/>
      <arg type="s" name="parent_window" direction="in"/>
      <arg type="s" name="uri" direction="in"/>
      <arg type="a{sv}" name="options" direction="in"/>
      <arg type="u" name="response" direction="out"/>
    </method>
  </interface>
</node>
"""
# Portal response codes.
SUCCESS = 0
FAILED = 2
# The service exits when unused; D-Bus starts it again on the next call.
IDLE_SECONDS = 60
SETTINGS_VERSION = 2
APPEARANCE = "org.freedesktop.appearance"
# GNOME's accents as libadwaita draws them, by their name in accent-color.
ACCENTS = {
    "blue": "#3584e4",
    "teal": "#2190a4",
    "green": "#3a944a",
    "yellow": "#c88800",
    "orange": "#ed5b00",
    "red": "#e62d42",
    "pink": "#d56199",
    "purple": "#9141ac",
    "slate": "#6f8396",
}


def kept_copy(path):
    """Copies a file from the runtime directory, which is cleared at logout, to a lasting place.

    Args:
        path: image path given by the portal.

    Returns:
        A path that stays valid across sessions.
    """
    runtime = os.environ.get("XDG_RUNTIME_DIR", "/run/user")
    if not path.startswith(runtime + "/"):
        return path
    data = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
    folder = data / "hyprdora" / "wallpapers"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / Path(path).name
    shutil.copyfile(path, target)
    return str(target)


def set_wallpaper(uri, options):
    """Hands an image to the shell.

    Args:
        uri: file URI of the image.
        options: portal options; "set-on" may name the lock screen only.

    Returns:
        A portal response code.
    """
    if options.get("set-on", "both") == "lockscreen":
        return FAILED
    parsed = urlparse(uri)
    if parsed.scheme != "file":
        return FAILED
    try:
        path = kept_copy(unquote(parsed.path))
        result = subprocess.run(
            ["qs", "-c", "hyprdora", "ipc", "call", "wallpaper", "set", path],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as error:
        print(f"hyprdora-portal: {error}", file=sys.stderr)
        return FAILED
    return SUCCESS if result.stdout.strip() == "true" else FAILED


def accent():
    """Reads GNOME's accent setting.

    Returns:
        The accent as the portal gives it: red, green and blue from 0 to 1.
    """
    name = Gio.Settings.new("org.gnome.desktop.interface").get_string("accent-color")
    color = ACCENTS.get(name, ACCENTS["green"])
    return GLib.Variant("(ddd)", tuple(int(color[i : i + 2], 16) / 255 for i in (1, 3, 5)))


def wanted(namespace, patterns):
    """Tells whether ReadAll asks for a namespace.

    Args:
        namespace: a settings namespace.
        patterns: namespaces asked for, each whole or ending in "*"; none means all.

    Returns:
        True when the namespace is asked for.
    """
    if not patterns:
        return True
    return any(namespace.startswith(p[:-1]) if p.endswith("*") else namespace == p for p in patterns)


def main():
    """Registers the portal backend on the session bus and serves calls until idle."""
    loop = GLib.MainLoop()
    idle = {"source": 0}

    def restart_idle_timer():
        if idle["source"]:
            GLib.source_remove(idle["source"])
        idle["source"] = GLib.timeout_add_seconds(IDLE_SECONDS, loop.quit)

    def on_call(_connection, _sender, _path, _interface, method, parameters, invocation):
        restart_idle_timer()
        if method == "SetWallpaperURI":
            _handle, _app_id, _window, uri, options = parameters.unpack()
            invocation.return_value(GLib.Variant("(u)", (set_wallpaper(uri, options),)))
        elif method == "ReadAll":
            (patterns,) = parameters.unpack()
            found = {APPEARANCE: {"accent-color": accent()}} if wanted(APPEARANCE, patterns) else {}
            invocation.return_value(GLib.Variant("(a{sa{sv}})", (found,)))
        elif method == "Read":
            namespace, key = parameters.unpack()
            if (namespace, key) == (APPEARANCE, "accent-color"):
                invocation.return_value(GLib.Variant("(v)", (accent(),)))
            else:
                # xdg-desktop-portal then asks the next backend, xdg-desktop-portal-gtk.
                invocation.return_dbus_error("org.freedesktop.portal.Error.NotFound", f"{namespace} {key}")
        else:
            invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)

    def on_property(_connection, _sender, _path, _interface, _name):
        return GLib.Variant("u", SETTINGS_VERSION)

    def on_bus(connection, _name):
        for info in Gio.DBusNodeInfo.new_for_xml(INTERFACE).interfaces:
            connection.register_object_with_closures2(OBJECT_PATH, info, on_call, on_property, None)

    Gio.bus_own_name(Gio.BusType.SESSION, BUS_NAME, Gio.BusNameOwnerFlags.NONE, on_bus, None, lambda *_: loop.quit())
    restart_idle_timer()
    loop.run()


if __name__ == "__main__":
    main()
