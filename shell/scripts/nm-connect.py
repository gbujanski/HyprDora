#!/usr/bin/env python3
"""Connect to a new Wi-Fi network through NetworkManager's D-Bus API.

Quickshell.Networking does not accept a password, and passing one to nmcli as
an argument would expose it in the process list. The request therefore arrives
as one line of JSON on stdin:
    {"ssid": "...", "password": "...", "hidden": false}

The result is one line of JSON on stdout:
    {"ok": true} or {"ok": false, "reason": "...", ...}

After a failed attempt the profile is deleted, so no wrong password remains.
The password never reaches output or logs.
"""

import json
import signal
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

try:
    from gi.repository import GLibUnix  # noqa: E402

    add_unix_signal = GLibUnix.signal_add
except ImportError:
    add_unix_signal = GLib.unix_signal_add

NM = "org.freedesktop.NetworkManager"
NM_PATH = "/org/freedesktop/NetworkManager"
PROPS = "org.freedesktop.DBus.Properties"
DEVICE_TYPE_WIFI = 2
ACTIVE_ACTIVATED = 2
ACTIVE_DEACTIVATED = 4
ACTIVE_REASON_WRONG_PASSWORD = {9, 10}  # NO_SECRETS, LOGIN_FAILED
DEVICE_REASON_WRONG_PASSWORD = {7, 8}  # NO_SECRETS, SUPPLICANT_DISCONNECT
TIMEOUT_SECONDS = 45


def finish(**result):
    """Print the result as one line of JSON."""
    print(json.dumps(result), flush=True)


class Connector:
    """One connection attempt driven by NetworkManager signals."""

    def __init__(self, request):
        self.request = request
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
        self.loop = GLib.MainLoop()
        self.settings_path = None
        self.active_path = None
        self.device_reason = 0
        self.result = None

    def call(self, path, interface, method, args, reply):
        """Call a NetworkManager method and return its unpacked reply."""
        return self.bus.call_sync(
            NM, path, interface, method, args,
            GLib.VariantType(reply) if reply else None,
            Gio.DBusCallFlags.NONE, -1, None,
        ).unpack()

    def prop(self, path, interface, name):
        """Return a D-Bus property value."""
        return self.call(path, PROPS, "Get", GLib.Variant("(ss)", (interface, name)), "(v)")[0]

    def wifi_device(self):
        """Return the path of the first Wi-Fi device, or None."""
        for path in self.call(NM_PATH, NM, "GetDevices", None, "(ao)")[0]:
            if self.prop(path, NM + ".Device", "DeviceType") == DEVICE_TYPE_WIFI:
                return path
        return None

    def strongest_access_point(self, device, ssid):
        """Return the path of the strongest access point for an SSID, or None."""
        best, best_strength = None, -1
        wanted = ssid.encode()
        for path in self.prop(device, NM + ".Device.Wireless", "AccessPoints"):
            if bytes(self.prop(path, NM + ".AccessPoint", "Ssid")) != wanted:
                continue
            strength = self.prop(path, NM + ".AccessPoint", "Strength")
            if strength > best_strength:
                best, best_strength = path, strength
        return best

    def connection_settings(self):
        """Build the NetworkManager settings for the requested network."""
        ssid = self.request["ssid"]
        password = self.request.get("password") or ""
        hidden = bool(self.request.get("hidden"))
        wireless = {"ssid": GLib.Variant("ay", ssid.encode())}
        if hidden:
            wireless["hidden"] = GLib.Variant("b", True)
        settings = {
            "connection": {
                "id": GLib.Variant("s", ssid),
                "type": GLib.Variant("s", "802-11-wireless"),
            },
            "802-11-wireless": wireless,
        }
        if password:
            security = {"psk": GLib.Variant("s", password)}
            # For a visible network, NetworkManager picks the mode from the access point.
            if hidden:
                security["key-mgmt"] = GLib.Variant("s", "wpa-psk")
            settings["802-11-wireless-security"] = security
        return settings

    def conclude(self, **result):
        """Record the first result, delete a failed profile and stop the loop."""
        if self.result is not None:
            return
        self.result = result
        if not result.get("ok") and self.settings_path:
            try:
                self.call(self.settings_path, NM + ".Settings.Connection", "Delete", None, None)
            except GLib.Error:
                pass
        self.loop.quit()

    def on_device_state(self, _conn, _sender, _path, _iface, _signal, params):
        _new, _old, reason = params.unpack()
        if reason:
            self.device_reason = reason

    def on_active_state(self, _conn, _sender, _path, _iface, _signal, params):
        state, reason = params.unpack()
        self.handle_active_state(state, reason)

    def handle_active_state(self, state, reason):
        """Conclude when the connection activates or fails."""
        if state == ACTIVE_ACTIVATED:
            self.conclude(ok=True)
        elif state == ACTIVE_DEACTIVATED:
            wrong_password = (
                reason in ACTIVE_REASON_WRONG_PASSWORD
                or self.device_reason in DEVICE_REASON_WRONG_PASSWORD
            )
            self.conclude(
                ok=False,
                reason="wrong_password" if wrong_password else "failed",
                activeReason=reason,
                deviceReason=self.device_reason,
            )

    def on_timeout(self):
        self.conclude(ok=False, reason="timeout", deviceReason=self.device_reason)
        return GLib.SOURCE_REMOVE

    def on_terminate(self):
        self.conclude(ok=False, reason="cancelled")
        return GLib.SOURCE_REMOVE

    def run(self):
        """Start the connection and return the result as a dict."""
        ssid = self.request.get("ssid") or ""
        if not ssid:
            return {"ok": False, "reason": "invalid_request"}
        device = self.wifi_device()
        if device is None:
            return {"ok": False, "reason": "no_device"}

        hidden = bool(self.request.get("hidden"))
        access_point = "/"
        if not hidden:
            access_point = self.strongest_access_point(device, ssid)
            if access_point is None:
                return {"ok": False, "reason": "not_found"}

        self.bus.signal_subscribe(
            NM, NM + ".Device", "StateChanged", device, None,
            Gio.DBusSignalFlags.NONE, self.on_device_state,
        )
        try:
            self.settings_path, self.active_path = self.call(
                NM_PATH, NM, "AddAndActivateConnection",
                GLib.Variant("(a{sa{sv}}oo)", (self.connection_settings(), device, access_point)),
                "(oo)",
            )
        except GLib.Error as error:
            return {"ok": False, "reason": "rejected", "detail": error.message}

        self.bus.signal_subscribe(
            NM, NM + ".Connection.Active", "StateChanged", self.active_path, None,
            Gio.DBusSignalFlags.NONE, self.on_active_state,
        )
        GLib.timeout_add_seconds(TIMEOUT_SECONDS, self.on_timeout)
        add_unix_signal(GLib.PRIORITY_DEFAULT, signal.SIGTERM, self.on_terminate)

        # The state may have changed before the subscription.
        try:
            self.handle_active_state(self.prop(self.active_path, NM + ".Connection.Active", "State"), 0)
        except GLib.Error:
            pass
        if self.result is None:
            self.loop.run()
        return self.result


def main():
    """Read the request from stdin and return an exit code."""
    try:
        request = json.loads(sys.stdin.readline())
    except ValueError:
        finish(ok=False, reason="invalid_request")
        return 1
    result = Connector(request).run()
    finish(**result)
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
