pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.base
import qs.config

// Available package and Flatpak updates, and installing them. Fedora publishes updates nearly every day, so,
// like GNOME Software, the bar shows ordinary updates once they have waited a week since the system was
// last up to date, and security updates and HyprDora's own at once; a new HyprDora version is also announced
// once in a notification.
Singleton {
    id: root

    // [{ name, version, repo }] from dnf, and [{ name, version, size, commit }] for Flatpaks, size in bytes.
    property var packageList: []
    property var flatpakList: []
    // Bytes the package updates still need to download; packages already downloaded do not count.
    property real packageDownload: 0
    // Whether dnf has said how much that is.
    property bool packageDownloadKnown: false
    // Commits of Flatpak updates the background download has pulled; they need no download either.
    property var pulledCommits: []
    readonly property real downloadSize: packageDownload + flatpakList.filter(f => !pulledCommits.includes(f.commit)).reduce((sum, f) => sum + (f.size ?? 0), 0)
    // Everything is downloaded, by the background download, and only waits to be installed.
    readonly property bool downloaded: count > 0 && (packages === 0 || packageDownloadKnown) && downloadSize === 0
    // Names of packages whose update is a security advisory.
    property var securityNames: []
    readonly property int packages: packageList.length
    readonly property int flatpaks: flatpakList.length
    readonly property int count: packages + flatpaks
    readonly property int securityCount: packageList.filter(p => securityNames.includes(p.name)).length

    // HyprDora's own packages, listed first and shown at once. Its version is the hyprdora package's, or
    // another of its packages' where hyprdora itself has nothing new; hyprdora-release goes by Fedora's.
    readonly property string hyprdoraRepo: "copr:copr.fedorainfracloud.org:gbujanski:hyprdora"
    readonly property var hyprdoraList: packageList.filter(p => isHyprdora(p.name))
    readonly property var hyprdoraLead: hyprdoraList.find(p => p.name === "hyprdora") ?? hyprdoraList.find(p => p.name !== "hyprdora-release") ?? null
    readonly property string hyprdoraVersion: hyprdoraLead ? hyprdoraLead.version.split("-")[0] : ""
    // What is new, from the packages' changelog: [{ version, notes: [line] }], newest first.
    property var hyprdoraChanges: []
    // The last HyprDora version a notification announced, so each one is announced once.
    property string announcedVersion: ""

    // When the system was last seen with nothing to update, in milliseconds.
    property real upToDateSince: 0
    property real now: Date.now()
    // Paused, nothing reminds of updates, not even security ones: the user looks after them.
    // Ordinary updates wait Settings.updateReminderDays since the system was last up to date.
    readonly property bool notify: !paused && (securityCount > 0 || hyprdoraList.length > 0 || (count > 0 && now - upToDateSince >= Settings.updateReminderDays * 24 * 3600 * 1000))

    // Set in the Updates settings and kept by the system (update-settings), as they also rule its services.
    // A pause lasts until restart, for good ("always"), or until pauseEnd; while paused nothing is checked or
    // downloaded unless asked for. interval is how often to look: "often" (every 3 hours), "daily" or "weekly".
    property bool pausedUntilRestart: false
    property bool pausedForGood: false
    // In milliseconds since the epoch; 0 for none.
    property real pauseEnd: 0
    readonly property bool paused: pausedUntilRestart || pausedForGood || pauseEnd > now
    property string interval: "often"
    // Flatpaks are looked up at this interval, as their check downloads the remotes' index; packages come
    // from the system's cache, which its own timer refreshes at the same interval.
    readonly property real intervalMs: (interval === "weekly" ? 7 * 24 : interval === "daily" ? 24 : 3) * 3600 * 1000
    property real flatpaksCheckedAt: 0
    // When the system last looked for updates, by its timer or by hand, in milliseconds; 0 when not known.
    property real lastChecked: 0
    // Whether updates download in the background; off, they are still looked for.
    property bool backgroundDownload: true
    // A change of these settings or a check asked for by hand is under way.
    readonly property bool changingSettings: settingsChange.running
    readonly property bool checkingNow: manualCheck.running || manualPending
    property bool manualPending: false
    readonly property bool checksRunning: packageCheck.running || sizeCheck.running || flatpakCheck.running || advisoryCheck.running

    /** A check asked for by hand has finished; failed when the package cache could not be refreshed. */
    signal checkedNow(bool failed)

    readonly property var fedoraRepos: ["fedora", "updates", "updates-testing"]
    // HyprDora, then Fedora's own packages, security updates, other repositories and Flatpaks.
    readonly property var groups: [
        {
            key: "hyprdora",
            items: hyprdoraList
        },
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
            items: [...packageList.filter(p => !fedoraRepos.includes(p.repo) && !securityNames.includes(p.name) && !isHyprdora(p.name)), ...flatpakList.map(f => Object.assign({}, f, {
                        repo: "Flatpak"
                    }))]
        }
    ].filter(g => g.items.length > 0)

    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/hyprdora/updates.json`

    /**
     * Whether a package is one of HyprDora's own.
     * @param {string} name  package name
     * @returns {bool}
     */
    function isHyprdora(name) {
        return name === "hyprdora" || name.startsWith("hyprdora-");
    }

    /**
     * Announces a new HyprDora version once, with a button that opens the update list. Not while paused.
     */
    function announceHyprdora() {
        if (paused || hyprdoraVersion === "" || hyprdoraVersion === announcedVersion)
            return;
        announcedVersion = hyprdoraVersion;
        saveState();
        announcement.command = ["notify-send", "--app-name=HyprDora", ...Notifications.glyphArgs(Icons.update, ""), `--action=show=${I18n.t("updates.hyprdora.show")}`, I18n.t("updates.hyprdora.available", {
                version: hyprdoraVersion
            }), I18n.t("updates.hyprdora.body")];
        announcement.running = true;
    }

    /** Remembers that nothing waits now. */
    function markUpToDate() {
        upToDateSince = Date.now();
        saveState();
    }

    function saveState() {
        stateFile.setText(JSON.stringify({
            upToDateSince: upToDateSince,
            flatpaksCheckedAt: flatpaksCheckedAt,
            lastChecked: lastChecked,
            announcedVersion: announcedVersion
        }));
    }

    /**
     * Pauses every automatic check and download, asking for the administrator password.
     * @param {var} value  "restart", "always" or a number of seconds
     */
    function setPause(value) {
        changeSettings(["pause", String(value)]);
    }

    /** Ends a pause, asking for the administrator password. */
    function resume() {
        changeSettings(["resume"]);
    }

    /**
     * Sets how often to look for updates, asking for the administrator password.
     * @param {string} value  "often", "daily" or "weekly"
     */
    function setInterval(value) {
        changeSettings(["interval", value]);
    }

    /**
     * Turns the background download on or off, asking for the administrator password.
     * @param {bool} on  whether updates download in the background
     */
    function setBackgroundDownload(on) {
        changeSettings(["download", on ? "on" : "off"]);
    }

    /**
     * Keeps a newer time of the last look for updates.
     * @param {real} time  milliseconds since the epoch
     */
    function noteChecked(time) {
        if (time > lastChecked) {
            lastChecked = time;
            saveState();
        }
    }

    function changeSettings(args) {
        if (settingsChange.running)
            return;
        settingsChange.command = ["pkexec", "/usr/libexec/hyprdora/update-settings", ...args];
        settingsChange.running = true;
    }

    /** Looks for updates now, paused or not: refreshes the system's package cache, then checks. */
    function checkNow() {
        if (!checkingNow)
            manualCheck.running = true;
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
     * Reads the available updates again; while paused, only when asked by hand. The package lists come from
     * the system's cache. Flatpaks need the remotes' index, so they are looked up once per interval and not
     * on a metered network, unless asked by hand.
     * @param {bool} byHand  asked for by the user
     */
    function check(byHand) {
        now = Date.now();
        pulledFile.reload();
        if (!refreshTime.running)
            refreshTime.running = true;
        if (paused && !byHand)
            return;
        if (!packageCheck.running)
            packageCheck.running = true;
        if (!advisoryCheck.running)
            advisoryCheck.running = true;
        if (!flatpakCheck.running && (byHand || (!Network.metered && now - flatpaksCheckedAt >= intervalMs))) {
            flatpaksCheckedAt = now;
            saveState();
            flatpakCheck.running = true;
        }
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

    // The packages come from the cache dnf-makecache.timer keeps fresh, but Flatpaks need the remote's index,
    // so the check waits for a network that is not metered. The first waits until the session has settled.
    ScheduledTask {
        interval: 60 * 60 * 1000
        delay: 60 * 1000
        onRun: root.check()
    }

    // key=value lines written by update-settings: pause=always or pause=END (seconds), interval=daily or weekly,
    // download=off.
    FileView {
        id: settingsFile
        path: "/etc/hyprdora/updates.conf"
        printErrors: false
        onLoaded: {
            const value = key => (text().split("\n").find(line => line.startsWith(`${key}=`)) ?? "").slice(key.length + 1);
            const pause = value("pause");
            root.pausedForGood = pause === "always";
            root.pauseEnd = /^\d+$/.test(pause) ? Number(pause) * 1000 : 0;
            root.interval = value("interval") || "often";
            root.backgroundDownload = value("download") !== "off";
        }
        onLoadFailed: {
            root.pausedForGood = false;
            root.pauseEnd = 0;
            root.interval = "often";
            root.backgroundDownload = true;
        }
    }

    // A pause until restart is this file, which a restart clears.
    FileView {
        id: restartPauseFile
        path: "/run/hyprdora/updates-paused"
        printErrors: false
        onLoaded: root.pausedUntilRestart = true
        onLoadFailed: root.pausedUntilRestart = false
    }

    // Ends when the password is refused too; the files then still hold the settings as they were.
    Process {
        id: settingsChange
        stderr: StdioCollector {
            id: settingsErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0 && exitCode !== 126)
                console.warn(log, "update settings:", exitCode, settingsErrors.text.trim());
            root.now = Date.now();
            settingsFile.reload();
            restartPauseFile.reload();
        }
    }

    // When the system's timer last refreshed the package cache, as "Result=success" and
    // "ExecMainExitTimestamp=@1795565291"; known since the computer started, so it is kept in the state.
    Process {
        id: refreshTime
        command: ["systemctl", "show", "--timestamp=unix", "-p", "Result,ExecMainExitTimestamp", "dnf-makecache.service"]
        stdout: StdioCollector {
            onStreamFinished: {
                const success = /^Result=success$/m.test(text);
                const time = /^ExecMainExitTimestamp=@(\d+)$/m.exec(text);
                if (success && time)
                    root.noteChecked(Number(time[1]) * 1000);
            }
        }
    }

    Process {
        id: manualCheck
        command: ["pkexec", "/usr/libexec/hyprdora/update-check"]
        stderr: StdioCollector {
            id: manualCheckErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn(log, "update check:", exitCode, manualCheckErrors.text.trim());
                root.checkedNow(true);
                return;
            }
            root.manualPending = true;
            root.noteChecked(Date.now());
            root.check(true);
        }
    }

    onChecksRunningChanged: {
        if (!checksRunning && manualPending) {
            manualPending = false;
            checkedNow(false);
        }
    }

    // Written by the background download (update-download), one commit per line.
    FileView {
        id: pulledFile
        path: "/var/lib/hyprdora/flatpak-pulled"
        printErrors: false
        onLoaded: root.pulledCommits = text().split("\n").filter(c => c !== "")
        onLoadFailed: root.pulledCommits = []
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false
        onLoaded: {
            try {
                const state = JSON.parse(text());
                root.upToDateSince = state.upToDateSince ?? 0;
                root.flatpaksCheckedAt = state.flatpaksCheckedAt ?? 0;
                root.lastChecked = state.lastChecked ?? 0;
                root.announcedVersion = state.announcedVersion ?? "";
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
                if (root.hyprdoraLead && !changelogCheck.running) {
                    changelogCheck.command = ["env", "LC_ALL=C", "dnf5", "changelog", "--upgrades", `--repo=${root.hyprdoraRepo}`, root.hyprdoraLead.name];
                    changelogCheck.running = true;
                } else if (!root.hyprdoraLead) {
                    root.hyprdoraChanges = [];
                }
                root.announceHyprdora();
                if (list.length === 0) {
                    root.packageDownload = 0;
                    root.packageDownloadKnown = false;
                    if (root.flatpaks === 0)
                        root.markUpToDate();
                } else if (!sizeCheck.running) {
                    sizeCheck.running = true;
                }
            }
        }
    }

    // The changelog entries newer than the installed version, from HyprDora's repository alone, whose small
    // changelog file dnf downloads the first time:
    //   * Tue Nov 24 2026 Name <address> - 0.2.0-1
    //   - Updates download in the background after each refresh of the package cache, on AC power and off
    //     metered networks, so updating at power off or restart only installs them
    Process {
        id: changelogCheck
        stdout: StdioCollector {
            onStreamFinished: {
                const changes = [];
                for (const line of text.split("\n")) {
                    const header = /^\* .* - ([^-\s]+)-[^-\s]+$/.exec(line);
                    const current = changes[changes.length - 1];
                    if (header)
                        changes.push({
                            version: header[1],
                            notes: []
                        });
                    else if (current && line.startsWith("- "))
                        current.notes.push(line.slice(2));
                    else if (current && current.notes.length > 0 && /^\s+\S/.test(line))
                        current.notes[current.notes.length - 1] += ` ${line.trim()}`;
                }
                root.hyprdoraChanges = changes;
            }
        }
    }

    Process {
        id: announcement
        stdout: SplitParser {
            onRead: line => {
                if (line === "show")
                    Panels.open("updates", null);
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
    // "Total size of inbound packages is 15 MiB. Need to download 15 MiB." It looks in the system's cache,
    // where the background download puts packages; a user's dnf would look in its own.
    Process {
        id: sizeCheck
        command: ["env", "LC_ALL=C", "dnf5", "upgrade", "--assumeno", "--cacheonly", "--setopt=cachedir=/var/cache/libdnf5"]
        stderr: StdioCollector {
            onStreamFinished: {
                const size = /Need to download ([\d.]+\s*\S*B)/.exec(text)?.[1];
                root.packageDownload = root.bytesOf(size);
                root.packageDownloadKnown = size !== undefined;
            }
        }
    }

    // Each remote on its own: a user may not read Fedora's OCI remote, and one failing remote would hide the
    // updates from the others.
    Process {
        id: flatpakCheck
        command: ["env", "LC_ALL=C", "sh", "-c", 'for remote in $(flatpak remotes --system --columns=name); do flatpak remote-ls --system --updates --columns=name,version,download-size,commit "$remote" 2>/dev/null; done']
        stdout: StdioCollector {
            onStreamFinished: root.flatpakList = text.split("\n").filter(line => line.trim() !== "").map(line => {
                const [name, version, size, commit] = line.split("\t");
                return {
                    name: name,
                    version: version ?? "",
                    size: root.bytesOf(size),
                    commit: commit ?? ""
                };
            })
        }
    }

    // On success the system restarts, so this ends only when the password is refused or the user gives up
    // after a failure; the update screen has shown why.
    Process {
        id: offline

        stdinEnabled: true

        // The service has written the progress file, which is followed from then on.
        stdout: SplitParser {
            onRead: line => {
                if (line === "started")
                    progressFile.reload();
            }
        }
        stderr: StdioCollector {
            id: offlineErrors
        }

        onExited: exitCode => {
            root.preparing = "";
            if (exitCode !== 0 && exitCode !== 126)
                console.warn(log, "offline update ended:", exitCode, offlineErrors.text.trim());
            progressFile.reload();
            root.check();
        }
    }

    // The service writes the progress as root to a file the shell may read; it is read once the service says
    // it is there, and at start, so a restarted shell shows the screen of a download still running, and it is
    // followed while it holds a progress.
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

    EventSubscription {
        file: root.progressPath
        enabled: root.updating
        onChanged: progressFile.reload()
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

    LoggingCategory {
        id: log
        name: "hyprdora.updates"
    }
}
