pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// System restore from snapper snapshots. Everything goes through a helper run with pkexec, so polkit asks for
// the administrator password before the list opens; it keeps the authorization for a few minutes, so a restore
// right after does not ask again. Snapshots cover the system, not /home.
Singleton {
    id: root

    readonly property string helper: "/usr/libexec/hyprdora/system-restore"

    // Snapshots taken before a change, and single ones, newest first: [{ number, type, date, description, kind }].
    property var snapshots: []
    property bool windowOpen: false
    // "list", "create" or "restore" while the helper runs; "" otherwise.
    property string busy: ""

    /** Asks for the password, then opens the window with the snapshots. */
    function open() {
        if (busy !== "")
            return;
        busy = "list";
        run(["list"]);
    }

    /** Takes a snapshot of the system now. */
    function create() {
        if (busy !== "")
            return;
        busy = "create";
        run(["create", I18n.t("restore.manualName")]);
    }

    /**
     * Restores a snapshot; the helper restarts the computer.
     * @param {int} number  snapshot number
     */
    function restore(number) {
        if (busy !== "")
            return;
        busy = "restore";
        run(["restore", String(number)]);
    }

    /**
     * Runs the helper; pkexec is started directly, so polkit remembers the authorization for this shell.
     * @param {list} args  helper arguments
     */
    function run(args) {
        helperProcess.command = ["pkexec", helper, ...args];
        helperProcess.running = true;
    }

    /**
     * Describes a snapshot in words, such as "before: system update".
     * @param {string} type  pre, post or single
     * @param {string} description  what snapper recorded, often a dnf command line
     * @returns {string}
     */
    function kind(type, description) {
        if (type !== "pre")
            // The installer takes the first snapshot, of the freshly installed system.
            return description === "timeline" ? I18n.t("restore.kind.timeline") : description === "first root filesystem" ? I18n.t("restore.kind.installed") : I18n.t("restore.kind.manual");
        const words = description.trim().split(/\s+/);
        const program = (words.shift() ?? "").split("/").pop();
        if (!/^dnf/.test(program))
            return I18n.t("restore.kind.before", {
                what: description
            });
        const args = words.filter(w => !w.startsWith("-"));
        const command = args.shift() ?? "";
        const packages = args.map(a => a.split("/").pop().replace(/\.rpm$/, "")).join(", ");
        let what;
        if (command === "offline")
            what = I18n.t("restore.op.offline");
        else if (["upgrade", "update", "distro-sync"].includes(command))
            what = packages === "" ? I18n.t("restore.op.update") : I18n.t("restore.op.updatePackages", {
                packages: packages
            });
        else if (command === "install")
            what = I18n.t("restore.op.install", {
                packages: packages
            });
        else if (command === "reinstall")
            what = I18n.t("restore.op.reinstall", {
                packages: packages
            });
        else if (["remove", "erase"].includes(command))
            what = I18n.t("restore.op.remove", {
                packages: packages
            });
        else if (command === "downgrade")
            what = I18n.t("restore.op.downgrade", {
                packages: packages
            });
        else
            what = [command, packages].filter(Boolean).join(" ");
        return I18n.t("restore.kind.before", {
            what: what
        });
    }

    Process {
        id: helperProcess

        stdout: StdioCollector {
            id: helperOutput
        }
        stderr: StdioCollector {
            id: helperErrors
        }

        onExited: exitCode => {
            const action = root.busy;
            root.busy = "";
            // 126 and 127 are a dismissed or failed password prompt, which needs no message.
            if (exitCode === 126 || exitCode === 127)
                return;
            if (exitCode !== 0) {
                console.warn(log, helperErrors.text.trim());
                Quickshell.execDetached(["notify-send", `--app-name=${I18n.t("restore.title")}`, ...Notifications.glyphArgs(Icons.alert, "error"), I18n.t(`restore.failed.${action}`), helperErrors.text.trim().split("\n").pop() ?? ""]);
                return;
            }
            if (action === "list") {
                // Snapper keeps dates in UTC.
                root.snapshots = helperOutput.text.split("\n").filter(Boolean).map(line => {
                    const [number, type, date, encoded] = line.split("\t");
                    // Snapper writes characters such as "ę" as numeric XML entities.
                    const description = (encoded ?? "").replace(/&#x([0-9a-f]+);/gi, (m, hex) => String.fromCodePoint(parseInt(hex, 16))).replace(/&#(\d+);/g, (m, dec) => String.fromCodePoint(Number(dec)));
                    return {
                        number: Number(number),
                        type: type,
                        date: new Date(date.replace(" ", "T") + "Z"),
                        description: description || (type === "single" ? I18n.t("restore.manualName") : ""),
                        kind: root.kind(type, description ?? "")
                    };
                }).filter(s => s.number > 0 && s.type !== "post").reverse();
                Panels.close("actioncenter");
                root.windowOpen = true;
            } else if (action === "create") {
                Quickshell.execDetached(["notify-send", "--transient", `--app-name=${I18n.t("restore.title")}`, ...Notifications.glyphArgs(Icons.restore, ""), I18n.t("restore.created")]);
            }
        }
    }

    IpcHandler {
        target: "systemrestore"

        function open(): void {
            root.open();
        }
        function close(): void {
            root.windowOpen = false;
        }
    }

    LoggingCategory {
        id: log
        name: "hyprdora.restore"
    }
}
