pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Applications outside the base system, offered on the welcome screen at a user's first HyprDora session and
// later from the settings: VS Code, Docker, codecs and the like, listed in configs/extras/catalog.json. The
// helper installs the chosen ones as root through pkexec, from their makers' repositories with signatures
// checked. Some need a step in the user's own home afterwards, done here: VS Code's keyring setting, Oh My Zsh.
// A second step picks the default applications, such as the browser, among those installed or chosen; a kind
// left without a choice keeps what it has, or nothing.
Singleton {
    id: root

    // The installed shell's catalog, or the repository's for a development copy.
    readonly property string folder: Quickshell.shellDir.startsWith("/etc/") ? "/usr/share/hyprdora/configs/extras" : `${Quickshell.shellDir}/../configs/extras`
    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/hyprdora`
    readonly property string home: Quickshell.env("HOME")

    // [{ id, items: [item] }], as in the catalog.
    property var groups: []
    readonly property var items: groups.reduce((all, g) => all.concat(g.items), [])
    // Installed items, by id; known once checked.
    property var installed: ({})
    property bool checked: false
    // Items ticked for installing, by id.
    property var selected: ({})
    // What installing each item came to, by id: "waiting", "installing", "done" or "failed".
    property var progress: ({})
    // Why an item failed, by id.
    property var errors: ({})
    property bool busy: false
    property bool windowOpen: false
    // Whether it opened by itself at the user's first HyprDora session.
    property bool welcome: false
    // Whether the user has not seen the welcome screen; the catalog and this arrive in either order.
    property bool firstSession: false
    // "apps" to choose applications, "defaults" to choose the default ones, "progress" while and after
    // installing.
    property string step: "apps"
    // The default application chosen for each kind, by kind: a desktop file name.
    property var defaults: ({})
    // Choices to make once the applications they need are installed: [[kind, desktopId, itemId], …].
    property var pendingDefaults: []

    readonly property var selectedIds: items.filter(i => selected[i.id] && !installed[i.id]).map(i => i.id)

    /** Opens the window and checks what is installed. */
    function open() {
        step = "apps";
        windowOpen = true;
        check();
        DefaultApps.refresh();
    }

    /**
     * The applications offered as the default for a kind: those installed that open its files, and those
     * ticked for installing that can.
     * @param {string} kind  kind id, as in DefaultApps
     * @returns {list} [{ desktop, name, itemId }]
     */
    function candidates(kind) {
        const result = (DefaultApps.apps[kind]?.choices ?? []).map(d => ({
                    desktop: d,
                    name: DefaultApps.name(d),
                    itemId: ""
                }));
        for (const item of items) {
            const desktop = item.defaults?.[kind];
            if (desktop && selectedIds.includes(item.id) && !result.some(r => r.desktop === desktop))
                result.push({
                    desktop: desktop,
                    name: I18n.t(`extras.${item.id}`),
                    itemId: item.id
                });
        }
        return result;
    }

    /** Goes to the choice of default applications, starting from the current ones. */
    function toDefaults() {
        const current = {};
        for (const kind of DefaultApps.kinds)
            if (DefaultApps.apps[kind.id]?.current)
                current[kind.id] = DefaultApps.apps[kind.id].current;
        defaults = current;
        step = "defaults";
    }

    /**
     * Chooses the default application of a kind, or takes the choice back.
     * @param {string} kind  kind id
     * @param {string} desktop  desktop file name
     */
    function chooseDefault(kind, desktop) {
        const next = Object.assign({}, defaults);
        if (next[kind] === desktop)
            delete next[kind];
        else
            next[kind] = desktop;
        defaults = next;
    }

    /** Installs the ticked applications, then sets the chosen defaults; with nothing to install, sets them now. */
    function finish() {
        const pending = [];
        for (const kind of Object.keys(defaults)) {
            if (defaults[kind] === (DefaultApps.apps[kind]?.current ?? ""))
                continue;
            const item = items.find(i => i.defaults?.[kind] === defaults[kind] && selectedIds.includes(i.id));
            pending.push([kind, defaults[kind], item?.id ?? ""]);
        }
        pendingDefaults = pending;
        if (selectedIds.length === 0) {
            applyDefaults();
            close();
            return;
        }
        step = "progress";
        install(selectedIds);
    }

    /** Sets the chosen defaults whose applications are there. */
    function applyDefaults() {
        for (const [kind, desktop, itemId] of pendingDefaults)
            if (itemId === "" || progress[itemId] === "done")
                DefaultApps.set(kind, desktop);
        pendingDefaults = [];
    }

    /** Opens the welcome screen at the first session, once both the catalog and the marker are read. */
    function welcomeIfFirst() {
        if (!firstSession || groups.length === 0 || windowOpen)
            return;
        welcome = true;
        open();
    }

    /** Closes the window, unless installing, and leaves the welcome screen done for this user. */
    function close() {
        if (busy)
            return;
        windowOpen = false;
        firstSession = false;
        welcomeMarker.setText(`${new Date().toISOString()}\n`);
    }

    /** Reads which items are installed. */
    function check() {
        if (items.length === 0 || rpmCheck.running || flatpakCheck.running)
            return;
        const packages = items.filter(i => i.packages).map(i => i.checkPackage ?? i.packages[0]);
        rpmCheck.command = ["sh", "-c", "for p; do rpm -q --quiet \"$p\" && echo \"$p\"; done; true", "sh", ...packages];
        rpmCheck.running = true;
    }

    /**
     * Ticks or unticks an item.
     * @param {string} id  item id
     * @param {bool} on  whether it is ticked
     */
    function setSelected(id, on) {
        selected = Object.assign({}, selected, {
            [id]: on
        });
    }

    /**
     * Ticks every item not installed, or none.
     * @param {bool} on  whether to tick them
     */
    function selectAll(on) {
        const next = {};
        for (const item of items)
            next[item.id] = on && !installed[item.id];
        selected = next;
    }

    /**
     * Installs items through the helper.
     * @param {list} ids  item ids
     */
    function install(ids) {
        if (busy || ids.length === 0)
            return;
        const next = Object.assign({}, progress);
        for (const id of ids)
            next[id] = "waiting";
        progress = next;
        busy = true;
        helper.command = ["pkexec", "/usr/libexec/hyprdora/install-extras", ...ids];
        helper.running = true;
    }

    /**
     * Sets an entry of a map property.
     * @param {string} name  "progress" or "errors"
     * @param {string} id  item id
     * @param {var} value  the value
     */
    function setEntry(name, id, value) {
        root[name] = Object.assign({}, root[name], {
            [id]: value
        });
    }

    /**
     * The step in the user's home an item needs once installed.
     * @param {string} id  item id
     */
    function setUpForUser(id) {
        if (id === "vscode")
            readFile(vscodeArgs, `${home}/.vscode/argv.json`);
        else if (id === "zsh")
            ohMyZsh.running = true;
    }

    /**
     * Reads a file only when asked: a FileView reads its file as soon as it has a path.
     * @param {FileView} view  the file's view
     * @param {string} path  the file
     */
    function readFile(view, path) {
        if (view.path === path)
            view.reload();
        else
            view.path = path;
    }

    // The catalog: read at start, so the welcome screen knows whether to open.
    FileView {
        path: `${root.folder}/catalog.json`
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                root.groups = JSON.parse(text()).groups;
                // Codecs are wanted almost always, so they start ticked.
                root.selected = {
                    codecs: true
                };
                root.welcomeIfFirst();
            } catch (e) {
                console.warn(log, "unreadable catalog.json");
            }
        }
        onLoadFailed: console.warn(log, "no catalog.json at", path)
    }

    // Present once the user has seen the welcome screen; missing at the first HyprDora session.
    FileView {
        id: welcomeMarker
        path: `${root.stateDir}/welcome-done`
        blockLoading: true
        printErrors: false
        onLoadFailed: {
            root.firstSession = true;
            root.welcomeIfFirst();
        }
    }

    Process {
        id: rpmCheck
        stdout: StdioCollector {
            onStreamFinished: {
                const present = text.split("\n").filter(Boolean);
                const next = {};
                for (const item of root.items)
                    if (item.packages)
                        next[item.id] = present.includes(item.checkPackage ?? item.packages[0]);
                root.installed = Object.assign({}, root.installed, next);
                flatpakCheck.running = true;
            }
        }
    }

    Process {
        id: flatpakCheck
        command: ["flatpak", "list", "--app", "--columns=application"]
        stdout: StdioCollector {
            onStreamFinished: {
                const present = text.split("\n").map(l => l.trim());
                const next = {};
                for (const item of root.items)
                    if (item.flatpaks)
                        next[item.id] = item.flatpaks.every(f => present.includes(f));
                root.installed = Object.assign({}, root.installed, next);
                root.checked = true;
            }
        }
    }

    // Lines "start ID", "done ID" or "failed ID MESSAGE", as the helper works through the items.
    Process {
        id: helper
        stdout: SplitParser {
            onRead: line => {
                const m = /^(start|done|failed) (\S+) ?(.*)$/.exec(line);
                if (!m)
                    return;
                const state = m[1] === "start" ? "installing" : m[1];
                root.setEntry("progress", m[2], state);
                if (m[1] === "failed")
                    root.setEntry("errors", m[2], m[3]);
                if (m[1] === "done")
                    root.setUpForUser(m[2]);
            }
        }
        stderr: StdioCollector {
            id: helperErrors
        }
        onExited: code => {
            // Cancelled at the password prompt, or the helper could not start: nothing ran.
            const next = Object.assign({}, root.progress);
            for (const id of Object.keys(next))
                if (next[id] === "waiting" || next[id] === "installing") {
                    next[id] = "failed";
                    root.setEntry("errors", id, code === 126 ? I18n.t("extras.cancelled") : helperErrors.text.trim().split("\n").pop() ?? "");
                }
            root.progress = next;
            root.busy = false;
            root.applyDefaults();
            root.check();
        }
    }

    // VS Code keeps its secrets in GNOME Keyring, which it does not find by itself outside GNOME. A file the
    // user already has stays.
    FileView {
        id: vscodeArgs
        printErrors: false
        onLoadFailed: setText("{\n  \"password-store\": \"gnome-libsecret\"\n}\n")
    }

    // Oh My Zsh for the user, with its template as .zshrc when there is none.
    Process {
        id: ohMyZsh
        command: ["sh", "-c", "[ -d \"$HOME/.oh-my-zsh\" ] || git clone --quiet --depth 1 https://github.com/ohmyzsh/ohmyzsh.git \"$HOME/.oh-my-zsh\""]
        onExited: code => {
            if (code === 0)
                root.readFile(zshrc, `${root.home}/.zshrc`);
            else
                console.warn(log, "could not fetch Oh My Zsh");
        }
    }

    FileView {
        id: zshrc
        printErrors: false
        onLoadFailed: root.readFile(zshTemplate, `${root.home}/.oh-my-zsh/templates/zshrc.zsh-template`)
    }

    FileView {
        id: zshTemplate
        printErrors: false
        onLoaded: zshrc.setText(text().replace(/^ZSH_THEME=.*$/m, "ZSH_THEME=\"agnoster\""))
    }

    IpcHandler {
        target: "extras"

        function open(): void {
            root.open();
        }
        // Goes to the choice of default applications, as Next does.
        function next(): void {
            root.toDefaults();
        }
        function describe(): string {
            return JSON.stringify({
                installed: root.installed,
                selected: root.selectedIds,
                progress: root.progress,
                errors: root.errors,
                open: root.windowOpen
            });
        }
    }

    LoggingCategory {
        id: log
        name: "hyprdora.extras"
    }
}
