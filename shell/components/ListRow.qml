import QtQuick
import qs.config

// Clickable list row, optionally marked as selected.
Rectangle {
    id: root

    property string text: ""
    property string trailingIcon: ""
    property bool selected: false

    signal clicked()

    implicitHeight: 34
    radius: Theme.radius
    color: selected ? Theme.surface : area.containsMouse ? Theme.surface : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Label {
        anchors {
            left: parent.left
            right: trailing.left
            leftMargin: 10
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        text: root.text
        elide: Text.ElideRight
        font.weight: root.selected ? Font.Medium : Font.Normal
    }

    Icon {
        id: trailing
        anchors {
            right: parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        text: root.selected ? Icons.check : root.trailingIcon
        color: root.selected ? Theme.accent : Theme.muted
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
