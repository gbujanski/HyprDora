pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Counts available package and Flatpak updates and installs them in a terminal.
Singleton {
    id: root

    property int packages: 0
    property int flatpaks: 0
    readonly property int count: packages + flatpaks
    property bool installing: false
    // "reboot" or "poweroff" while updates download before an offline update; "" otherwise.
    property string preparing: ""

    /** Counts available updates again. */
    function check() {
        if (!packageCheck.running)
            packageCheck.running = true;
        if (!flatpakCheck.running)
            flatpakCheck.running = true;
    }

    /** Opens a terminal that installs the updates; dnf shows the list and asks before changing anything. */
    function install() {
        if (installing)
            return;
        installing = true;
        installer.command = [...Settings.terminalCommand, "sh", "-c", 'sudo dnf upgrade --refresh; flatpak update -y; echo; read -r -p "$1" _', "hyprdora-update", I18n.t("updates.done")];
        installer.running = true;
    }

    /**
     * Updates Flatpaks, downloads the system updates and restarts to install them before the system starts,
     * then restarts or powers off. Asks for the password through polkit.
     * @param {string} mode  "reboot" or "poweroff"
     */
    function installOffline(mode) {
        if (preparing !== "")
            return;
        preparing = mode;
        Quickshell.execDetached(["notify-send", "--transient", `--app-name=${I18n.t("updates.appName")}`, "--icon=system-software-update", I18n.t("updates.preparingTitle"), I18n.t(mode === "poweroff" ? "updates.preparingPoweroff" : "updates.preparingReboot")]);
        offline.command = ["sh", "-c", 'flatpak update -y --noninteractive >/dev/null 2>&1; exec pkexec /usr/libexec/hyprdora/offline-update "$1"', "hyprdora-offline-update", mode];
        offline.running = true;
    }

    // The check reads only the cache that dnf-makecache.timer keeps fresh, so it downloads nothing.
    Timer {
        interval: 60 * 60 * 1000
        repeat: true
        running: true
        onTriggered: root.check()
    }

    // The first check waits until the session has settled.
    Timer {
        interval: 60 * 1000
        running: true
        onTriggered: root.check()
    }

    Process {
        id: packageCheck
        command: ["env", "LC_ALL=C", "dnf", "check-upgrade", "-q", "--cacheonly"]
        stdout: StdioCollector {
            // One package per line: name.arch, version, repository.
            onStreamFinished: root.packages = text.split("\n").filter(line => /^\S+\.\S+\s+\S+\s+\S+\s*$/.test(line)).length
        }
    }

    Process {
        id: flatpakCheck
        command: ["flatpak", "remote-ls", "--updates", "--columns=application"]
        stdout: StdioCollector {
            onStreamFinished: root.flatpaks = text.split("\n").filter(line => line.trim() !== "").length
        }
    }

    // On success the system restarts, so only a failure comes back here.
    Process {
        id: offline

        stderr: StdioCollector {
            id: offlineErrors
        }

        onExited: exitCode => {
            root.preparing = "";
            // 126 is a dismissed password prompt, which needs no message.
            if (exitCode !== 0 && exitCode !== 126) {
                console.warn("updates: offline update failed:", offlineErrors.text.trim());
                Quickshell.execDetached(["notify-send", `--app-name=${I18n.t("updates.appName")}`, "--icon=dialog-error", I18n.t("updates.failedTitle"), offlineErrors.text.trim().split("\n").pop() ?? ""]);
            }
            root.check();
        }
    }

    Process {
        id: installer
        onExited: {
            root.installing = false;
            root.check();
        }
    }

    IpcHandler {
        target: "updates"

        function check(): void {
            root.check();
        }
        function describe(): string {
            return JSON.stringify({
                packages: root.packages,
                flatpaks: root.flatpaks,
                installing: root.installing,
                preparing: root.preparing
            });
        }
    }
}
