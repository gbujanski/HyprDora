import QtQuick
import qs.config
import qs.components
import qs.services

// Default applications by kind. Hovering a row opens the installed applications beside it.
Column {
    id: root

    // The settings menu, which shows the choices.
    property Item menu: null

    spacing: 2

    Component.onCompleted: DefaultApps.refresh()

    Repeater {
        model: DefaultApps.kinds

        Rectangle {
            id: row

            required property var modelData
            readonly property var app: DefaultApps.apps[modelData.id] ?? null
            readonly property bool open: root.menu?.submenu?.owner === row

            /** Shows the applications for this kind beside the row. */
            function showOptions() {
                const choices = app?.choices ?? [];
                if (choices.length === 0)
                    return;
                root.menu?.openSubmenu(row, choices.map(id => ({
                            value: id,
                            label: DefaultApps.name(id)
                        })), app.current, id => DefaultApps.set(modelData.id, id));
            }

            width: root.width
            height: 34
            radius: Theme.radius
            color: open || rowArea.containsMouse ? Theme.surface : "transparent"

            Label {
                id: kindLabel
                anchors {
                    left: parent.left
                    leftMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: I18n.t(`defaultApps.${row.modelData.id}`)
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
                    // Takes the space the kind's name leaves free.
                    width: Math.min(implicitWidth, row.width - kindLabel.implicitWidth - 50)
                    text: row.app?.current ? DefaultApps.name(row.app.current) : "—"
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.chevronRight
                    color: Theme.muted
                    opacity: (row.app?.choices.length ?? 0) > 0 ? 1 : 0
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
