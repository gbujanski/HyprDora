#!/usr/bin/python3
"""Wallpaper portal backend: lets any application set the HyprDora wallpaper.

xdg-desktop-portal forwards org.freedesktop.portal.Wallpaper calls here, for example from
"Set as Background" in Nautilus or Loupe. The image goes to the shell, which shows and keeps it.
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
        if method != "SetWallpaperURI":
            invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", method)
            return
        _handle, _app_id, _window, uri, options = parameters.unpack()
        invocation.return_value(GLib.Variant("(u)", (set_wallpaper(uri, options),)))

    def on_bus(connection, _name):
        info = Gio.DBusNodeInfo.new_for_xml(INTERFACE).interfaces[0]
        connection.register_object_with_closures2(OBJECT_PATH, info, on_call, None, None)

    Gio.bus_own_name(Gio.BusType.SESSION, BUS_NAME, Gio.BusNameOwnerFlags.NONE, on_bus, None, lambda *_: loop.quit())
    restart_idle_timer()
    loop.run()


if __name__ == "__main__":
    main()
