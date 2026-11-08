import QtQuick
import Quickshell
import qs.config

// Tooltip shown below a bar item after a short hover.
Scope {
    id: root

    required property Item target
    property string text: ""
    property bool hovered: false

    Timer {
        id: delay
        interval: 400
        running: root.hovered && root.text !== ""
        onTriggered: loader.active = true
    }

    Connections {
        target: root
        function onHoveredChanged() {
            if (!root.hovered) loader.active = false;
        }
    }

    LazyLoader {
        id: loader

        PopupWindow {
            anchor.item: root.target
            anchor.edges: Edges.Bottom
            anchor.gravity: Edges.Bottom
            anchor.margins.bottom: -4
            anchor.adjustment: PopupAdjustment.Slide
            visible: true
            color: "transparent"
            implicitWidth: label.implicitWidth + 16
            implicitHeight: label.implicitHeight + 10

            Rectangle {
                anchors.fill: parent
                color: Theme.surface
                radius: Theme.radius

                Label {
                    id: label
                    anchors.centerIn: parent
                    text: root.text
                }
            }
        }
    }
}
