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

    // Mute state still being applied; tries repeat while the sound system starts, such as right after login.
    property var pendingMute: null
    property int muteTries: 0

    /**
     * Mutes or unmutes the default output through WirePlumber, which works as soon as the sound system runs,
     * unlike changing it through Quickshell before it has read the sound card's routes.
     * @param {bool} on  muted
     */
    function setMuted(on) {
        pendingMute = on;
        muteTries = 0;
        muteRetry.stop();
        muter.command = ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", on ? "1" : "0"];
        muter.running = true;
    }

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
            setMuted(on);
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

    Process {
        id: muter
        onExited: exitCode => {
            if (exitCode === 0) {
                root.pendingMute = null;
            } else if (++root.muteTries < 15) {
                muteRetry.restart();
            } else {
                console.warn("automations: could not change muting");
                root.pendingMute = null;
            }
        }
    }

    Timer {
        id: muteRetry
        interval: 2000
        onTriggered: muter.running = true
    }

    onOnHeadphonesChanged: {
        if (onHeadphones && rule("headphones").enabled && Audio.muted)
            setMuted(false);
    }

    // The network the VPN rule last acted on, so it acts once per change of network.
    property string lastNetwork: ""
    readonly property string currentNetwork: Network.connected ? `wifi:${Network.ssid}` : Network.wiredConnected ? "wired" : ""

    onCurrentNetworkChanged: {
        vpnDelay.restart();
        onHotspot = false;
        if (currentNetwork.startsWith("wifi:"))
            hotspotDelay.restart();
    }

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
                pendingMute: root.pendingMute,
                onHeadphones: root.onHeadphones,
                network: root.currentNetwork,
                onHotspot: root.onHotspot,
                rules: Settings.automations
            });
        }
    }

    // Phone hotspots: an Android hotspot marks itself as metered, and an iPhone hotspot hands out
    // addresses from 172.20.10.0/28 with the gateway at 172.20.10.1. A hotspot gets a lower autoconnect
    // priority in NetworkManager, so at start and on wake a saved fixed network in range wins, while a
    // hotspot chosen by hand stays as long as wanted.
    property bool onHotspot: false

    // The address and the metered guess arrive a moment after the connection.
    Timer {
        id: hotspotDelay
        interval: 4000
        onTriggered: {
            if (!hotspotCheck.running)
                hotspotCheck.running = true;
        }
    }

    Process {
        id: hotspotCheck

        // Prints the metered state, the gateway and the connection's id and priority.
        command: ["sh", "-c", `export LC_ALL=C
            device=$(nmcli -t -f DEVICE,TYPE,STATE device | awk -F: '$2 == "wifi" && $3 == "connected" {print $1; exit}')
            [ -n "$device" ] || exit 0
            nmcli -t -f GENERAL.METERED,IP4.GATEWAY,GENERAL.CON-UUID device show "$device"
            uuid=$(nmcli -g GENERAL.CON-UUID device show "$device")
            echo "PRIORITY:$(nmcli -g connection.autoconnect-priority connection show "$uuid")"`]

        stdout: StdioCollector {
            onStreamFinished: {
                const metered = /GENERAL\.METERED:yes/.test(text);
                const iphone = /IP4\.GATEWAY:172\.20\.10\.1\s*$/m.test(text);
                root.onHotspot = (metered || iphone) && root.currentNetwork.startsWith("wifi:");
                const uuid = /GENERAL\.CON-UUID:(\S+)/.exec(text)?.[1] ?? "";
                const priority = Number(/PRIORITY:(-?\d+)/.exec(text)?.[1] ?? 0);
                if (root.onHotspot && uuid !== "" && priority >= 0)
                    Quickshell.execDetached(["nmcli", "connection", "modify", uuid, "connection.autoconnect-priority", "-10"]);
                // An iPhone hotspot does not say it is metered, as an Android one does; set by hand, it stays.
                const active = Network.activeNetwork;
                if (iphone && active && Network.savedMetered[active.name]?.value === "unknown")
                    Network.setMetered(active, true);
            }
        }
    }
}
