pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// Monitors: state, draft changes, safe application and saving.
Singleton {
    id: root

    readonly property int confirmSeconds: 15
    readonly property string configPath: `${Settings.configDir}/hypr/monitors.lua`
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")

    property var monitors: []
    property var draft: []
    property string selectedName: ""
    property string errorMessage: ""

    // A change waits for confirmation; without one, the previous state returns.
    property bool pending: false
    property int secondsLeft: 0
    property var previousRules: []
    property string watchdogToken: ""
    property int changeCounter: 0
    property bool saveAfterFetch: false

    readonly property var selected: draft.find(m => m.name === selectedName) ?? draft[0] ?? null
    readonly property var activeDraft: draft.filter(m => m.enabled && !m.mirrorOf)
    readonly property bool hasExternal: monitors.some(m => !isInternal(m))
    readonly property bool dirty: JSON.stringify(draft.map(rule)) !== JSON.stringify(monitors.map(rule))

    /**
     * Tells whether a monitor is a built-in panel.
     * @param {object} monitor  monitor entry
     * @returns {bool}
     */
    function isInternal(monitor) {
        return /^(eDP|LVDS|DSI)/.test(monitor.name);
    }

    /**
     * Returns a monitor's width after scaling.
     * @param {object} monitor  monitor entry
     * @returns {int}
     */
    function logicalWidth(monitor) {
        return Math.ceil(monitor.width / monitor.scale);
    }

    /**
     * Returns a monitor's height after scaling.
     * @param {object} monitor  monitor entry
     * @returns {int}
     */
    function logicalHeight(monitor) {
        return Math.ceil(monitor.height / monitor.scale);
    }

    /**
     * Returns a readable monitor name.
     * @param {object} monitor  monitor entry
     * @returns {string}
     */
    function displayName(monitor) {
        if (isInternal(monitor)) return I18n.t("displays.laptopScreen");
        return monitor.description || monitor.name;
    }

    /**
     * Parses Hyprland mode strings such as 1920x1080@60.00Hz.
     * @param {list} modes  mode strings
     * @returns {list}
     */
    function parseModes(modes) {
        const result = [];
        for (const text of modes) {
            const match = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(text);
            if (match) result.push({ width: Number(match[1]), height: Number(match[2]), refresh: Number(match[3]) });
        }
        return result;
    }

    /**
     * Parses `hyprctl -j monitors all` output.
     * @param {string} text  JSON output
     * @returns {list}
     */
    function parseMonitors(text) {
        const raw = JSON.parse(text);
        const names = {};
        for (const m of raw) names[String(m.id)] = m.name;
        return raw.map(m => ({
            name: m.name,
            description: m.description ?? "",
            width: m.width,
            height: m.height,
            refresh: m.refreshRate,
            x: m.x,
            y: m.y,
            scale: m.scale,
            transform: m.transform ?? 0,
            vrr: m.vrr ?? false,
            enabled: !m.disabled,
            mirrorOf: m.mirrorOf && m.mirrorOf !== "none" ? (names[m.mirrorOf] ?? "") : "",
            modes: parseModes(m.availableModes ?? [])
        }));
    }

    /**
     * Returns the mode part of a monitor rule.
     * @param {object} monitor  monitor entry
     * @returns {string}
     */
    function modeText(monitor) {
        if (monitor.width > 0 && monitor.height > 0)
            return `${monitor.width}x${monitor.height}@${Number(monitor.refresh).toFixed(2)}`;
        return "preferred";
    }

    /**
     * Builds a Lua monitor rule for a given identifier. hl.monitor merges with the existing
     * rule, so an enabled monitor states every field that could otherwise stay from before.
     * @param {string} id  connector name or desc: selector
     * @param {object} monitor  monitor entry
     * @param {string} position  position override, optional
     * @returns {string}
     */
    function ruleFor(id, monitor, position) {
        const output = JSON.stringify(id);
        if (!monitor.enabled) return `hl.monitor({ output = ${output}, disabled = true })`;
        const where = position ?? (monitor.mirrorOf ? "auto" : `${monitor.x}x${monitor.y}`);
        return `hl.monitor({ output = ${output}, disabled = false, mode = "${modeText(monitor)}", position = "${where}", `
            + `scale = ${monitor.scale}, mirror = ${JSON.stringify(monitor.mirrorOf)}, `
            + `transform = ${monitor.transform}, vrr = ${monitor.vrr ? 1 : 0} })`;
    }

    /**
     * Builds a monitor rule addressed by connector name.
     * @param {object} monitor  monitor entry
     * @returns {string}
     */
    function rule(monitor) {
        return ruleFor(monitor.name, monitor);
    }

    /**
     * Builds the rule stored on disk. The description is more stable than the connector name, and the laptop screen always stays on so booting without an external monitor cannot give a black screen.
     * @param {object} monitor  monitor entry
     * @returns {string}
     */
    function savedRule(monitor) {
        const id = monitor.description ? `desc:${monitor.description}` : monitor.name;
        if (isInternal(monitor) && !monitor.enabled)
            return ruleFor(id, Object.assign({}, monitor, { enabled: true, mirrorOf: "" }), "auto");
        return ruleFor(id, monitor);
    }

    /**
     * Builds the argv that applies rules.
     * @param {list} rules  Lua monitor rules
     * @returns {list}
     */
    function applyCommand(rules) {
        return ["hyprctl", "eval", rules.join(" ")];
    }

    /**
     * Returns rules with enabled monitors first, so there is always an active screen.
     * @param {list} targets  monitor entries
     * @returns {list}
     */
    function orderedRules(targets) {
        const on = targets.filter(m => m.enabled);
        const off = targets.filter(m => !m.enabled);
        return [...on, ...off].map(rule);
    }

    /**
     * Checks a target layout.
     * @param {list} targets  monitor entries
     * @returns {string} empty when valid
     */
    function validationError(targets) {
        if (!targets.some(m => m.enabled && !m.mirrorOf)) return I18n.t("displays.error.needOne");
        for (const m of targets) {
            if (m.mirrorOf && !targets.some(o => o.name === m.mirrorOf && o.enabled && !o.mirrorOf))
                return I18n.t("displays.error.mirrorSource");
        }
        return "";
    }

    /** Reads the current monitor state unless a read is running. */
    function refresh() {
        if (!fetcher.running) fetcher.running = true;
    }

    /**
     * Selects the monitor edited on the page.
     * @param {string} name  connector name
     */
    function select(name) {
        selectedName = name;
    }

    /** Discards the draft and returns to the current state. */
    function resetDraft() {
        draft = monitors.map(m => Object.assign({}, m));
        errorMessage = "";
    }

    /**
     * Merges changes into one draft monitor.
     * @param {string} name  connector name
     * @param {object} patch  fields to change
     */
    function editDraft(name, patch) {
        draft = draft.map(m => m.name === name ? Object.assign({}, m, patch) : m);
    }

    /**
     * Sets a draft monitor's mode.
     * @param {string} name  connector name
     * @param {int} width  width in pixels
     * @param {int} height  height in pixels
     * @param {real} refreshRate  refresh rate in Hz
     */
    function setMode(name, width, height, refreshRate) {
        editDraft(name, { width: width, height: height, refresh: refreshRate });
        draft = layoutWithoutOverlap(draft);
    }

    /**
     * Sets a draft monitor's scale.
     * @param {string} name  connector name
     * @param {real} scale  new scale
     */
    function setScale(name, scale) {
        editDraft(name, { scale: scale });
        draft = layoutWithoutOverlap(draft);
    }

    /**
     * Turns a draft monitor on or off.
     * @param {string} name  connector name
     * @param {bool} enabled  new state
     */
    function setEnabled(name, enabled) {
        const target = draft.find(m => m.name === name);
        if (!target) return;
        let width = target.width;
        let height = target.height;
        let refreshRate = target.refresh;
        if (enabled && !(width > 0) && target.modes.length > 0) {
            width = target.modes[0].width;
            height = target.modes[0].height;
            refreshRate = target.modes[0].refresh;
        }
        editDraft(name, { enabled: enabled, mirrorOf: "", width: width, height: height, refresh: refreshRate });
        draft = layoutWithoutOverlap(draft);
    }

    /**
     * Rearranges screens in a row if a size change made them overlap.
     * @param {list} list  monitor entries
     * @returns {list}
     */
    function layoutWithoutOverlap(list) {
        const active = list.filter(m => m.enabled && !m.mirrorOf);
        const overlaps = active.some((a, i) => active.slice(i + 1).some(b =>
            a.x < b.x + logicalWidth(b) && b.x < a.x + logicalWidth(a)
            && a.y < b.y + logicalHeight(b) && b.y < a.y + logicalHeight(a)));
        return overlaps ? arrangeInRow(list) : normalized(list);
    }

    /**
     * Places active screens side by side in their current order.
     * @param {list} list  monitor entries
     * @returns {list}
     */
    function arrangeInRow(list) {
        const positions = {};
        let x = 0;
        for (const m of list.filter(o => o.enabled && !o.mirrorOf).sort((a, b) => a.x - b.x || a.name.localeCompare(b.name))) {
            positions[m.name] = x;
            x += logicalWidth(m);
        }
        return list.map(m => m.name in positions ? Object.assign({}, m, { x: positions[m.name], y: 0 }) : m);
    }

    /**
     * Shifts active screens so the smallest coordinates are 0.
     * @param {list} list  monitor entries
     * @returns {list}
     */
    function normalized(list) {
        const active = list.filter(m => m.enabled && !m.mirrorOf);
        if (active.length === 0) return list;
        const minX = Math.min(...active.map(m => m.x));
        const minY = Math.min(...active.map(m => m.y));
        return list.map(m => m.enabled && !m.mirrorOf ? Object.assign({}, m, { x: m.x - minX, y: m.y - minY }) : m);
    }

    /**
     * Snaps a dropped screen to the nearest free edge of another screen.
     * @param {string} name  connector name
     * @param {int} x  drop position
     * @param {int} y  drop position
     */
    function placeDraft(name, x, y) {
        const moving = draft.find(m => m.name === name);
        const others = activeDraft.filter(m => m.name !== name);
        if (!moving || others.length === 0) return;
        const w = logicalWidth(moving);
        const h = logicalHeight(moving);
        const clear = (cx, cy) => others.every(o =>
            cx >= o.x + logicalWidth(o) || o.x >= cx + w || cy >= o.y + logicalHeight(o) || o.y >= cy + h);
        let best = null;
        let bestDistance = Infinity;
        for (const o of others) {
            const ow = logicalWidth(o);
            const oh = logicalHeight(o);
            const candidates = [
                [o.x - w, o.y], [o.x + ow, o.y], [o.x, o.y - h], [o.x, o.y + oh],
                [o.x - w, o.y + oh - h], [o.x + ow, o.y + oh - h],
                [o.x + ow - w, o.y - h], [o.x + ow - w, o.y + oh]
            ];
            for (const [cx, cy] of candidates) {
                const distance = Math.hypot(cx - x, cy - y);
                if (distance < bestDistance && clear(cx, cy)) {
                    best = [cx, cy];
                    bestDistance = distance;
                }
            }
        }
        if (best) {
            editDraft(name, { x: best[0], y: best[1] });
            draft = normalized(draft);
        }
    }

    /**
     * Builds the layout for a preset.
     * @param {string} preset  extend, mirror, internal or external
     * @returns {list or null when unavailable}
     */
    function presetTargets(preset) {
        const copy = monitors.map(m => Object.assign({}, m, { mirrorOf: "" }));
        const internal = copy.find(isInternal) ?? copy[0];
        const externals = copy.filter(m => m !== internal);
        const enable = m => {
            m.enabled = true;
            if (!(m.width > 0) && m.modes.length > 0) {
                m.width = m.modes[0].width;
                m.height = m.modes[0].height;
                m.refresh = m.modes[0].refresh;
            }
        };
        switch (preset) {
        case "internal":
            enable(internal);
            internal.x = 0;
            internal.y = 0;
            for (const m of externals) m.enabled = false;
            return copy;
        case "external": {
            if (externals.length === 0) return null;
            let x = 0;
            for (const m of externals) {
                enable(m);
                m.x = x;
                m.y = 0;
                x += logicalWidth(m);
            }
            internal.enabled = false;
            return copy;
        }
        case "extend": {
            let x = 0;
            for (const m of [internal, ...externals]) {
                enable(m);
                m.x = x;
                m.y = 0;
                x += logicalWidth(m);
            }
            return copy;
        }
        case "mirror":
            if (externals.length === 0) return null;
            enable(internal);
            for (const m of externals) {
                enable(m);
                m.mirrorOf = internal.name;
            }
            return copy;
        default:
            return null;
        }
    }

    /**
     * Applies a preset, pending confirmation.
     * @param {string} preset  preset name
     */
    function applyPreset(preset) {
        const targets = presetTargets(preset);
        if (targets) startChange(targets);
    }

    /** Applies the draft, pending confirmation. */
    function applyDraft() {
        startChange(draft);
    }

    /**
     * Applies a layout, arming a watchdog that restores the previous one.
     * @param {list} targets  monitor entries
     */
    function startChange(targets) {
        if (pending || applier.running) return;
        const problem = validationError(targets);
        if (problem !== "") {
            errorMessage = problem;
            return;
        }
        const current = JSON.stringify(monitors.map(rule));
        if (JSON.stringify(targets.map(rule)) === current) return;
        errorMessage = "";
        previousRules = orderedRules(monitors);

        // The watchdog runs outside the shell, so it reverts the change even if the shell crashes.
        changeCounter++;
        watchdogToken = `${runtimeDir}/hyprdora-display-${Quickshell.processId}-${changeCounter}`;
        Quickshell.execDetached(["sh", "-c",
            'touch "$1"; sleep "$3"; if [ -e "$1" ]; then rm -f "$1"; hyprctl eval "$2"; fi',
            "hyprdora-display-watchdog", watchdogToken, previousRules.join(" "), String(confirmSeconds + 3)]);

        applier.command = applyCommand(orderedRules(targets));
        applier.running = true;
        secondsLeft = confirmSeconds;
        pending = true;
        countdown.restart();
    }

    /** Cancels the running watchdog. */
    function disarmWatchdog() {
        if (watchdogToken !== "") Quickshell.execDetached(["rm", "-f", watchdogToken]);
        watchdogToken = "";
    }

    /**
     * Writes the rules to monitors.lua, keeping the previous version as a backup.
     * @param {list} rules  Lua monitor rules
     */
    function save(rules) {
        const previous = savedFile.text();
        if (previous !== "") backupFile.setText(previous);
        savedFile.setText(`-- Generated by the HyprDora shell. Do not edit.\n${rules.join("\n")}\n`);
    }

    /**
     * Shows a failed save to the user.
     * @param {int} error  FileViewError value
     */
    function reportSaveError(error) {
        root.errorMessage = I18n.t("displays.error.saveFailed");
        console.warn("displays: save:", FileViewError.toString(error));
    }

    /** Confirms the pending change and saves it. */
    function keepChange() {
        if (!pending) return;
        countdown.stop();
        pending = false;
        disarmWatchdog();
        saveAfterFetch = true;
        refresh();
    }

    /** Restores the layout from before the pending change. */
    function revertChange() {
        if (!pending) return;
        countdown.stop();
        pending = false;
        disarmWatchdog();
        applier.command = applyCommand(previousRules);
        applier.running = true;
    }

    /** Turns a screen back on when the only active one was unplugged, for example in external-only mode. */
    function rescueIfNoActiveScreen() {
        if (pending || monitors.length === 0 || monitors.some(m => m.enabled && !m.mirrorOf)) return;
        const internal = monitors.find(isInternal) ?? monitors[0];
        applier.command = applyCommand([ruleFor(internal.name, Object.assign({}, internal, { enabled: true, mirrorOf: "" }), "auto")]);
        applier.running = true;
    }

    /** Moves a lone screen to 0x0. After unplugging a monitor it can keep an old position such as 3360x0. */
    function normalizeSingleScreen() {
        if (pending || applier.running) return;
        const active = monitors.filter(m => m.enabled && !m.mirrorOf);
        if (active.length !== 1 || (active[0].x === 0 && active[0].y === 0)) return;
        applier.command = applyCommand([ruleFor(active[0].name, active[0], "0x0")]);
        applier.running = true;
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft--;
            if (root.secondsLeft <= 0) root.revertChange();
        }
    }

    Process {
        id: fetcher

        command: ["hyprctl", "-j", "monitors", "all"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                let parsed;
                try {
                    parsed = root.parseMonitors(text);
                } catch (e) {
                    console.warn("displays: unreadable hyprctl response");
                    return;
                }
                root.monitors = parsed;
                if (!root.pending) root.resetDraft();
                if (!parsed.some(m => m.name === root.selectedName)) root.selectedName = parsed[0]?.name ?? "";
                if (root.saveAfterFetch) {
                    root.saveAfterFetch = false;
                    root.save(parsed.map(root.savedRule));
                }
                root.rescueIfNoActiveScreen();
                root.normalizeSingleScreen();
            }
        }
    }

    Process {
        id: applier

        stdout: StdioCollector {
            id: applierOutput
        }

        onExited: exitCode => {
            const failed = exitCode !== 0 || applierOutput.text.split(/\s+/).some(word => word !== "" && word !== "ok");
            if (failed) {
                root.errorMessage = I18n.t("displays.error.rejected");
                console.warn("displays: hyprctl response:", applierOutput.text.trim());
                root.revertChange();
            }
            refreshDelay.restart();
        }
    }

    // Hyprland needs a moment to apply the rules.
    Timer {
        id: refreshDelay
        interval: 400
        onTriggered: root.refresh()
    }

    FileView {
        id: savedFile
        path: root.configPath
        blockLoading: true
        printErrors: false
        onSaveFailed: error => root.reportSaveError(error)
    }

    FileView {
        id: backupFile
        path: `${root.configPath}.bak`
        printErrors: false
        onSaveFailed: error => root.reportSaveError(error)
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name.startsWith("monitor") || event.name === "configreloaded") refreshDelay.restart();
        }
    }

    IpcHandler {
        target: "displays"

        function describe(): string {
            return JSON.stringify({
                pending: root.pending,
                secondsLeft: root.secondsLeft,
                dirty: root.dirty,
                selected: root.selectedName,
                error: root.errorMessage,
                rules: root.monitors.map(root.rule),
                draft: root.draft.map(root.rule),
                saved: root.monitors.map(root.savedRule)
            });
        }
        function preview(preset: string): string {
            const targets = root.presetTargets(preset);
            return targets ? JSON.stringify({ rules: root.orderedRules(targets), error: root.validationError(targets) }) : "null";
        }
        function preset(name: string): void { root.applyPreset(name); }
        function select(name: string): void { root.select(name); }
        function setEnabled(name: string, enabled: bool): void { root.setEnabled(name, enabled); }
        function setScale(name: string, scale: real): void { root.setScale(name, scale); }
        function setMode(name: string, width: int, height: int, rate: real): void { root.setMode(name, width, height, rate); }
        function place(name: string, x: int, y: int): void { root.placeDraft(name, x, y); }
        function apply(): void { root.applyDraft(); }
        function reset(): void { root.resetDraft(); }
        function keep(): void { root.keepChange(); }
        function revert(): void { root.revertChange(); }
    }
}
