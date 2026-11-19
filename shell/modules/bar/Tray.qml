import QtQuick
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.config
import qs.components

Row {
    id: root

    required property var barWindow

    spacing: 2

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: item

            required property var modelData

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Theme.barHeight - 6
            implicitHeight: Theme.barHeight - 6
            radius: Theme.radius
            color: area.containsMouse ? Theme.surface : "transparent"

            IconImage {
                anchors.centerIn: parent
                implicitSize: Theme.iconSize
                source: item.modelData.icon
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    const showMenu = mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && item.modelData.onlyMenu);
                    if (showMenu && item.modelData.hasMenu) {
                        const pos = item.mapToItem(null, 0, item.height);
                        item.modelData.display(root.barWindow, pos.x, pos.y);
                    } else if (mouse.button === Qt.LeftButton) {
                        item.modelData.activate();
                    } else if (mouse.button === Qt.MiddleButton) {
                        item.modelData.secondaryActivate();
                    }
                }
                onWheel: wheel => item.modelData.scroll(wheel.angleDelta.y, false)
            }

            Tooltip {
                target: item
                text: item.modelData.tooltipTitle || item.modelData.title
                hovered: area.containsMouse
            }
        }
    }
}
