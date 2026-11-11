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
                installing: root.installing
            });
        }
    }
}
