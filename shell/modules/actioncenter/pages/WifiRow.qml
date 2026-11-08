import QtQuick
import qs.config
import qs.components
import qs.services

Rectangle {
    id: root

    required property var network

    readonly property bool busy: Network.busySsid === network.name
    readonly property bool hasError: Network.errorSsid === network.name

    // Pierwsze kliknięcie kosza uzbraja, drugie usuwa: zapomnienie kasuje zapisane hasło.
    property bool forgetArmed: false

    implicitHeight: 44
    radius: Theme.radius
    color: network.connected || area.containsMouse ? Theme.surface : "transparent"

    Behavior on color { ColorAnimation { duration: Theme.animFast } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.network.connected ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: Network.activate(root.network)
    }

    Icon {
        id: signalIcon
        anchors {
            left: parent.left
            leftMargin: 10
            verticalCenter: parent.verticalCenter
        }
        text: Icons.wifi(root.network.signalStrength)
        color: root.network.connected ? Theme.accent : Theme.foreground
    }

    Column {
        anchors {
            left: signalIcon.right
            right: actions.left
            leftMargin: 10
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            text: root.network.name
            elide: Text.ElideRight
            font.weight: root.network.connected ? Font.Medium : Font.Normal
        }

        Label {
            width: parent.width
            elide: Text.ElideRight
            color: root.hasError ? Theme.error : Theme.muted
            font.pixelSize: Theme.fontSizeSmall
            text: {
                if (root.busy) return "Łączenie…";
                if (root.network.connected) return `Połączono, ${Network.securityLabel(root.network)}`;
                if (root.network.known) return `Zapisana, ${Network.securityLabel(root.network)}`;
                return Network.securityLabel(root.network);
            }
        }
    }

    Row {
        id: actions
        anchors {
            right: parent.right
            rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.network.connected
            icon: Icons.close
            iconColor: Theme.muted
            tooltip: "Rozłącz"
            onClicked: Network.disconnectActive()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.network.known
            icon: Icons.trash
            iconColor: root.forgetArmed ? Theme.error : Theme.muted
            tooltip: root.forgetArmed ? "Kliknij ponownie, aby zapomnieć sieć" : "Zapomnij sieć"
            onClicked: {
                if (root.forgetArmed) {
                    root.forgetArmed = false;
                    Network.forget(root.network);
                } else {
                    root.forgetArmed = true;
                    disarm.restart();
                }
            }
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Network.needsPassword(root.network) && !root.network.known
            rightPadding: 6
            text: Icons.lock
            color: Theme.dim
            font.pixelSize: 14
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.forgetArmed = false
    }
}
