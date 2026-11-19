import QtQuick
import qs.config

Rectangle {
    id: root

    property string icon: ""
    property color iconColor: Theme.foreground
    property string tooltip: ""
    property bool active: true
    // The background under the pointer; a button on a coloured surface passes a shade of that colour.
    property color hoverColor: Theme.surfaceHover

    signal clicked

    implicitWidth: 30
    implicitHeight: 30
    radius: Theme.radius
    // Fades from a transparent shade of the same colour, not from transparent black, which would darken
    // the surface underneath on the way.
    color: area.containsMouse && active ? hoverColor : Qt.rgba(hoverColor.r, hoverColor.g, hoverColor.b, 0)

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

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
