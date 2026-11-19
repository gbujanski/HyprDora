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

    // [{ name, version, repo }] from dnf, and [{ name, version, size }] for Flatpaks, size in bytes.
    property var packageList: []
    property var flatpakList: []
    // Bytes the package updates still need to download; packages already downloaded do not count.
    property real packageDownload: 0
    readonly property real downloadSize: packageDownload + flatpakList.reduce((sum, f) => sum + (f.size ?? 0), 0)
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
    // "reboot" or "poweroff" from the click until the download stops; "" otherwise.
    property string preparing: ""
    // Progress of the download before an offline update, written by the offline-update service:
    // { mode, state: "preparing" | "downloading" | "restarting" | "failed", done, total, bytes, totalBytes,
    // message }, or null when none runs. While it is set, the update screen locks the session.
    property var progress: null
    readonly property bool updating: progress !== null
    readonly property string progressPath: "/run/hyprdora/offline-update.json"

    /**
     * Reads a size such as 15 MiB, 685.2 MB or 12 kB as bytes.
     * @param {string} text  number and unit
     * @returns {real} bytes, 0 when unreadable
     */
    function bytesOf(text) {
        const m = /([\d.]+)\s*([kKMGT]?)(i?)B/.exec(text ?? "");
        if (!m)
            return 0;
        const power = " KMGT".indexOf(m[2].toUpperCase());
        return parseFloat(m[1]) * Math.pow(m[3] ? 1024 : 1000, Math.max(0, power));
    }

    /**
     * Formats bytes for the update list, such as 450 MB or 1,2 GB.
     * @param {real} bytes  size
     * @returns {string}
     */
    function formatSize(bytes) {
        if (bytes >= 1e9)
            return `${(bytes / 1e9).toLocaleString(I18n.locale, "f", 1)} GB`;
        if (bytes >= 1e6)
            return `${Math.round(bytes / 1e6)} MB`;
        return `${Math.max(1, Math.round(bytes / 1e3))} kB`;
    }

    /**
     * Reads the available updates again. On a metered connection nothing is downloaded: the package lists
     * come from the cache, and Flatpaks, which need the remote's index, wait for another network.
     */
    function check() {
        now = Date.now();
        if (!packageCheck.running)
            packageCheck.running = true;
        if (!advisoryCheck.running)
            advisoryCheck.running = true;
        if (!flatpakCheck.running && !Network.metered)
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
     * then restarts or powers off. Asks for the password through polkit first; the download then runs as a
     * system service, shown by the update screen, and takes "retry" or "quit" on stdin after a failure.
     * @param {string} mode  "reboot" or "poweroff"
     */
    function installOffline(mode) {
        if (preparing !== "" || updating)
            return;
        preparing = mode;
        offline.command = ["pkexec", "/usr/libexec/hyprdora/offline-update", "start", mode];
        offline.running = true;
    }

    /** After a failed download, tries again. */
    function retryOffline() {
        if (offline.running)
            offline.write("retry\n");
    }

    /** After a failed download, gives up and returns to the desktop; nothing has changed. */
    function cancelOffline() {
        if (offline.running)
            offline.write("quit\n");
        else
            progress = null;
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
                if (list.length === 0) {
                    root.packageDownload = 0;
                    if (root.flatpaks === 0)
                        root.markUpToDate();
                } else if (!sizeCheck.running) {
                    sizeCheck.running = true;
                }
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

    // dnf answers no after showing the transaction, which ends with a line on stderr such as
    // "Total size of inbound packages is 15 MiB. Need to download 15 MiB."
    Process {
        id: sizeCheck
        command: ["env", "LC_ALL=C", "dnf5", "upgrade", "--assumeno", "--cacheonly"]
        stderr: StdioCollector {
            onStreamFinished: root.packageDownload = root.bytesOf(/Need to download ([\d.]+\s*\S*B)/.exec(text)?.[1])
        }
    }

    Process {
        id: flatpakCheck
        command: ["env", "LC_ALL=C", "flatpak", "remote-ls", "--system", "--updates", "--columns=name,version,download-size"]
        stdout: StdioCollector {
            onStreamFinished: root.flatpakList = text.split("\n").filter(line => line.trim() !== "").map(line => {
                const [name, version, size] = line.split("\t");
                return {
                    name: name,
                    version: version ?? "",
                    size: root.bytesOf(size)
                };
            })
        }
    }

    // On success the system restarts, so this ends only when the password is refused or the user gives up
    // after a failure; the update screen has shown why.
    Process {
        id: offline

        stdinEnabled: true

        stderr: StdioCollector {
            id: offlineErrors
        }

        onExited: exitCode => {
            root.preparing = "";
            if (exitCode !== 0 && exitCode !== 126)
                console.warn("updates: offline update ended:", exitCode, offlineErrors.text.trim());
            progressFile.reload();
            root.check();
        }
    }

    // The service writes the progress as root to a file the shell may read; it is read often while an update
    // may run, and once at start, so a restarted shell shows the screen of a download still running.
    FileView {
        id: progressFile
        path: root.progressPath
        printErrors: false
        onLoaded: {
            try {
                root.progress = JSON.parse(text());
            } catch (e) {
                // A file being replaced keeps the last progress.
            }
        }
        onLoadFailed: root.progress = null
    }

    Timer {
        interval: 400
        repeat: true
        running: root.preparing !== "" || root.updating
        onTriggered: progressFile.reload()
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
                downloadSize: root.downloadSize,
                installing: root.installing,
                preparing: root.preparing,
                progress: root.progress
            });
        }
    }
}
