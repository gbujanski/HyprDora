pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Automations from the settings. Schedules turn Do Not Disturb, coffee or muted sound on when their hours
// start and off when they end, and on at once when the shell starts inside them. Headphones that connect
// unmute the sound. A VPN connects on any network except the listed home Wi-Fi networks, which disconnect it.
Singleton {
    id: root

    readonly property var scheduled: ["dnd", "coffee", "mute"]
    readonly property var defaults: ({
            from: 9 * 60,
            to: 18 * 60,
            days: [1, 2, 3, 4, 5]
        })

    // Whether each schedule was inside its hours at the last check; missing before the first one.
    property var inside: ({})

    // Saved Wi-Fi networks for the home list: [{ name, ssid }].
    property var savedNetworks: []

    /**
     * Returns an automation's settings with defaults filled in.
     * @param {string} name  automation
     * @returns {object}
     */
    function rule(name) {
        return Object.assign({
            enabled: false
        }, scheduled.includes(name) ? defaults : {}, Settings.automations[name] ?? {});
    }

    /**
     * Saves part of an automation's settings.
     * @param {string} name  automation
     * @param {object} changes  values to change
     */
    function update(name, changes) {
        Settings.setIn("automations", name, Object.assign({}, Settings.automations[name] ?? {}, changes));
    }

    /**
     * Whether a time falls inside a schedule. Hours may pass midnight; the day is the one they start on.
     * @param {object} schedule  { from, to, days }
     * @param {date} now  time to check
     * @returns {bool}
     */
    function within(schedule, now) {
        const minutes = now.getHours() * 60 + now.getMinutes();
        const today = (now.getDay() + 6) % 7 + 1;
        const yesterday = (today + 5) % 7 + 1;
        const days = schedule.days ?? [];
        if (schedule.from < schedule.to)
            return days.includes(today) && minutes >= schedule.from && minutes < schedule.to;
        if (schedule.from > schedule.to)
            return (days.includes(today) && minutes >= schedule.from) || (days.includes(yesterday) && minutes < schedule.to);
        return false;
    }

    /**
     * Turns what a schedule controls on or off.
     * @param {string} name  automation
     * @param {bool} on  new state
     */
    function apply(name, on) {
        switch (name) {
        case "dnd":
            Notifications.dnd = on;
            break;
        case "coffee":
            Idle.paused = on;
            break;
        case "mute":
            if (Audio.sink?.audio)
                Audio.sink.audio.muted = on;
            break;
        }
    }

    /** Acts on schedules whose hours started or ended since the last check. */
    function checkSchedules() {
        const now = new Date();
        const next = {};
        for (const name of scheduled) {
            const r = rule(name);
            const isInside = r.enabled && within(r, now);
            next[name] = isInside;
            const was = inside[name];
            if (was === undefined ? isInside : was !== isInside)
                apply(name, isInside);
        }
        inside = next;
    }

    /**
     * Formats minutes after midnight as a clock time, such as 09:30.
     * @param {int} minutes  minutes after midnight
     * @returns {string}
     */
    function clock(minutes) {
        return `${String(Math.floor(minutes / 60)).padStart(2, "0")}:${String(minutes % 60).padStart(2, "0")}`;
    }

    /** Reads the saved Wi-Fi networks again. */
    function refreshNetworks() {
        if (!networkReader.running)
            networkReader.running = true;
    }

    // Headphones: a Bluetooth output, a device that says it is a headset, or the jack's headphone port.
    readonly property bool onHeadphones: {
        const sink = Audio.sink;
        if (!sink)
            return false;
        const form = sink.properties?.["device.form-factor"] ?? "";
        const port = Audio.activePorts[sink.name] ?? "";
        return sink.name.startsWith("bluez_output") || form === "headphone" || form === "headset" || /headphone|headset/.test(port);
    }

    onOnHeadphonesChanged: {
        if (onHeadphones && rule("headphones").enabled && Audio.sink?.audio?.muted)
            Audio.sink.audio.muted = false;
    }

    // The network the VPN rule last acted on, so it acts once per change of network.
    property string lastNetwork: ""
    readonly property string currentNetwork: Network.connected ? `wifi:${Network.ssid}` : Network.wiredConnected ? "wired" : ""

    onCurrentNetworkChanged: vpnDelay.restart()

    // NetworkManager settles a new connection, and the shell reads it, over a moment.
    Timer {
        id: vpnDelay
        interval: 3000
        onTriggered: {
            const network = root.currentNetwork;
            if (network === root.lastNetwork)
                return;
            root.lastNetwork = network;
            const r = root.rule("vpn");
            if (!r.enabled || network === "" || Vpn.connections.length === 0)
                return;
            const home = network.startsWith("wifi:") && (r.homeNetworks ?? []).includes(network.slice(5));
            if (home) {
                if (Vpn.active)
                    Vpn.disconnect(Vpn.active.uuid);
            } else if (!Vpn.active) {
                const target = Vpn.connections.find(c => c.uuid === r.connection) ?? Vpn.connections[0];
                Vpn.connect(target.uuid);
            }
        }
    }

    Timer {
        interval: 30 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.checkSchedules()
    }

    // Edited hours or days apply at once, as if the clock had just reached them.
    Connections {
        target: Settings
        function onAutomationsChanged() {
            root.checkSchedules();
        }
    }

    Process {
        id: networkReader

        // Name and SSID of each saved Wi-Fi connection, one per line, separated by a tab.
        command: ["sh", "-c", `LC_ALL=C nmcli -t -f UUID,TYPE connection show | while IFS=: read -r uuid type; do
            [ "$type" = 802-11-wireless ] || continue
            printf '%s\\t%s\\n' "$(nmcli -g connection.id connection show "$uuid")" "$(nmcli -g 802-11-wireless.ssid connection show "$uuid")"
        done`]

        stdout: StdioCollector {
            onStreamFinished: root.savedNetworks = text.split("\n").filter(Boolean).map(line => {
                const [name, ssid] = line.split("\t");
                return {
                    name: name,
                    ssid: ssid || name
                };
            }).sort((a, b) => a.name.localeCompare(b.name))
        }
    }

    IpcHandler {
        target: "automations"

        function describe(): string {
            return JSON.stringify({
                inside: root.inside,
                onHeadphones: root.onHeadphones,
                network: root.currentNetwork,
                rules: Settings.automations
            });
        }
    }
}
