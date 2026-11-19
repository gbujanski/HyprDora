import QtQuick
import qs.config

// One of the two buttons of a confirmation, such as Cancel and Power off: the selected one is filled, in red
// when it does something that cannot be undone, so arrows and Enter show which one they pick.
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
