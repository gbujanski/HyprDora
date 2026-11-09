import QtQuick
import qs.config

Rectangle {
    id: root

    property bool checked: false
    property bool active: true

    signal toggled

    implicitWidth: 38
    implicitHeight: 22
    radius: height / 2
    color: !active ? Theme.surface : checked ? Theme.accent : Theme.dim

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? parent.width - width - 3 : 3
        width: 16
        height: 16
        radius: 8
        color: root.active ? Theme.foreground : Theme.muted

        Behavior on x {
            NumberAnimation {
                duration: Theme.animFast
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
