import QtQuick
import qs.config
import qs.components
import qs.services

// The wired connection: its state, address and link speed; a click connects, the cross disconnects, the
// meter marks it metered. Under it, the connection's IP settings.
Column {
    spacing: 6

    Component.onCompleted: Wired.refresh()

    // The details change with the state, such as the address once connected.
    Connections {
        target: Wired
        function onStateChanged() {
            Wired.refresh();
        }
    }

    ErrorBanner {
        width: parent.width
        text: Wired.error
    }

    ItemRow {
        width: parent.width
        icon: Icons.ethernet
        title: Wired.name || I18n.t("network.wired")
        subtitle: {
            if (Wired.connecting)
                return I18n.t("status.connecting");
            if (!Wired.cable)
                return I18n.t("wired.noCable");
            if (!Wired.connected)
                return I18n.t("wired.disconnected");
            const parts = [I18n.t("wired.connected")];
            if (Wired.speed > 0)
                parts.push(Wired.speed >= 1000 ? `${Wired.speed / 1000} Gb/s` : `${Wired.speed} Mb/s`);
            if (Wired.metered === "yes")
                parts.push(I18n.t("wifi.meteredShort"));
            return parts.join(" · ");
        }
        highlighted: Wired.connected
        interactive: Wired.cable && !Wired.connected && !Wired.connecting
        onClicked: Wired.setConnected(true)

        details: Column {
            visible: Wired.connected

            Repeater {
                model: [[I18n.t("wired.address"), Wired.address], [I18n.t("wired.gateway"), Wired.gateway], ["DNS", Wired.dns]].filter(r => r[1] !== "")

                Label {
                    required property var modelData
                    text: `${modelData[0]}: ${modelData[1]}`
                    color: Theme.muted
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        trailing: [
            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                running: Wired.connecting
                visible: Wired.connecting
            },
            // Metered: nothing downloads in the background on this connection.
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wired.uuid !== ""
                icon: Icons.metered
                iconColor: Wired.metered === "yes" ? Theme.accent : Theme.dim
                tooltip: I18n.t(Wired.metered === "yes" ? "wifi.meteredOn" : "wifi.meteredOff")
                onClicked: Wired.setMetered(Wired.metered !== "yes")
            },
            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wired.connected
                icon: Icons.close
                iconColor: Theme.muted
                tooltip: I18n.t("wired.disconnect")
                onClicked: Wired.setConnected(false)
            }
        ]
    }

    SectionTitle {
        visible: Wired.uuid !== ""
        topPadding: 6
        text: I18n.t("section.ipSettings")
    }

    // Made again for another connection, so the form starts from its settings.
    Repeater {
        model: Wired.uuid !== "" ? [Wired.uuid] : []

        IpSettings {
            required property string modelData
            width: parent.width
            uuid: modelData
            active: Wired.connected
            // The address and DNS above follow.
            onSaved: Wired.refresh()
        }
    }
}
