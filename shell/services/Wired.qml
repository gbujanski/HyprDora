pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.base

// The wired connection: the first Ethernet device NetworkManager manages, its state, and the saved
// connection it uses, from nmcli, as Quickshell.Networking knows only Wi-Fi. The details shown on its page
// (address, gateway, DNS, link speed, metered) are read while the page is open.
Singleton {
    id: root

    property string device: ""
    // "connected", "disconnected" (a cable, but not connected), "unavailable" (no cable), or a step of
    // connecting such as "connecting (getting IP configuration)".
    property string state: ""
    readonly property bool connected: state === "connected"
    // Whether a cable is in, so the connection can be brought up.
    readonly property bool cable: device !== "" && state !== "unavailable"
    readonly property bool connecting: state.startsWith("connecting")

    // The saved connection: the one up on the device, or else the first wired one.
    property string uuid: ""
    property string name: ""
    property string address: ""
    property string gateway: ""
    property string dns: ""
    // Link speed in Mb/s; 0 when unknown.
    property int speed: 0
    // "yes", "no", or "unknown" for NetworkManager's guess.
    property string metered: "unknown"
    property string error: ""

    /**
     * Splits a line of nmcli's terse output, where a colon inside a value is escaped.
     * @param {string} line  terse line
     * @returns {list} the values
     */
    function fields(line) {
        return line.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"));
    }

    /** Reads the details shown on the wired page. */
    function refresh() {
        if (device !== "" && !connectionCheck.running)
            connectionCheck.running = true;
    }

    /** Brings the wired connection up, or takes it down. */
    function setConnected(on) {
        if (device === "" || action.running)
            return;
        error = "";
        action.command = ["env", "LC_ALL=C", "nmcli", "device", on ? "connect" : "disconnect", device];
        action.running = true;
    }

    /**
     * Marks the wired connection as metered or not, for good.
     * @param {bool} on  metered
     */
    function setMetered(on) {
        if (uuid === "" || action.running)
            return;
        error = "";
        action.command = ["nmcli", "connection", "modify", uuid, "connection.metered", on ? "yes" : "no"];
        action.running = true;
    }

    Process {
        id: deviceCheck
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device"]
        running: true
        stdout: StdioCollector {
            // Container interfaces show as unmanaged Ethernet, so only managed ones count.
            onStreamFinished: {
                const wired = text.split("\n").map(root.fields).find(f => f[1] === "ethernet" && f[2] && f[2] !== "unmanaged");
                root.device = wired?.[0] ?? "";
                root.state = wired?.[2] ?? "";
            }
        }
    }

    EventSubscription {
        stream: "network"
        onEvent: deviceDelay.restart()
    }

    Timer {
        id: deviceDelay
        interval: 500
        onTriggered: {
            if (!deviceCheck.running)
                deviceCheck.running = true;
        }
    }

    // Saved connections as "uuid:type:device:name"; the device is empty for one not up.
    Process {
        id: connectionCheck
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "UUID,TYPE,DEVICE,NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const wired = text.split("\n").map(root.fields).filter(f => f[1] === "802-3-ethernet");
                const chosen = wired.find(f => f[2] === root.device) ?? wired[0];
                root.uuid = chosen?.[0] ?? "";
                root.name = chosen?.slice(3).join(":") ?? "";
                if (!detailCheck.running) {
                    detailCheck.command = ["sh", "-c", 'export LC_ALL=C; nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,CAPABILITIES.SPEED device show "$1"; [ -n "$2" ] && printf "METERED:%s\\n" "$(nmcli -g connection.metered connection show "$2")"', "hyprdora-wired", root.device, root.uuid];
                    detailCheck.running = true;
                }
            }
        }
    }

    // Lines such as "IP4.ADDRESS[1]:192.168.1.20/24", "CAPABILITIES.SPEED:1000 Mb/s" and "METERED:no".
    Process {
        id: detailCheck
        stdout: StdioCollector {
            onStreamFinished: {
                const values = {};
                const dns = [];
                for (const line of text.split("\n")) {
                    const [key, ...rest] = root.fields(line);
                    const value = rest.join(":");
                    if (key.startsWith("IP4.DNS"))
                        dns.push(value);
                    else if (values[key.replace(/\[\d+\]$/, "")] === undefined)
                        values[key.replace(/\[\d+\]$/, "")] = value;
                }
                root.address = values["IP4.ADDRESS"] ?? "";
                root.gateway = values["IP4.GATEWAY"] ?? "";
                root.dns = dns.join(", ");
                root.speed = parseInt(values["CAPABILITIES.SPEED"] ?? "") || 0;
                root.metered = values["METERED"] || "unknown";
            }
        }
    }

    Process {
        id: action
        stderr: StdioCollector {
            id: actionErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.error = actionErrors.text.trim().split("\n").pop() ?? "";
            root.refresh();
        }
    }
}
