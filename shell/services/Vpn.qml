pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// VPN connections kept by NetworkManager: WireGuard and OpenVPN. Quickshell.Networking does not cover them,
// so they are read and changed with nmcli, which also makes them work outside the shell.
ConnectionService {
    id: root

    // [{ uuid, name, kind: "wireguard" | "openvpn" | "vpn", state: "" | "activating" | "activated" }]
    property var connections: []
    readonly property var active: connections.find(c => c.state === "activated") ?? null
    readonly property var activating: connections.find(c => c.state === "activating") ?? null
    readonly property bool connected: active !== null

    // The state in one line, an icon and a tooltip, for the bar and the action center's tile.
    stateBusy: busy !== "" || activating !== null
    connectedName: active?.name ?? ""
    idleText: connections.length === 0 ? I18n.t("vpn.none") : I18n.t("vpn.disconnected")
    statusIcon: Icons.vpn
    statusTooltip: I18n.t("vpn.barTooltip", {
        name: active?.name ?? ""
    })
    property string busy: ""
    property string error: ""

    /**
     * Splits a terse nmcli line on the colons nmcli does not escape.
     * @param {string} line  output line
     * @returns {list} fields
     */
    function fields(line) {
        const result = [];
        let current = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) {
                current += line[++i];
            } else if (line[i] === ":") {
                result.push(current);
                current = "";
            } else {
                current += line[i];
            }
        }
        result.push(current);
        return result;
    }

    /**
     * Formats a byte count briefly, such as 1.2 MB.
     * @param {real} bytes  byte count
     * @returns {string}
     */
    function formatBytes(bytes) {
        const units = ["B", "kB", "MB", "GB", "TB"];
        let value = bytes;
        let unit = 0;
        while (value >= 1000 && unit < units.length - 1) {
            value /= 1000;
            unit++;
        }
        return `${value.toFixed(unit === 0 || value >= 100 ? 0 : 1)} ${units[unit]}`;
    }

    /** Reads the connections and their state again. */
    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    /**
     * Runs an nmcli command for a connection and shows its error, if any.
     * @param {string} uuid  connection being changed, shown as busy
     * @param {list} args  nmcli arguments
     */
    function run(uuid, args) {
        if (runner.running)
            return;
        error = "";
        busy = uuid;
        runner.command = ["env", "LC_ALL=C", "nmcli", ...args];
        runner.running = true;
    }

    /**
     * Connects a VPN and remembers it for the tile.
     * @param {string} uuid  connection
     */
    function connect(uuid) {
        Settings.setIn("vpn", "last", uuid);
        run(uuid, ["connection", "up", "uuid", uuid]);
    }

    /**
     * Disconnects a VPN.
     * @param {string} uuid  connection
     */
    function disconnect(uuid) {
        run(uuid, ["connection", "down", "uuid", uuid]);
    }

    /**
     * Deletes a VPN connection.
     * @param {string} uuid  connection
     */
    function remove(uuid) {
        run(uuid, ["connection", "delete", "uuid", uuid]);
    }

    /**
     * Imports a WireGuard .conf or an OpenVPN .ovpn file.
     * @param {string} path  file path
     */
    function importFile(path) {
        const type = path.toLowerCase().endsWith(".ovpn") ? "openvpn" : "wireguard";
        if (runner.running)
            return;
        error = "";
        busy = "import";
        // NetworkManager connects an imported connection at once and at every boot; a VPN should start only
        // when asked, so it is switched to manual and disconnected.
        runner.command = ["sh", "-c", 'export LC_ALL=C; out=$(nmcli connection import type "$1" file "$2") || exit 1; uuid=$(printf "%s" "$out" | sed -n "s/.*(\\(.*\\)) successfully added.*/\\1/p"); [ -n "$uuid" ] || exit 0; nmcli connection modify "$uuid" connection.autoconnect no; nmcli connection down "$uuid" >/dev/null 2>&1; exit 0', "hyprdora-vpn-import", type, path];
        runner.running = true;
    }

    /**
     * Asks for a file to import. The dialog is an ordinary window, which the action center would cover,
     * so the panel closes meanwhile and comes back on the VPN page.
     */
    function chooseFile() {
        Panels.close("actioncenter");
        if (!fileDialog.running)
            fileDialog.running = true;
    }

    /** Disconnects the active VPN, or connects the one used last. */
    function toggle() {
        if (active) {
            disconnect(active.uuid);
            return;
        }
        const last = connections.find(c => c.uuid === Settings.overrides.vpn?.last) ?? connections[0];
        if (last)
            connect(last.uuid);
    }

    // zenity rather than QtQuick.Dialogs, whose dialog does not open from a shell without a window.
    Process {
        id: fileDialog

        command: ["zenity", "--file-selection", `--title=${I18n.t("vpn.import")}`, `--file-filter=${I18n.t("vpn.fileFilter")} | *.conf *.ovpn`]

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    root.importFile(path);
                Panels.openActionCenter(null, "vpn");
            }
        }
    }

    Process {
        id: reader

        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "NAME,UUID,TYPE,STATE,DEVICE", "connection", "show"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.connections = text.split("\n").filter(Boolean).map(root.fields).filter(f => f[2] === "wireguard" || f[2] === "vpn").map(f => ({
                        name: f[0],
                        uuid: f[1],
                        kind: f[2] === "wireguard" ? "wireguard" : "openvpn",
                        state: f[3] ?? "",
                        device: f[4] ?? ""
                    })).sort((a, b) => a.name.localeCompare(b.name))
        }
    }

    Process {
        id: runner

        stderr: StdioCollector {
            id: runnerErrors
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                const message = runnerErrors.text.trim().split("\n").pop();
                // OpenVPN with a login asks for a password, which needs a prompt the shell does not have yet.
                root.error = /secrets|password/i.test(message) ? I18n.t("vpn.error.password") : I18n.t("vpn.error.failed", {
                    message: message
                });
                console.warn("vpn:", runnerErrors.text.trim());
            }
            root.busy = "";
            root.refresh();
        }
    }

    // NetworkManager reports every change, such as a VPN dropping on its own.
    Process {
        // setpriv ends the monitor together with the shell, so a restart leaves no stray process.
        command: ["setpriv", "--pdeathsig", "TERM", "env", "LC_ALL=C", "nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: refreshDelay.restart()
        }
    }

    Timer {
        id: refreshDelay
        interval: 400
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "vpn"

        function describe(): string {
            return JSON.stringify({
                connections: root.connections,
                busy: root.busy,
                error: root.error
            });
        }
        function toggle(): void {
            root.toggle();
        }
    }
}
