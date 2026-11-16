pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Finds what the launcher shows: applications, a calculator result, a command, a web search, or clipboard
// history. Everything it starts runs through Hyprland, so it does not belong to the shell's process group.
Singleton {
    id: root

    // How often each application was started, by desktop entry id; kept across sessions.
    property var usage: ({})

    // Clipboard history from cliphist, newest first: [{ line, id, text }].
    property var clipboard: []

    readonly property string stateDir: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/hyprdora`

    // Applications shown in menus. Desktop entries load in the background, so this fills in shortly after start.
    readonly property var applications: DesktopEntries.applications.values.filter(e => !e.noDisplay && !Settings.hiddenApplications.includes(e.id))

    /**
     * Lowercases text and drops diacritics, so "prze" finds "Przeglądarka" and "zolw" finds "Żółw".
     * @param {string} text  any text
     * @returns {string}
     */
    function normalized(text) {
        return (text ?? "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/ł/g, "l");
    }

    /**
     * Scores how well an application matches a query; 0 means no match.
     * @param {DesktopEntry} entry  application
     * @param {string} query  normalized query
     * @returns {real}
     */
    function score(entry, query) {
        const name = normalized(entry.name);
        let best = 0;
        if (name === query)
            best = 100;
        else if (name.startsWith(query))
            best = 80;
        else if (name.split(/[\s\-_.]+/).some(word => word.startsWith(query)))
            best = 70;
        else if (name.includes(query))
            best = 60;
        else {
            const other = [entry.genericName, ...(entry.keywords ?? [])].map(normalized);
            if (other.some(text => text.startsWith(query) || text.split(/\s+/).some(word => word.startsWith(query))))
                best = 45;
            else if (other.some(text => text.includes(query)))
                best = 35;
            else if (normalized(entry.comment).includes(query) || normalized(entry.id).includes(query))
                best = 20;
            else if (subsequence(query, name))
                // Letters in order with gaps, which also forgives a skipped or doubled letter.
                best = 10;
        }
        return best === 0 ? 0 : best + Math.min(25, 6 * Math.log2(1 + (usage[entry.id] ?? 0)));
    }

    /**
     * Whether all letters of a query appear in a text in the same order.
     * @param {string} query  normalized query
     * @param {string} text  normalized text
     * @returns {bool}
     */
    function subsequence(query, text) {
        let at = 0;
        for (const letter of query) {
            at = text.indexOf(letter, at);
            if (at < 0)
                return false;
            at++;
        }
        return query.length >= 3;
    }

    /**
     * Results for a query in the applications mode.
     * @param {string} text  query as typed
     * @returns {list} rows of { kind: "app" | "calc" | "command" | "web", … }
     */
    function search(text) {
        const query = text.trim();
        if (query.startsWith(">")) {
            const command = query.slice(1).trim();
            return command === "" ? [] : [
                {
                    kind: "command",
                    command: command
                }
            ];
        }

        const rows = [];
        const value = calculate(query);
        if (value !== null)
            rows.push({
                kind: "calc",
                value: value
            });

        const q = normalized(query);
        const apps = q === "" ? applications.map(e => ({
                    entry: e,
                    score: usage[e.id] ?? 0
                })).sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name)) : applications.map(e => ({
                    entry: e,
                    score: score(e, q)
                })).filter(r => r.score > 0).sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
        for (const r of apps)
            rows.push({
                kind: "app",
                entry: r.entry
            });

        if (query !== "" && value === null)
            rows.push({
                kind: "web",
                query: query
            });
        return rows;
    }

    /**
     * Results for a query in the clipboard mode.
     * @param {string} text  query as typed
     * @returns {list} rows of { kind: "clip", … }
     */
    function searchClipboard(text) {
        const q = normalized(text.trim());
        return clipboard.filter(c => q === "" || normalized(c.text).includes(q)).map(c => ({
                    kind: "clip",
                    clip: c
                }));
    }

    /**
     * Evaluates arithmetic such as 2*(3+4) or 2,5^2; returns null for anything else.
     * Supports + - * / % ^, parentheses, and a comma or dot as the decimal mark.
     * @param {string} text  query
     * @returns {var} number or null
     */
    function calculate(text) {
        const source = text.replace(/\s+/g, "").replace(/,/g, ".");
        if (!/^[\d.+\-*/%^()]+$/.test(source) || !/\d/.test(source) || !/[+\-*/%^]/.test(source.replace(/^-/, "")))
            return null;
        let at = 0;
        const peek = () => source[at];
        const take = () => source[at++];
        function number() {
            const match = /^\d*\.?\d+|^\d+\./.exec(source.slice(at));
            if (!match)
                throw new Error("number");
            at += match[0].length;
            return parseFloat(match[0]);
        }
        function factor() {
            if (peek() === "-") {
                take();
                return -factor();
            }
            if (peek() === "+") {
                take();
                return factor();
            }
            let value;
            if (peek() === "(") {
                take();
                value = sum();
                if (take() !== ")")
                    throw new Error("parenthesis");
            } else {
                value = number();
            }
            if (peek() === "^") {
                take();
                value = Math.pow(value, factor());
            }
            return value;
        }
        function product() {
            let value = factor();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = take();
                const right = factor();
                value = op === "*" ? value * right : op === "/" ? value / right : value % right;
            }
            return value;
        }
        function sum() {
            let value = product();
            while (peek() === "+" || peek() === "-") {
                const op = take();
                const right = product();
                value = op === "+" ? value + right : value - right;
            }
            return value;
        }
        try {
            const value = sum();
            if (at !== source.length || !isFinite(value))
                return null;
            return Number(value.toPrecision(12));
        } catch (e) {
            return null;
        }
    }

    /**
     * Formats a calculator result in the interface language, without thousands separators.
     * @param {real} value  result
     * @returns {string}
     */
    function formatNumber(value) {
        const text = String(value);
        return I18n.locale.decimalPoint === "," ? text.replace(".", ",") : text;
    }

    /**
     * Runs a shell command as a child of Hyprland.
     * @param {string} command  shell command
     */
    function exec(command) {
        Quickshell.execDetached(["hyprctl", "dispatch", `hl.dsp.exec_cmd([==[${command}]==])`]);
    }

    /**
     * Quotes text for a POSIX shell.
     * @param {string} text  any text
     * @returns {string}
     */
    function quoted(text) {
        return `'${String(text).replace(/'/g, `'\\''`)}'`;
    }

    /**
     * Does what a row stands for and remembers application starts.
     * @param {object} row  result row
     */
    function activate(row) {
        switch (row.kind) {
        case "app":
            usage = Object.assign({}, usage, {
                [row.entry.id]: (usage[row.entry.id] ?? 0) + 1
            });
            usageFile.setText(JSON.stringify(usage));
            exec(`gtk-launch ${quoted(row.entry.id)}`);
            break;
        case "calc":
            exec(`wl-copy ${quoted(formatNumber(row.value))}`);
            break;
        case "command":
            exec(row.command);
            break;
        case "web":
            exec(`xdg-open ${quoted(Settings.webSearchUrl + encodeURIComponent(row.query))}`);
            break;
        case "clip":
            exec(`printf '%s' ${quoted(row.clip.line)} | cliphist decode | wl-copy`);
            break;
        }
    }

    /**
     * Removes a clipboard entry from the history.
     * @param {object} clip  entry from clipboard
     */
    function forget(clip) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | cliphist delete', "hyprdora-clipboard", clip.line]);
        clipboard = clipboard.filter(c => c.line !== clip.line);
    }

    /** Reads the clipboard history again. */
    function refreshClipboard() {
        if (!clipboardReader.running)
            clipboardReader.running = true;
    }

    FileView {
        id: usageFile
        path: `${root.stateDir}/launcher.json`
        printErrors: false
        onLoaded: {
            try {
                root.usage = JSON.parse(text()) ?? {};
            } catch (e) {
                root.usage = {};
            }
        }
    }

    Process {
        id: clipboardReader
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            // Each line is an id, a tab and a preview.
            onStreamFinished: root.clipboard = text.split("\n").filter(Boolean).map(line => {
                const tab = line.indexOf("\t");
                return {
                    line: line,
                    id: line.slice(0, tab),
                    text: line.slice(tab + 1)
                };
            })
        }
    }
}
