import QtQuick
import qs.config

// Read-only usage bar. Its color warns at high values, or at low values when reversed.
Rectangle {
    id: root

    property real value: 0
    property bool reversed: false
    // Transparent means the color is picked automatically.
    property color fillColor: "transparent"
    readonly property color autoColor: {
        const v = reversed ? 1 - value : value;
        return v >= 0.9 ? Theme.error : v >= 0.75 ? Theme.warning : Theme.accent;
    }

    implicitHeight: 4
    radius: height / 2
    color: Theme.surface

    Rectangle {
        width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
        height: parent.height
        radius: parent.radius
        color: root.fillColor.a > 0 ? root.fillColor : root.autoColor
        visible: root.value > 0

        Behavior on width {
            NumberAnimation {
                duration: Theme.animPanel
                easing.type: Easing.OutCubic
            }
        }
    }
}
