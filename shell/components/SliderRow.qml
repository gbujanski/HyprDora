import QtQuick
import qs.config

// An icon, a name with its value on the right, and a slider under them, for volume, brightness and the like.
// The icon can be a button, such as mute. Room for one button on the right is kept, unless turned off, even
// without the button, so the sliders of rows one above another line up.
Item {
    id: root

    property string icon: ""
    property color iconColor: Theme.foreground
    // Whether the icon is a button; it emits iconClicked.
    property bool iconClickable: false
    property string iconTooltip: ""
    property string title: ""
    property color titleColor: Theme.foreground
    // Shown on the right of the name; the percentage by default.
    property string valueText: `${Math.round(value * 100)}%`
    property real value: 0
    property bool active: true
    property alias trailing: trailingSlot.data
    property bool reserveTrailing: true

    signal moved(real value)
    signal iconClicked

    implicitHeight: 46

    IconButton {
        id: iconButton
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        visible: root.iconClickable
        active: root.active
        icon: root.icon
        iconColor: root.iconColor
        tooltip: root.iconTooltip
        onClicked: root.iconClicked()
    }

    Icon {
        anchors.centerIn: iconButton
        visible: !root.iconClickable
        text: root.icon
        color: root.iconColor
    }

    Column {
        anchors {
            left: iconButton.right
            right: trailingSlot.left
            leftMargin: 8
            rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Item {
            width: parent.width
            height: nameLabel.implicitHeight

            Label {
                id: nameLabel
                anchors {
                    left: parent.left
                    right: valueLabel.left
                    rightMargin: 8
                }
                text: root.title
                elide: Text.ElideRight
                color: root.titleColor
            }

            Label {
                id: valueLabel
                anchors.right: parent.right
                visible: text !== ""
                text: root.valueText
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Slider {
            width: parent.width
            active: root.active
            value: root.value
            onMoved: value => root.moved(value)
        }
    }

    Item {
        id: trailingSlot
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: root.reserveTrailing ? 30 : 0
        height: 30
    }
}
