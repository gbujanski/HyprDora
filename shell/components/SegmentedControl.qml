import QtQuick
import qs.config

// Wybór jednej z kilku opcji: [{ value, label, icon, enabled }].
Rectangle {
    id: root

    property var options: []
    property var currentValue

    signal selected(var value)

    implicitHeight: 36
    radius: Theme.radius
    color: Theme.surface

    Row {
        anchors {
            fill: parent
            margins: 2
        }

        Repeater {
            model: root.options

            Rectangle {
                id: segment

                required property var modelData

                readonly property bool isCurrent: modelData.value === root.currentValue
                readonly property bool isEnabled: modelData.enabled ?? true

                width: parent.width / root.options.length
                height: parent.height
                radius: Theme.radius - 1
                color: isCurrent ? Theme.accent : segmentArea.containsMouse && isEnabled ? Theme.surfaceHover : "transparent"

                Behavior on color { ColorAnimation { duration: Theme.animFast } }

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: segment.modelData.icon ?? ""
                        font.pixelSize: 14
                        color: segment.isCurrent ? Theme.accentText : segment.isEnabled ? Theme.foreground : Theme.dim
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
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
