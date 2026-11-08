import QtQuick
import qs.config
import qs.components
import qs.services

Rectangle {
    id: root

    required property var device

    // Pierwsze kliknięcie kosza uzbraja, drugie usuwa parowanie.
    property bool forgetArmed: false

    implicitHeight: 44
    radius: Theme.radius
    color: device.connected || area.containsMouse ? Theme.surface : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Bluetooth.activate(root.device)
    }

    Icon {
        id: deviceIcon
        anchors {
            left: parent.left
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
        text: Icons.bluetoothDevice(root.device.icon)
        color: root.device.connected ? Theme.accent : Theme.foreground
    }

    Column {
        anchors {
            left: deviceIcon.right
            right: forgetButton.visible ? forgetButton.left : parent.right
            leftMargin: 10
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            text: root.device.name
            elide: Text.ElideRight
            font.weight: root.device.connected ? Font.Medium : Font.Normal
        }

        Label {
            width: parent.width
            text: Bluetooth.statusText(root.device)
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }

    IconButton {
        id: forgetButton
        anchors {
            right: parent.right
            rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        visible: root.device.paired
        icon: Icons.trash
        iconColor: root.forgetArmed ? Theme.error : Theme.muted
        tooltip: root.forgetArmed ? "Kliknij ponownie, aby zapomnieć urządzenie" : "Zapomnij urządzenie"
        onClicked: {
            if (root.forgetArmed) {
                root.forgetArmed = false;
                Bluetooth.forget(root.device);
            } else {
                root.forgetArmed = true;
                disarm.restart();
            }
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.forgetArmed = false
    }
}
