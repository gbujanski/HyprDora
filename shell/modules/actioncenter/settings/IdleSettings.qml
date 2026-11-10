import QtQuick
import qs.config
import qs.components

// Times after which the screen dims, locks and the laptop suspends. Hovering a row opens its choices beside it.
Column {
    id: root

    // The settings menu, which shows the choices.
    property Item menu: null

    readonly property var steps: [0, 60, 120, 180, 240, 300, 600, 900, 1800, 3600]
    readonly property var rows: [
        {
            key: "dim",
            setting: "idleDim",
            title: I18n.t("idle.dim")
        },
        {
            key: "lock",
            setting: "idleLock",
            title: I18n.t("idle.lock")
        },
        {
            key: "suspend",
            setting: "idleSuspend",
            title: I18n.t("idle.suspend")
        }
    ]

    /**
     * Returns the label for a time.
     * @param {int} seconds  time in seconds, 0 for off
     * @returns {string}
     */
    function label(seconds) {
        if (seconds === 0)
            return I18n.t("idle.never");
        return seconds % 60 === 0 ? I18n.t("idle.minutes", {
            count: seconds / 60
        }) : I18n.t("idle.seconds", {
            count: seconds
        });
    }

    /**
     * Returns the choices for a step, keeping a value set outside this list.
     * @param {int} current  current value in seconds
     * @returns {array} [{ value, label }]
     */
    function options(current) {
        const values = steps.includes(current) ? steps : [...steps, current].sort((a, b) => a - b);
        return values.map(seconds => ({
                    value: seconds,
                    label: label(seconds)
                }));
    }

    spacing: 2

    Repeater {
        model: root.rows

        Rectangle {
            id: row

            required property var modelData
            readonly property int value: Settings[modelData.setting]
            readonly property bool open: root.menu?.submenu?.owner === row

            /** Shows this setting's choices beside the row. */
            function showOptions() {
                root.menu?.openSubmenu(row, root.options(value), value, v => Settings.setIn("idle", modelData.key, v));
            }

            width: root.width
            height: 34
            radius: Theme.radius
            color: open || rowArea.containsMouse ? Theme.surface : "transparent"

            Label {
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: row.modelData.title
                color: Theme.muted
            }

            Row {
                anchors {
                    right: parent.right
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                spacing: 4

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.label(row.value)
                    font.weight: Font.Medium
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.chevronRight
                    color: Theme.muted
                }
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: {
                    if (containsMouse)
                        row.showOptions();
                }
                onClicked: row.showOptions()
            }
        }
    }
}
