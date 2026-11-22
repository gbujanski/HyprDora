import QtQuick
import Quickshell.Io
import qs.config
import qs.components

// Keyboard shortcuts with their descriptions, read from Hyprland, so changes in the user's binds.lua show too.
Column {
    id: root

    property var binds: []

    readonly property var keyNames: ({
            left: "←",
            right: "→",
            up: "↑",
            down: "↓",
            minus: "-",
            Escape: "Esc",
            SPACE: "Space",
            "mouse:272": I18n.t("shortcuts.leftMouse"),
            "mouse:273": I18n.t("shortcuts.rightMouse"),
            mouse_down: I18n.t("shortcuts.wheelDown"),
            mouse_up: I18n.t("shortcuts.wheelUp")
        })

    /**
     * Writes the modifiers of a binding the way they are pressed, such as SUPER + SHIFT.
     * @param {int} modmask  modifier bits from hyprctl
     * @returns {list} names
     */
    function modifiers(modmask) {
        return [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]].filter(m => modmask & m[0]).map(m => m[1]);
    }

    /**
     * Turns hyprctl bindings into rows. Bindings with the same description share a row, and numbered
     * series such as Workspace 1 to 10 collapse into one.
     * @param {list} binds  hyprctl bindings
     * @returns {list} rows of { description, keys }
     */
    function rows(binds) {
        const result = [];
        const byName = {};
        for (const b of binds) {
            // Hardware keys carry their meaning printed on them, and a release binding only completes a press.
            if (!b.has_description || b.release || b.key.startsWith("XF86"))
                continue;
            const series = b.description.match(/^(.*\S) (\d+)$/);
            const name = series ? series[1] : b.description;
            const key = keyNames[b.key] ?? b.key;
            let row = byName[name];
            if (!row) {
                row = byName[name] = {
                    name: name,
                    combos: [],
                    numbers: [],
                    seriesKeys: []
                };
                result.push(row);
            }
            if (series) {
                row.numbers.push(Number(series[2]));
                row.seriesKeys.push(key);
                row.seriesModifiers = modifiers(b.modmask);
            } else {
                row.combos.push([...modifiers(b.modmask), key].join(" + "));
            }
        }
        return result.map(row => {
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
        });
    }

    spacing: 2

    Process {
        command: ["hyprctl", "-j", "binds"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.binds = root.rows(JSON.parse(text));
                } catch (e) {
                    console.warn(log, "unreadable hyprctl response");
                }
            }
        }
    }

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

    Repeater {
        model: [...root.binds, ...(root.binds.length > 0 ? [
                    {
                        title: I18n.t("shortcuts.gestures")
                    }
                ] : []), ...(root.binds.length > 0 ? root.gestures : [])]

        Item {
            required property var modelData

            width: root.width
            height: modelData.title ? 40 : 28

            SectionTitle {
                visible: !!parent.modelData.title
                anchors {
                    left: parent.left
                    leftMargin: 4
                    bottom: parent.bottom
                    bottomMargin: 4
                }
                text: parent.modelData.title ?? ""
            }

            Label {
                visible: !parent.modelData.title
                anchors {
                    left: parent.left
                    right: keys.left
                    leftMargin: 4
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: parent.modelData.description
                elide: Text.ElideRight
            }

            Label {
                id: keys
                anchors {
                    right: parent.right
                    rightMargin: 4
                    verticalCenter: parent.verticalCenter
                }
                text: parent.modelData.keys ?? ""
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }

    LoggingCategory {
        id: log
        name: "hyprdora.shortcuts"
    }
}
