import QtQuick
import qs.config

Rectangle {
    id: root

    property string text: ""

    visible: text !== ""
    implicitHeight: errorText.implicitHeight + 16
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Theme.error

    Icon {
        id: errorIcon
        anchors {
            left: parent.left
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
        text: Icons.alert
        color: Theme.error
    }

    Label {
        id: errorText
        anchors {
            left: errorIcon.right
            right: parent.right
            leftMargin: 8
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        wrapMode: Text.Wrap
        text: root.text
    }
}
