import QtQuick
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// VPN connections: a click connects, the cross disconnects, the bin deletes; files are imported from here.
Column {
    spacing: 6

    ErrorBanner {
        width: parent.width
        text: Vpn.error
    }

    Label {
        visible: Vpn.connections.length === 0
        width: parent.width
        text: I18n.t("vpn.empty")
        color: Theme.muted
        wrapMode: Text.WordWrap
        topPadding: 4
        bottomPadding: 4
    }

    Repeater {
        model: Vpn.connections

        ItemRow {
            id: row

            required property var modelData
            readonly property bool connected: modelData.state === "activated"
            readonly property bool working: modelData.state === "activating" || Vpn.busy === modelData.uuid

            // Interface counters, readable without root, refreshed while the page is open.
            readonly property string statistics: modelData.device !== "" ? `/sys/class/net/${modelData.device}/statistics` : ""

            width: parent.width
            icon: Icons.vpn
            title: modelData.name
            subtitle: (modelData.kind === "wireguard" ? "WireGuard" : "OpenVPN") + " · " + (working ? I18n.t("status.connecting") : connected ? I18n.t("vpn.connected") : I18n.t("vpn.disconnected"))
            highlighted: connected
            interactive: !connected
            onClicked: Vpn.connect(modelData.uuid)

            details: Row {
                visible: row.connected && row.statistics !== ""
                spacing: 4

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.arrowUp
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    text: Vpn.formatBytes(Number(sent.text().trim()) || 0)
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                }

                Item {
                    width: 6
                    height: 1
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.arrowDown
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                }

                Label {
                    text: Vpn.formatBytes(Number(received.text().trim()) || 0)
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            trailing: [
                Spinner {
                    anchors.verticalCenter: parent.verticalCenter
                    running: row.working
                },
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.connected
                    icon: Icons.close
                    iconColor: Theme.muted
                    tooltip: I18n.t("vpn.disconnect")
                    onClicked: Vpn.disconnect(row.modelData.uuid)
                },
                DeleteButton {
                    anchors.verticalCenter: parent.verticalCenter
                    label: I18n.t("vpn.delete")
                    onConfirmed: Vpn.remove(row.modelData.uuid)
                }
            ]

            FileView {
                id: sent
                path: row.connected && row.statistics !== "" ? `${row.statistics}/tx_bytes` : ""
                printErrors: false
            }

            FileView {
                id: received
                path: row.connected && row.statistics !== "" ? `${row.statistics}/rx_bytes` : ""
                printErrors: false
            }

            Timer {
                interval: 2000
                repeat: true
                running: row.connected && row.statistics !== ""
                onTriggered: {
                    sent.reload();
                    received.reload();
                }
            }
        }
    }

    ListRow {
        width: parent.width
        text: I18n.t("vpn.import")
        trailingIcon: Icons.plus
        onClicked: Vpn.chooseFile()
    }
}
