import QtQuick
import qs.config
import qs.components

// Icon, name, value, usage bar and optional details below.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string valueText: ""
    property real value: 0
    property bool reversed: false
    property color fillColor: "transparent"
    property string detail: ""

    implicitHeight: Math.max(40, column.implicitHeight + 8)

    Icon {
        id: statIcon
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: 30
        text: root.icon
    }

    Column {
        id: column
        anchors {
            left: statIcon.right
            right: parent.right
            leftMargin: 8
            rightMargin: 34
            verticalCenter: parent.verticalCenter
        }
        spacing: 3

        Item {
            width: parent.width
            height: titleLabel.implicitHeight

            Label {
                id: titleLabel
                text: root.title
            }

            Label {
                anchors.right: parent.right
                text: root.valueText
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
                font.features: { "tnum": 1 }
            }
        }

        Meter {
            id: meter
            width: parent.width
            value: root.value
            reversed: root.reversed
            fillColor: root.fillColor
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: root.detail
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            topPadding: 1
        }
    }
}
