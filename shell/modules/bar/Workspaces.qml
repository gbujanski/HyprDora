import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.components

Row {
    id: root

    required property ShellScreen screen

    readonly property int persistentCount: 5
    readonly property var monitor: Hyprland.monitorFor(screen)

    // Always 1-5, plus any higher workspace that exists. Negative ids are special workspaces.
    readonly property var ids: {
        const result = [];
        for (let i = 1; i <= persistentCount; i++) result.push(i);
        for (const ws of Hyprland.workspaces.values) {
            if (ws.id > persistentCount) result.push(ws.id);
        }
        return result.sort((a, b) => a - b);
    }

    spacing: 2

    Repeater {
        model: root.ids

        Rectangle {
            id: button

            required property int modelData

            readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
            readonly property bool current: root.monitor?.activeWorkspace?.id === modelData
            readonly property bool occupied: (workspace?.toplevels.values.length ?? 0) > 0
            readonly property bool urgent: workspace?.urgent ?? false

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 26
            implicitHeight: Theme.barHeight - 8
            radius: Theme.radius
            color: urgent ? Theme.warning
                : current ? Theme.accent
                : area.containsMouse ? Theme.surface : "transparent"

            Behavior on color { ColorAnimation { duration: Theme.animFast } }

            Label {
                anchors.centerIn: parent
                text: button.modelData
                font.weight: button.current ? Font.DemiBold : Font.Normal
                color: button.current || button.urgent ? Theme.accentText
                    : button.occupied ? Theme.foreground : Theme.dim
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch(`workspace ${button.modelData}`)
                onWheel: wheel => Hyprland.dispatch(`workspace ${wheel.angleDelta.y > 0 ? "m-1" : "m+1"}`)
            }
        }
    }
}
