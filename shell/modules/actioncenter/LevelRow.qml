import QtQuick
import qs.config
import qs.components

// Ikona, nazwa, procent i suwak dla jasności oraz podobnych wartości.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property real value: 0

    signal moved(real value)

    implicitHeight: 46

    Icon {
        id: levelIcon
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: 30
        text: root.icon
        color: Theme.foreground
    }

    Column {
        anchors {
            left: levelIcon.right
            right: parent.right
            leftMargin: 8
            rightMargin: 34
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Item {
            width: parent.width
            height: titleLabel.implicitHeight

            Label {
                id: titleLabel
                text: root.title
            }

            Label {
                anchors.right: parent.right
                text: `${Math.round(root.value * 100)}%`
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Slider {
            width: parent.width
            value: root.value
            onMoved: value => root.moved(value)
        }
    }
}
