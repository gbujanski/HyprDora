import QtQuick
import qs.config

Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Theme.foreground
    property string tooltip: ""
    property bool active: true

    signal clicked()

    implicitWidth: 30
    implicitHeight: 30
    radius: Theme.radius
    color: area.containsMouse && active ? Theme.surfaceHover : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Icon {
        anchors.centerIn: parent
        text: root.icon
        color: root.active ? root.iconColor : Theme.dim
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Tooltip {
        target: root
        text: root.tooltip
        hovered: area.containsMouse
    }
}
