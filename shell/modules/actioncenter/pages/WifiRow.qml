import QtQuick
import qs.config
import qs.components
import qs.services

Rectangle {
    id: root

    required property var network

    readonly property bool busy: Network.busySsid === network.name
    readonly property bool hasError: Network.errorSsid === network.name
    readonly property bool metered: Network.isMetered(network)

    // The first click arms the button, the second forgets the network and its saved password.
    property bool forgetArmed: false

    implicitHeight: 44
    radius: Theme.radius
    color: network.connected || area.containsMouse ? Theme.surface : "transparent"

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

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
                if (root.busy)
                    return I18n.t("status.connecting");
                const suffix = root.metered ? ` · ${I18n.t("wifi.meteredShort")}` : "";
                if (root.network.connected)
                    return I18n.t("wifi.connectedWith", {
                        security: Network.securityLabel(root.network)
                    }) + suffix;
                if (root.network.known)
                    return I18n.t("wifi.savedWith", {
                        security: Network.securityLabel(root.network)
                    }) + suffix;
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

        // Metered: nothing downloads in the background on this network.
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.network.known && Network.savedMetered[root.network.name] !== undefined
            icon: Icons.metered
            iconColor: root.metered ? Theme.accent : Theme.dim
            tooltip: I18n.t(root.metered ? "wifi.meteredOn" : "wifi.meteredOff")
            onClicked: Network.setMetered(root.network, !root.metered)
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.network.connected
            icon: Icons.close
            iconColor: Theme.muted
            tooltip: I18n.t("wifi.disconnect")
            onClicked: Network.disconnectActive()
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.network.known
            icon: Icons.trash
            iconColor: root.forgetArmed ? Theme.error : Theme.muted
            tooltip: root.forgetArmed ? I18n.t("wifi.forgetArmed") : I18n.t("wifi.forget")
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
            font.pixelSize: Theme.iconSizeSmall
        }
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.forgetArmed = false
    }
}
