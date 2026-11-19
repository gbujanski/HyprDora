import QtQuick
import qs.config
import qs.components
import qs.services

// One Wi-Fi network: a click connects to it. A saved one can be marked metered and forgotten, the connected
// one disconnected.
ItemRow {
    id: root

    required property var network
    readonly property bool busy: Network.busySsid === network.name
    readonly property bool hasError: Network.errorSsid === network.name
    readonly property bool metered: Network.isMetered(network)

    icon: Icons.wifi(network.signalStrength)
    title: network.name
    highlighted: network.connected
    interactive: !network.connected
    subtitleColor: hasError ? Theme.error : Theme.muted
    subtitle: {
        if (busy)
            return I18n.t("status.connecting");
        const suffix = metered ? ` · ${I18n.t("wifi.meteredShort")}` : "";
        if (network.connected)
            return I18n.t("wifi.connectedWith", {
                security: Network.securityLabel(network)
            }) + suffix;
        if (network.known)
            return I18n.t("wifi.savedWith", {
                security: Network.securityLabel(network)
            }) + suffix;
        return Network.securityLabel(network);
    }
    onClicked: Network.activate(network)

    trailing: [
        // Metered: nothing downloads in the background on this network.
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.network.known && Network.savedMetered[root.network.name] !== undefined
            icon: Icons.metered
            iconColor: root.metered ? Theme.accent : Theme.dim
            tooltip: I18n.t(root.metered ? "wifi.meteredOn" : "wifi.meteredOff")
            onClicked: Network.setMetered(root.network, !root.metered)
        },
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.network.connected
            icon: Icons.close
            iconColor: Theme.muted
            tooltip: I18n.t("wifi.disconnect")
            onClicked: Network.disconnectActive()
        },
        DeleteButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.network.known
            label: I18n.t("wifi.forget")
            onConfirmed: Network.forget(root.network)
        },
        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: Network.needsPassword(root.network) && !root.network.known
            rightPadding: 6
            text: Icons.lock
            color: Theme.dim
            font.pixelSize: Theme.iconSizeSmall
        }
    ]
}
