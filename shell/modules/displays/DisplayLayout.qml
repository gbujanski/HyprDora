import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/DisplayGeometry.js" as Geometry

// Screen layout: dragging snaps a screen to a neighbor's edge.
Rectangle {
    id: root

    readonly property var screens: Displays.activeDraft
    readonly property real boundsWidth: Math.max(1, ...screens.map(m => m.x + Geometry.logicalWidth(m)))
    readonly property real boundsHeight: Math.max(1, ...screens.map(m => m.y + Geometry.logicalHeight(m)))
    readonly property real factor: Math.min((width - 24) / boundsWidth, (height - 24) / boundsHeight)
    readonly property real offsetX: (width - boundsWidth * factor) / 2
    readonly property real offsetY: (height - boundsHeight * factor) / 2

    implicitHeight: 150
    radius: Theme.radius
    color: Theme.surface

    Repeater {
        model: root.screens

        Rectangle {
            id: screenRect

            required property var modelData

            property real dragX: 0
            property real dragY: 0

            readonly property bool isSelected: Displays.selected?.name === modelData.name

            x: root.offsetX + modelData.x * root.factor + dragX
            y: root.offsetY + modelData.y * root.factor + dragY
            z: dragArea.pressed ? 2 : 1
            width: Geometry.logicalWidth(modelData) * root.factor
            height: Geometry.logicalHeight(modelData) * root.factor
            radius: Theme.radiusSmall
            color: isSelected ? Theme.accentSoft : Theme.surfaceHover
            border.width: isSelected ? 2 : 1
            border.color: isSelected ? Theme.accent : Theme.dim

            Label {
                anchors {
                    fill: parent
                    margins: 4
                }
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSmall
                text: `${screenRect.modelData.name}\n${screenRect.modelData.width}×${screenRect.modelData.height}`
            }

            MouseArea {
                id: dragArea

                property point start

                anchors.fill: parent
                preventStealing: true
                cursorShape: root.screens.length > 1 ? Qt.SizeAllCursor : Qt.PointingHandCursor

                onPressed: mouse => {
                    Displays.select(screenRect.modelData.name);
                    start = mapToItem(root, mouse.x, mouse.y);
                }
                onPositionChanged: mouse => {
                    const position = mapToItem(root, mouse.x, mouse.y);
                    screenRect.dragX = position.x - start.x;
                    screenRect.dragY = position.y - start.y;
                }
                onReleased: {
                    const moved = Math.hypot(screenRect.dragX, screenRect.dragY) > 4;
                    const logicalX = screenRect.modelData.x + screenRect.dragX / root.factor;
                    const logicalY = screenRect.modelData.y + screenRect.dragY / root.factor;
                    const name = screenRect.modelData.name;
                    screenRect.dragX = 0;
                    screenRect.dragY = 0;
                    if (moved)
                        Displays.placeDraft(name, logicalX, logicalY);
                }
            }
        }
    }
}
