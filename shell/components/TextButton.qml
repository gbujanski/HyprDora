import QtQuick
import qs.config

Rectangle {
    id: root

    property string text: ""
    property bool primary: false
    property bool active: true

    signal clicked()

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 30
    radius: Theme.radius
    color: !active ? Theme.surface
        : primary ? Theme.accent
        : area.containsMouse ? Theme.surfaceHover : Theme.surface

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.weight: Font.Medium
        color: !root.active ? Theme.dim : root.primary ? Theme.accentText : Theme.foreground
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.active
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
