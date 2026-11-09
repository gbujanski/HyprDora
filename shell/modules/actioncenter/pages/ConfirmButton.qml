import QtQuick
import qs.config
import qs.components

Rectangle {
    id: root

    property string text: ""
    property bool selected: false
    property bool danger: false

    signal clicked

    implicitWidth: label.implicitWidth + 28
    implicitHeight: 34
    radius: Theme.radius
    color: !selected ? Theme.surfaceHover : danger ? Theme.error : Theme.foreground

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        font.weight: Font.Medium
        color: root.selected ? Theme.background : Theme.foreground
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
