import QtQuick
import qs.config

// Single choice from options: [{ value, label, icon, enabled }].
Rectangle {
    id: root

    property var options: []
    property var currentValue

    signal selected(var value)

    implicitHeight: 38
    radius: Theme.radius
    color: Theme.surface

    Row {
        id: segments

        anchors {
            fill: parent
            margins: 3
        }
        // A gap keeps the hover of one option from touching the selected one.
        spacing: 3

        readonly property real available: width - spacing * (root.options.length - 1)
        // Sum of the widths the options need; each one gets that, plus an equal share of what is left.
        readonly property real needed: {
            let total = 0;
            for (const child of children)
                total += child.needed ?? 0;
            return total;
        }

        Repeater {
            model: root.options

            Rectangle {
                id: segment

                required property var modelData

                readonly property bool isCurrent: modelData.value === root.currentValue
                readonly property bool isEnabled: modelData.enabled ?? true

                // Icon, gap, text and a margin of 10 on each side; shrinks proportionally when space runs out.
                readonly property real needed: (segment.modelData.icon ? 18 : 0) + label.implicitWidth + 20
                width: segments.needed <= segments.available ? needed + (segments.available - segments.needed) / root.options.length : needed * segments.available / segments.needed
                height: parent.height
                radius: Theme.radius - 1
                color: isCurrent ? Theme.accent : segmentArea.containsMouse && isEnabled ? Theme.surfaceHover : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animFast
                    }
                }

                Row {
                    anchors.centerIn: parent
                    // Room for the content, with a margin on both sides.
                    width: Math.min(implicitWidth, segment.width - 16)
                    spacing: 4

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: segment.modelData.icon ?? ""
                        font.pixelSize: 14
                        color: segment.isCurrent ? Theme.accentText : segment.isEnabled ? Theme.foreground : Theme.dim
                    }

                    Label {
                        id: label
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, segment.width - 16 - 18)
                        elide: Text.ElideRight
                        text: segment.modelData.label
                        font.pixelSize: Theme.fontSizeSmall + 1
                        font.weight: segment.isCurrent ? Font.Medium : Font.Normal
                        color: segment.isCurrent ? Theme.accentText : segment.isEnabled ? Theme.foreground : Theme.dim
                    }
                }

                MouseArea {
                    id: segmentArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: segment.isEnabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(segment.modelData.value)
                }
            }
        }
    }
}
