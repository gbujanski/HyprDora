import QtQuick
import qs.config

// Wiersz z bieżącą wartością, który rozwija listę opcji: [{ value, label }].
Column {
    id: root

    property string title: ""
    property var options: []
    property var currentValue
    property bool expanded: false

    signal selected(var value)

    readonly property var currentOption: options.find(o => o.value === currentValue) ?? null

    spacing: 2

    Rectangle {
        width: parent.width
        height: 34
        radius: Theme.radius
        color: headerArea.containsMouse ? Theme.surfaceHover : "transparent"

        Label {
            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: root.title
            color: Theme.muted
        }

        Row {
            anchors {
                right: parent.right
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            spacing: 4

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentOption?.label ?? "Brak"
                font.weight: Font.Medium
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: root.expanded ? Icons.chevronUp : Icons.chevronDown
                color: Theme.muted
                visible: root.options.length > 1
            }
        }

        MouseArea {
            id: headerArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.options.length > 1
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Repeater {
        model: root.expanded ? root.options : []

        ListRow {
            required property var modelData
            width: root.width
            text: modelData.label
            selected: modelData.value === root.currentValue
            onClicked: {
                root.expanded = false;
                root.selected(modelData.value);
            }
        }
    }
}
