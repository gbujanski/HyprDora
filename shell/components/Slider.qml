import QtQuick
import qs.config

Item {
    id: root

    property real value: 0
    property real step: 0.05
    property bool active: true

    signal moved(real value)

    readonly property real shownValue: area.pressed ? dragValue : Math.max(0, Math.min(1, value))
    property real dragValue: 0

    function emitValue(newValue) {
        if (active) moved(Math.max(0, Math.min(1, newValue)));
    }

    function valueAt(x) {
        return Math.max(0, Math.min(1, (x - knob.width / 2) / (width - knob.width)));
    }

    implicitWidth: 200
    implicitHeight: 22
    activeFocusOnTab: true

    Keys.onLeftPressed: emitValue(value - step)
    Keys.onRightPressed: emitValue(value + step)

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Theme.surface

        Rectangle {
            height: parent.height
            width: knob.x + knob.width / 2
            radius: parent.radius
            color: root.active ? Theme.accent : Theme.dim
        }
    }

    Rectangle {
        id: knob
        anchors.verticalCenter: parent.verticalCenter
        x: root.shownValue * (root.width - width)
        width: 14
        height: 14
        radius: 7
        color: root.active ? Theme.foreground : Theme.muted
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.accent
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.active
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => {
            root.dragValue = root.valueAt(mouse.x);
            root.emitValue(root.dragValue);
        }
        onPositionChanged: mouse => {
            root.dragValue = root.valueAt(mouse.x);
            root.emitValue(root.dragValue);
        }
        onWheel: wheel => root.emitValue(root.value + (wheel.angleDelta.y > 0 ? root.step : -root.step))
    }
}
