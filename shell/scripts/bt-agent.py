#!/usr/bin/env python3
"""BlueZ pairing agent for the action center.

Quickshell.Bluetooth does not register an agent, so devices that need a PIN or
code confirmation could not pair without this process. It runs only while the
Bluetooth page is in use.

Stdout (JSON lines):
    {"event": "ready"}
    {"event": "request", "id": 1, "kind": "confirm", "device": "...", "value": "123456"}
    {"event": "display", "device": "...", "value": "123456"}
    {"event": "cancel"}
Values of "kind": pin, passkey, confirm, authorize, authorize-service.

Stdin (JSON lines):
    {"id": 1, "accept": true, "value": "1234"}
"""

import json
import os
import signal
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

try:
    from gi.repository import GLibUnix

    add_unix_signal = GLibUnix.signal_add
except ImportError:
    add_unix_signal = GLib.unix_signal_add

BLUEZ = "org.bluez"
AGENT_PATH = "/org/hyprdora/agent"
CAPABILITY = "KeyboardDisplay"
REJECTED = "org.bluez.Error.Rejected"

INTROSPECTION = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode">
      <arg type="o" direction="in"/><arg type="s" direction="out"/>
    </method>
    <method name="DisplayPinCode">
      <arg type="o" direction="in"/><arg type="s" direction="in"/>
    </method>
    <method name="RequestPasskey">
      <arg type="o" direction="in"/><arg type="u" direction="out"/>
    </method>
    <method name="DisplayPasskey">
      <arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/>
    </method>
    <method name="RequestConfirmation">
      <arg type="o" direction="in"/><arg type="u" direction="in"/>
    </method>
    <method name="RequestAuthorization">
      <arg type="o" direction="in"/>
    </method>
    <method name="AuthorizeService">
      <arg type="o" direction="in"/><arg type="s" direction="in"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>
"""


def emit(**message):
    """Print one JSON line to the shell."""
    print(json.dumps(message), flush=True)


def build_reply(kind, value):
    """Return the reply variant, or None when the value is invalid."""
    if kind == "pin":
        return GLib.Variant("(s)", (value,)) if 1 <= len(value) <= 16 else None
    if kind == "passkey":
        if value.isdigit() and int(value) <= 999999:
            return GLib.Variant("(u)", (int(value),))
        return None
    return GLib.Variant("()", ())


class Agent:
    """org.bluez.Agent1 implementation that forwards requests to the shell."""

    def __init__(self, bus, loop):
        self.bus = bus
        self.loop = loop
        self.pending = {}
        self.next_id = 1
        self.input_buffer = b""

    def device_name(self, path):
        """Return a device's alias, or its address when unavailable."""
        try:
            reply = self.bus.call_sync(
                BLUEZ, path, "org.freedesktop.DBus.Properties", "Get",
                GLib.Variant("(ss)", ("org.bluez.Device1", "Alias")),
                GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, 2000, None,
            )
            return reply.unpack()[0]
        except GLib.Error:
            return path.rsplit("/", 1)[-1].removeprefix("dev_").replace("_", ":")

    def request(self, invocation, kind, device, value=""):
        """Store a pending call and ask the shell to answer it."""
        request_id = self.next_id
        self.next_id += 1
        self.pending[request_id] = (invocation, kind)
        emit(event="request", id=request_id, kind=kind, device=self.device_name(device), value=value)

    def on_method(self, _conn, _sender, _path, _iface, method, params, invocation):
        args = params.unpack()
        if method == "Release":
            invocation.return_value(None)
            self.loop.quit()
        elif method == "Cancel":
            for pending, _kind in self.pending.values():
                pending.return_dbus_error("org.bluez.Error.Canceled", "Canceled")
            self.pending.clear()
            invocation.return_value(None)
            emit(event="cancel")
        elif method == "RequestPinCode":
            self.request(invocation, "pin", args[0])
        elif method == "RequestPasskey":
            self.request(invocation, "passkey", args[0])
        elif method == "RequestConfirmation":
            self.request(invocation, "confirm", args[0], f"{args[1]:06d}")
        elif method == "RequestAuthorization":
            self.request(invocation, "authorize", args[0])
        elif method == "AuthorizeService":
            self.request(invocation, "authorize-service", args[0], args[1])
        elif method == "DisplayPinCode":
            emit(event="display", device=self.device_name(args[0]), value=args[1])
            invocation.return_value(None)
        elif method == "DisplayPasskey":
            emit(event="display", device=self.device_name(args[0]), value=f"{args[1]:06d}")
            invocation.return_value(None)

    def answer(self, message):
        """Complete a pending call with the shell's response."""
        entry = self.pending.pop(message.get("id"), None)
        if entry is None:
            return
        invocation, kind = entry
        reply = build_reply(kind, str(message.get("value", ""))) if message.get("accept") else None
        if reply is None:
            invocation.return_dbus_error(REJECTED, "Rejected")
        else:
            invocation.return_value(reply)

    def on_stdin(self, fd, _condition):
        """Read responses from stdin and quit when it closes."""
        data = os.read(fd, 4096)
        if not data:
            self.loop.quit()
            return GLib.SOURCE_REMOVE
        self.input_buffer += data
        *lines, self.input_buffer = self.input_buffer.split(b"\n")
        for line in lines:
            try:
                self.answer(json.loads(line))
            except ValueError:
                pass
        return GLib.SOURCE_CONTINUE


def main():
    """Register the agent, run until stopped and return an exit code."""
    loop = GLib.MainLoop()
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    agent = Agent(bus, loop)
    info = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION).interfaces[0]
    registration = bus.register_object_with_closures2(AGENT_PATH, info, agent.on_method, None, None)

    def manager(method, args):
        return bus.call_sync(
            BLUEZ, "/org/bluez", "org.bluez.AgentManager1", method, args,
            None, Gio.DBusCallFlags.NONE, 5000, None,
        )

    try:
        manager("RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, CAPABILITY)))
        manager("RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,)))
    except GLib.Error as error:
        emit(event="error", detail=error.message)
        return 1

    GLib.io_add_watch(sys.stdin.fileno(), GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN | GLib.IOCondition.HUP, agent.on_stdin)
    for signum in (signal.SIGTERM, signal.SIGINT):
        add_unix_signal(GLib.PRIORITY_DEFAULT, signum, lambda: (loop.quit(), GLib.SOURCE_REMOVE)[1])

    emit(event="ready")
    loop.run()

    try:
        manager("UnregisterAgent", GLib.Variant("(o)", (AGENT_PATH,)))
    except GLib.Error:
        pass
    bus.unregister_object(registration)
    return 0


if __name__ == "__main__":
    sys.exit(main())
