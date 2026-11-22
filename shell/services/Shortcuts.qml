pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Keyboard shortcuts with their descriptions, read from Hyprland, so changes in the user's binds.lua show too,
// in the groups binds.lua gives them, and the touchpad gestures after them. The settings and the cheat sheet
// both list them, reading them again each time they open.
Singleton {
    id: root

    // [{ title, rows: [{ description, keys }] }], in the order of binds.lua.
    property var groups: []

    readonly property var keyNames: ({
            left: "←",
            right: "→",
            up: "↑",
            down: "↓",
            minus: "-",
            slash: "/",
            Escape: "Esc",
            SPACE: "Space",
            "mouse:272": I18n.t("shortcuts.leftMouse"),
            "mouse:273": I18n.t("shortcuts.rightMouse"),
            mouse_down: I18n.t("shortcuts.wheelDown"),
            mouse_up: I18n.t("shortcuts.wheelUp")
        })

    // Hyprland does not list gestures the way it lists bindings, so these follow hypr/input.lua by hand.
    readonly property var gestures: [
        {
            description: I18n.t("shortcuts.gesture.workspace"),
            keys: I18n.t("shortcuts.gesture.threeFingers") + " ← →"
        },
        {
            description: I18n.t("shortcut.Windows and workspaces"),
            keys: I18n.t("shortcuts.gesture.threeFingers") + " ↑"
        },
        {
            description: I18n.t("shortcut.App launcher"),
            keys: I18n.t("shortcuts.gesture.pinchFour")
        }
    ]

    /** Reads the shortcuts from Hyprland again. */
    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    /**
     * Writes the modifiers of a binding the way they are pressed, such as SUPER + SHIFT.
     * @param {int} modmask  modifier bits from hyprctl
     * @returns {list} names
     */
    function modifiers(modmask) {
        return [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]].filter(m => modmask & m[0]).map(m => m[1]);
    }

    /**
     * Turns hyprctl bindings into groups of rows. The group comes before a tab in the description, as
     * hypr/lib/binds.lua writes it. Bindings with the same description share a row, and numbered series such
     * as Workspace 1 to 10 collapse into one.
     * @param {list} binds  hyprctl bindings
     * @returns {list} groups of { title, rows: [{ description, keys }] }
     */
    function grouped(binds) {
        const groupList = [];
        const groupsByName = {};
        const rowsByName = {};
        for (const b of binds) {
            // Hardware keys carry their meaning printed on them, and a release binding only completes a press.
            if (!b.has_description || b.release || b.key.startsWith("XF86"))
                continue;
            const tab = b.description.indexOf("\t");
            const groupName = tab >= 0 ? b.description.slice(0, tab) : "";
            const text = tab >= 0 ? b.description.slice(tab + 1) : b.description;
            let group = groupsByName[groupName];
            if (!group) {
                group = groupsByName[groupName] = {
                    name: groupName,
                    rows: []
                };
                groupList.push(group);
            }
            const series = text.match(/^(.*\S) (\d+)$/);
            const name = series ? series[1] : text;
            const key = keyNames[b.key] ?? b.key;
            let row = rowsByName[name];
            if (!row) {
                row = rowsByName[name] = {
                    name: name,
                    combos: [],
                    numbers: [],
                    seriesKeys: []
                };
                group.rows.push(row);
            }
            if (series) {
                row.numbers.push(Number(series[2]));
                row.seriesKeys.push(key);
                row.seriesModifiers = modifiers(b.modmask);
            } else {
                row.combos.push([...modifiers(b.modmask), key].join(" + "));
            }
        }
        // Shortcuts without a group, as from an older binds.lua, come last.
        const ordered = [...groupList.filter(g => g.name !== ""), ...groupList.filter(g => g.name === "")];
        return ordered.map(g => ({
                    title: g.name === "" ? I18n.t("shortcuts.group.other") : I18n.tOr(`shortcuts.group.${g.name}`, g.name.toUpperCase()),
                    rows: g.rows.map(row => {
                        const description = I18n.tOr(`shortcut.${row.name}`, row.name);
                        if (row.numbers.length === 0)
                            return {
                                description: description,
                                keys: row.combos.join("  /  ")
                            };
                        return {
                            description: `${description} ${Math.min(...row.numbers)}–${Math.max(...row.numbers)}`,
                            keys: [...row.seriesModifiers, `${row.seriesKeys[0]}…${row.seriesKeys[row.seriesKeys.length - 1]}`].join(" + ")
                        };
                    })
                }));
    }

    Process {
        id: reader
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const groups = root.grouped(JSON.parse(text));
                    root.groups = groups.length > 0 ? [...groups,
                        {
                            title: I18n.t("shortcuts.gestures"),
                            rows: root.gestures
                        }
                    ] : [];
                } catch (e) {
                    console.warn(log, "unreadable hyprctl response");
                }
            }
        }
    }

    LoggingCategory {
        id: log
        name: "hyprdora.shortcuts"
    }
}
