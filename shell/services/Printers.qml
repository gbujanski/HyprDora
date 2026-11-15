pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Printers and scanners. Network printers that print without drivers (IPP Everywhere) are found by CUPS and
// can be added for good or removed with lpadmin, which a member of wheel may run without a password.
// Network scanners are found by sane-airscan each time an application scans, so they are only listed.
Singleton {
    id: root

    // Added printers: [{ name, uri, state: "idle" | "printing" | "disabled", isDefault }].
    property var printers: []
    // Printers found on the network and not added: [{ name, uri }].
    property var found: []
    // Scanners found on the network: [{ id, name }].
    property var scanners: []
    readonly property bool searching: printerSearch.running || scannerSearch.running
    // "" when idle, or the printer being added or removed.
    property string busy: ""
    property string error: ""

    /**
     * Turns a found printer's address into its name, such as Canon MG5700 series.
     * @param {string} uri  such as ipps://Canon%20MG5700%20series._ipps._tcp.local/
     * @returns {string}
     */
    function nameOf(uri) {
        const host = decodeURIComponent(uri.replace(/^[a-z]+:\/\//, "").split("/")[0]);
        return host.replace(/\._ipps?\._tcp\.local\.?$/, "");
    }

    /**
     * A queue name CUPS accepts, from a printer's name.
     * @param {string} name  printer name
     * @returns {string}
     */
    function queueName(name) {
        return name.replace(/[^A-Za-z0-9_-]+/g, "_").replace(/^_+|_+$/g, "") || "Printer";
    }

    /** Reads the added printers and searches the network again. */
    function refresh() {
        if (!listReader.running)
            listReader.running = true;
        if (!printerSearch.running)
            printerSearch.running = true;
        if (!scannerSearch.running)
            scannerSearch.running = true;
    }

    /**
     * Adds a found printer for good, with the driverless IPP Everywhere settings.
     * @param {object} printer  entry from found
     */
    function add(printer) {
        run(printer.name, ["lpadmin", "-p", queueName(printer.name), "-E", "-v", printer.uri, "-m", "everywhere"]);
    }

    /**
     * Removes an added printer.
     * @param {object} printer  entry from printers
     */
    function remove(printer) {
        run(printer.name, ["lpadmin", "-x", printer.name]);
    }

    /**
     * Makes a printer the one applications pick first.
     * @param {object} printer  entry from printers
     */
    function setDefault(printer) {
        run(printer.name, ["lpadmin", "-d", printer.name]);
    }

    /**
     * Runs an lpadmin command and reads the printers again.
     * @param {string} name  printer shown as busy
     * @param {list} command  command and arguments
     */
    function run(name, command) {
        if (busy !== "")
            return;
        busy = name;
        error = "";
        changer.command = ["env", "LC_ALL=C", ...command];
        changer.running = true;
    }

    /** Opens the scanning application. */
    function scan() {
        Launcher.exec("simple-scan");
    }

    /** Opens the full printer settings. */
    function openSettings() {
        Launcher.exec("system-config-printer");
    }

    // Added printers, their states and the default, in one go.
    Process {
        id: listReader

        command: ["sh", "-c", "export LC_ALL=C; lpstat -v 2>/dev/null; echo '--'; lpstat -p 2>/dev/null; echo '--'; lpstat -d 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const [devices, states, fallback] = text.split("--\n");
                const defaultName = /destination: (\S+)/.exec(fallback ?? "")?.[1] ?? "";
                const list = [];
                for (const line of (devices ?? "").split("\n")) {
                    const m = /^device for (\S+): (\S+)/.exec(line);
                    if (!m)
                        continue;
                    const status = new RegExp(`^printer ${m[1].replace(/[.*+?^${}()|[\]\\]/g, "\\$&")} (.*)$`, "m").exec(states ?? "")?.[1] ?? "";
                    list.push({
                        name: m[1],
                        uri: m[2],
                        state: /disabled/.test(status) ? "disabled" : /printing/.test(status) ? "printing" : "idle",
                        isDefault: m[1] === defaultName
                    });
                }
                root.printers = list;
                root.found = root.found.filter(f => !list.some(p => p.uri === f.uri || p.name === root.queueName(f.name)));
            }
        }
    }

    // Network printers that print without drivers; each may answer over ipp and ipps, so names are joined.
    Process {
        id: printerSearch

        command: ["timeout", "20", "driverless"]

        stdout: StdioCollector {
            onStreamFinished: {
                const byName = {};
                for (const uri of text.split("\n").map(l => l.trim()).filter(Boolean)) {
                    const name = root.nameOf(uri);
                    // The encrypted address wins.
                    if (!byName[name] || uri.startsWith("ipps"))
                        byName[name] = uri;
                }
                root.found = Object.keys(byName).map(name => ({
                            name: name,
                            uri: byName[name]
                        })).filter(f => !root.printers.some(p => p.uri === f.uri || p.name === root.queueName(f.name)));
            }
        }
    }

    // Lines such as: device `airscan:e0:Canon MG5700 series' is a eSCL Canon MG5700 series ip=...
    Process {
        id: scannerSearch

        command: ["timeout", "25", "scanimage", "-L"]

        stdout: StdioCollector {
            onStreamFinished: root.scanners = text.split("\n").map(line => /^device `([^']+)' is a (.*)$/.exec(line)).filter(Boolean).map(m => ({
                        id: m[1],
                        name: m[2].replace(/\s+ip=\S+$/, "")
                    }))
        }
    }

    Process {
        id: changer

        stderr: StdioCollector {
            id: changerErrors
        }

        onExited: exitCode => {
            root.busy = "";
            if (exitCode !== 0)
                root.error = changerErrors.text.trim().replace(/^lpadmin: /, "") || I18n.t("printers.error");
            if (!listReader.running)
                listReader.running = true;
        }
    }

    IpcHandler {
        target: "printers"

        function describe(): string {
            return JSON.stringify({
                printers: root.printers,
                found: root.found,
                scanners: root.scanners,
                searching: root.searching,
                error: root.error
            });
        }
        function refresh(): void {
            root.refresh();
        }
    }
}
