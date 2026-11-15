pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Available package and Flatpak updates, and installing them. Fedora publishes updates nearly every day, so,
// like GNOME Software, the bar shows ordinary updates once they have waited a week since the system was
// last up to date, and security updates at once.
Singleton {
    id: root

    // [{ name, version, repo }] from dnf, and [{ name, version }] for Flatpaks.
    property var packageList: []
    property var flatpakList: []
    // Names of packages whose update is a security advisory.
    property var securityNames: []
    readonly property int packages: packageList.length
    readonly property int flatpaks: flatpakList.length
    readonly property int count: packages + flatpaks
    readonly property int securityCount: packageList.filter(p => securityNames.includes(p.name)).length

    // When the system was last seen with nothing to update, in milliseconds.
    property real upToDateSince: 0
    property real now: Date.now()
    readonly property bool notify: securityCount > 0 || (count > 0 && now - upToDateSince >= 7 * 24 * 3600 * 1000)

    readonly property var fedoraRepos: ["fedora", "updates", "updates-testing"]
    // Fedora's own packages, then security updates, then other repositories and Flatpaks.
    readonly property var groups: [
        {
            key: "system",
            items: packageList.filter(p => fedoraRepos.includes(p.repo) && !securityNames.includes(p.name))
        },
        {
            key: "security",
            items: packageList.filter(p => securityNames.includes(p.name))
        },
        {
            key: "other",
            items: [...packageList.filter(p => !fedoraRepos.includes(p.repo) && !securityNames.includes(p.name)), ...flatpakList.map(f => Object.assign({}, f, {
                        repo: "Flatpak"
                    }))]
        }
    ].filter(g => g.items.length > 0)

    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/hyprdora/updates.json`

    /** Remembers that nothing waits now. */
    function markUpToDate() {
        upToDateSince = Date.now();
        stateFile.setText(JSON.stringify({
            upToDateSince: upToDateSince
        }));
    }
    property bool installing: false
    // "reboot" or "poweroff" while updates download before an offline update; "" otherwise.
    property string preparing: ""

    /** Reads the available updates again. */
    function check() {
        now = Date.now();
        if (!packageCheck.running)
            packageCheck.running = true;
        if (!advisoryCheck.running)
            advisoryCheck.running = true;
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

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                root.upToDateSince = JSON.parse(text()).upToDateSince ?? 0;
            } catch (e) {}
        }
        // A new system counts as up to date, so the first notice comes after a week.
        onLoadFailed: root.markUpToDate()
    }

    Process {
        id: packageCheck
        command: ["env", "LC_ALL=C", "dnf", "check-upgrade", "-q", "--cacheonly"]
        stdout: StdioCollector {
            // One package per line: name.arch, version, repository.
            onStreamFinished: {
                const list = [];
                for (const line of text.split("\n")) {
                    const m = /^(\S+)\.(\S+)\s+(\S+)\s+(\S+)\s*$/.exec(line);
                    if (m)
                        list.push({
                            name: m[1],
                            version: m[3],
                            repo: m[4]
                        });
                }
                root.packageList = list;
                if (list.length === 0 && root.flatpaks === 0)
                    root.markUpToDate();
            }
        }
    }

    Process {
        id: advisoryCheck
        command: ["env", "LC_ALL=C", "dnf5", "advisory", "list", "--security", "--json", "--cacheonly"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // A full name such as kernel-core-7.3.3-200.fc44.x86_64 ends in version, release and arch.
                    root.securityNames = [...new Set(JSON.parse(text).map(a => a.nevra.replace(/-[^-]+-[^-]+\.[^.]+$/, "")))];
                } catch (e) {
                    root.securityNames = [];
                }
            }
        }
    }

    Process {
        id: flatpakCheck
        command: ["flatpak", "remote-ls", "--updates", "--columns=name,version"]
        stdout: StdioCollector {
            onStreamFinished: root.flatpakList = text.split("\n").filter(line => line.trim() !== "").map(line => {
                const [name, version] = line.split("\t");
                return {
                    name: name,
                    version: version ?? ""
                };
            })
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
                security: root.securityCount,
                notify: root.notify,
                upToDateSince: new Date(root.upToDateSince).toISOString(),
                installing: root.installing,
                preparing: root.preparing
            });
        }
    }
}
