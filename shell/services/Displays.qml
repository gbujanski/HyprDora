pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Monitory: odczyt stanu, szkic zmian, bezpieczne zastosowanie i zapis.
Singleton {
    id: root

    readonly property int confirmSeconds: 15
    readonly property string configPath: `${Quickshell.env("HOME")}/.config/hypr/monitors.conf`
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")

    property var monitors: []
    property var draft: []
    property string selectedName: ""
    property string errorMessage: ""

    // Zmiana czeka na potwierdzenie; bez niego wraca stan poprzedni.
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

    function isInternal(monitor) {
        return /^(eDP|LVDS|DSI)/.test(monitor.name);
    }

    function logicalWidth(monitor) {
        return Math.ceil(monitor.width / monitor.scale);
    }

    function logicalHeight(monitor) {
        return Math.ceil(monitor.height / monitor.scale);
    }

    function displayName(monitor) {
        if (isInternal(monitor)) return "Ekran laptopa";
        return monitor.description || monitor.name;
    }

    function parseModes(modes) {
        const result = [];
        for (const text of modes) {
            const match = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(text);
            if (match) result.push({ width: Number(match[1]), height: Number(match[2]), refresh: Number(match[3]) });
        }
        return result;
    }

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

    function modeText(monitor) {
        if (monitor.width > 0 && monitor.height > 0)
            return `${monitor.width}x${monitor.height}@${Number(monitor.refresh).toFixed(2)}`;
        return "preferred";
    }

    function extras(monitor) {
        return (monitor.transform ? `,transform,${monitor.transform}` : "") + (monitor.vrr ? ",vrr,1" : "");
    }

    // Reguła dla podanego identyfikatora monitora.
    function ruleFor(id, monitor, position) {
        if (!monitor.enabled) return `${id},disable`;
        const where = position ?? (monitor.mirrorOf ? "auto" : `${monitor.x}x${monitor.y}`);
        const mirror = monitor.mirrorOf ? `,mirror,${monitor.mirrorOf}` : "";
        return `${id},${modeText(monitor)},${where},${monitor.scale}${mirror}${extras(monitor)}`;
    }

    function rule(monitor) {
        return ruleFor(monitor.name, monitor);
    }

    // W pliku: opis jest stabilniejszy niż nazwa złącza. Ekran laptopa zawsze zostaje
    // włączony, żeby start bez zewnętrznego monitora nie dał czarnego ekranu.
    function savedRule(monitor) {
        const id = monitor.description ? `desc:${monitor.description}` : monitor.name;
        if (isInternal(monitor) && !monitor.enabled)
            return ruleFor(id, Object.assign({}, monitor, { enabled: true, mirrorOf: "" }), "auto");
        return ruleFor(id, monitor);
    }

    function batchFor(rules) {
        return rules.map(r => `keyword monitor ${r}`).join(" ; ");
    }

    // Najpierw włączane, potem wyłączane: nigdy nie zostajemy bez aktywnego ekranu.
    function orderedRules(targets) {
        const on = targets.filter(m => m.enabled);
        const off = targets.filter(m => !m.enabled);
        return [...on, ...off].map(rule);
    }

    function validationError(targets) {
        if (!targets.some(m => m.enabled && !m.mirrorOf)) return "Co najmniej jeden ekran musi zostać włączony.";
        for (const m of targets) {
            if (m.mirrorOf && !targets.some(o => o.name === m.mirrorOf && o.enabled && !o.mirrorOf))
                return "Ekran źródłowy kopii musi być włączony.";
        }
        return "";
    }

    function refresh() {
        if (!fetcher.running) fetcher.running = true;
    }

    function select(name) {
        selectedName = name;
    }

    function resetDraft() {
        draft = monitors.map(m => Object.assign({}, m));
        errorMessage = "";
    }

    function editDraft(name, patch) {
        draft = draft.map(m => m.name === name ? Object.assign({}, m, patch) : m);
    }

    function setMode(name, width, height, refreshRate) {
        editDraft(name, { width: width, height: height, refresh: refreshRate });
        draft = layoutWithoutOverlap(draft);
    }

    function setScale(name, scale) {
        editDraft(name, { scale: scale });
        draft = layoutWithoutOverlap(draft);
    }

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

    // Przesuwa ekrany w poziomie tak, żeby po zmianie rozmiaru nie nachodziły na siebie.
    function layoutWithoutOverlap(list) {
        const active = list.filter(m => m.enabled && !m.mirrorOf);
        const overlaps = active.some((a, i) => active.slice(i + 1).some(b =>
            a.x < b.x + logicalWidth(b) && b.x < a.x + logicalWidth(a)
            && a.y < b.y + logicalHeight(b) && b.y < a.y + logicalHeight(a)));
        return overlaps ? arrangeInRow(list) : normalized(list);
    }

    function arrangeInRow(list) {
        const positions = {};
        let x = 0;
        for (const m of list.filter(o => o.enabled && !o.mirrorOf).sort((a, b) => a.x - b.x || a.name.localeCompare(b.name))) {
            positions[m.name] = x;
            x += logicalWidth(m);
        }
        return list.map(m => m.name in positions ? Object.assign({}, m, { x: positions[m.name], y: 0 }) : m);
    }

    // Najmniejsze współrzędne aktywnych ekranów zawsze wynoszą 0.
    function normalized(list) {
        const active = list.filter(m => m.enabled && !m.mirrorOf);
        if (active.length === 0) return list;
        const minX = Math.min(...active.map(m => m.x));
        const minY = Math.min(...active.map(m => m.y));
        return list.map(m => m.enabled && !m.mirrorOf ? Object.assign({}, m, { x: m.x - minX, y: m.y - minY }) : m);
    }

    // Upuszczony ekran przykleja się do najbliższej krawędzi innego ekranu.
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

    function applyPreset(preset) {
        const targets = presetTargets(preset);
        if (targets) startChange(targets);
    }

    function applyDraft() {
        startChange(draft);
    }

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

        // Strażnik działa poza shellem: cofnie zmianę, nawet gdyby shell padł po jej zastosowaniu.
        changeCounter++;
        watchdogToken = `${runtimeDir}/hyprdora-display-${Quickshell.processId}-${changeCounter}`;
        Quickshell.execDetached(["sh", "-c",
            'touch "$1"; sleep "$3"; if [ -e "$1" ]; then rm -f "$1"; hyprctl --batch "$2"; fi',
            "hyprdora-display-watchdog", watchdogToken, batchFor(previousRules), String(confirmSeconds + 3)]);

        applier.command = ["hyprctl", "--batch", batchFor(orderedRules(targets))];
        applier.running = true;
        secondsLeft = confirmSeconds;
        pending = true;
        countdown.restart();
    }

    function disarmWatchdog() {
        if (watchdogToken !== "") Quickshell.execDetached(["rm", "-f", watchdogToken]);
        watchdogToken = "";
    }

    function keepChange() {
        if (!pending) return;
        countdown.stop();
        pending = false;
        disarmWatchdog();
        saveAfterFetch = true;
        refresh();
    }

    function revertChange() {
        if (!pending) return;
        countdown.stop();
        pending = false;
        disarmWatchdog();
        applier.command = ["hyprctl", "--batch", batchFor(previousRules)];
        applier.running = true;
    }

    // Odłączono jedyny aktywny ekran, np. przy trybie „tylko zewnętrzny”.
    function rescueIfNoActiveScreen() {
        if (pending || monitors.length === 0 || monitors.some(m => m.enabled && !m.mirrorOf)) return;
        const internal = monitors.find(isInternal) ?? monitors[0];
        applier.command = ["hyprctl", "keyword", "monitor", ruleFor(internal.name, Object.assign({}, internal, { enabled: true, mirrorOf: "" }), "auto")];
        applier.running = true;
    }

    // Po odłączeniu monitora jedyny ekran może zostać z dawną pozycją, np. 3360x0.
    function normalizeSingleScreen() {
        if (pending || applier.running) return;
        const active = monitors.filter(m => m.enabled && !m.mirrorOf);
        if (active.length !== 1 || (active[0].x === 0 && active[0].y === 0)) return;
        applier.command = ["hyprctl", "keyword", "monitor", ruleFor(active[0].name, active[0], "0x0")];
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
                    console.warn("displays: nieczytelna odpowiedź hyprctl");
                    return;
                }
                root.monitors = parsed;
                if (!root.pending) root.resetDraft();
                if (!parsed.some(m => m.name === root.selectedName)) root.selectedName = parsed[0]?.name ?? "";
                if (root.saveAfterFetch) {
                    root.saveAfterFetch = false;
                    saver.rules = parsed.map(root.savedRule);
                    saver.running = true;
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
                root.errorMessage = "Hyprland odrzucił ustawienia monitora.";
                console.warn("displays: odpowiedź hyprctl:", applierOutput.text.trim());
                root.revertChange();
            }
            refreshDelay.restart();
        }
    }

    // Hyprland potrzebuje chwili na zastosowanie reguł.
    Timer {
        id: refreshDelay
        interval: 400
        onTriggered: root.refresh()
    }

    Process {
        id: saver

        property var rules: []

        command: ["python3", "-I", Quickshell.shellPath("scripts/save-monitors.py"), root.configPath]
        stdinEnabled: true

        onStarted: write(JSON.stringify(rules) + "\n")

        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: saverErrors
        }

        onRunningChanged: {
            // Skrypt czyta stdin do końca, więc zamykamy go po wysłaniu reguł.
            if (running) Qt.callLater(() => { saver.stdinEnabled = false; });
            else stdinEnabled = true;
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                root.errorMessage = "Nie udało się zapisać ustawień monitorów.";
                console.warn("displays: zapis:", saverErrors.text.trim());
            }
        }
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
