import QtQuick
import qs.config

// Bar item: icon, optional text, hover background and tooltip.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color contentColor: Theme.foreground
    property string tooltip: ""
    property bool interactive: true

    signal clicked()
    signal scrolled(int direction)

    implicitWidth: content.implicitWidth + 12
    implicitHeight: Theme.barHeight - 6
    radius: Theme.radius
    color: mouse.containsMouse && interactive ? Theme.surface : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.contentColor
            visible: text !== ""
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.contentColor
            visible: text !== ""
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.interactive) root.clicked()
        onWheel: wheel => root.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }

    Tooltip {
        target: root
        text: root.tooltip
        hovered: mouse.containsMouse
    }
}
