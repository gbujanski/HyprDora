import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

Column {
    spacing: 6

    Row {
        width: parent.width
        spacing: 6

        Tile {
            width: (parent.width - parent.spacing) / 2
            icon: Network.connected ? Icons.wifi(Network.signal) : Icons.wifiOff
            title: "Wi-Fi"
            subtitle: Network.busySsid !== "" ? I18n.t("status.connecting")
                : !Network.hardwareEnabled ? I18n.t("wifi.tile.blocked")
                : !Network.wifiEnabled ? I18n.t("wifi.tile.off")
                : Network.connected ? Network.ssid : I18n.t("wifi.notConnected")
            active: Network.wifiEnabled
            enabledTile: Network.hardwareEnabled
            onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
            onOpened: Panels.actionCenterPage = "wifi"
        }

        Tile {
            width: (parent.width - parent.spacing) / 2
            icon: !Bluetooth.enabled ? Icons.bluetoothOff
                : Bluetooth.connectedDevices.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth
            title: "Bluetooth"
            subtitle: !Bluetooth.hasAdapter ? I18n.t("bluetooth.noAdapter")
                : Bluetooth.blocked ? I18n.t("bluetooth.tile.blocked")
                : !Bluetooth.enabled ? I18n.t("bluetooth.tile.off")
                : Bluetooth.connectedDevices.length === 1 ? Bluetooth.connectedDevices[0].name
                : Bluetooth.connectedDevices.length > 1 ? I18n.t("bluetooth.tile.connectedCount", { count: Bluetooth.connectedDevices.length })
                : I18n.t("bluetooth.tile.on")
            active: Bluetooth.enabled
            enabledTile: Bluetooth.hasAdapter && !Bluetooth.blocked
            onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
            onOpened: Panels.actionCenterPage = "bluetooth"
        }
    }

    Item {
        width: parent.width
        height: 6
    }

    MediaCard {
        width: parent.width
        visible: Media.hasPlayer
    }

    Item {
        width: parent.width
        height: 6
        visible: Media.hasPlayer
    }

    Item {
        width: parent.width
        height: 30

        SectionTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t("section.power")
        }

        Row {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            IconButton {
                icon: Icons.lock
                iconColor: Theme.muted
                tooltip: I18n.t("session.lock")
                onClicked: Session.runById("lock")
            }

            IconButton {
                icon: Icons.power
                iconColor: Theme.muted
                tooltip: I18n.t("power.pageTooltip")
                onClicked: Panels.actionCenterPage = "power"
            }
        }
    }

    SegmentedControl {
        width: parent.width
        currentValue: Power.profile
        options: [
            { value: PowerProfile.PowerSaver, label: I18n.t("power.saver"), icon: Icons.powerSaver },
            { value: PowerProfile.Balanced, label: I18n.t("power.balanced"), icon: Icons.balanced },
            { value: PowerProfile.Performance, label: I18n.t("power.performance"), icon: Icons.performance, enabled: Power.hasPerformance }
        ]
        onSelected: value => Power.setProfile(value)
    }

    Item {
        width: parent.width
        height: 6
    }

    SectionTitle {
        text: I18n.t("section.audio")
    }

    VolumeRow {
        width: parent.width
        node: Audio.sink
        emptyTitle: I18n.t("audio.noOutput")
        showChevron: true
        onChevronClicked: Panels.actionCenterPage = "audio"
    }

    VolumeRow {
        width: parent.width
        node: Audio.source
        emptyTitle: I18n.t("audio.noMicrophone")
        isMicrophone: true
        showChevron: true
        onChevronClicked: Panels.actionCenterPage = "audio"
    }

    Item {
        width: parent.width
        height: 6
        visible: Brightness.display.available || Brightness.keyboard.available
    }

    SectionTitle {
        visible: Brightness.display.available || Brightness.keyboard.available
        text: I18n.t("section.backlight")
    }

    LevelRow {
        width: parent.width
        visible: Brightness.display.available
        icon: Icons.brightness
        title: I18n.t("backlight.screen")
        value: Brightness.display.level
        onMoved: value => Brightness.display.setLevel(value)
    }

    LevelRow {
        width: parent.width
        visible: Brightness.keyboard.available
        icon: Icons.keyboard
        title: I18n.t("backlight.keyboard")
        value: Brightness.keyboard.level
        onMoved: value => Brightness.keyboard.setLevel(value)
    }

    ListRow {
        width: parent.width
        text: Displays.monitors.length > 1 ? I18n.t("displays.buttonWithCount", { count: Displays.monitors.length }) : I18n.t("page.displays")
        trailingIcon: Icons.chevronRight
        onClicked: Panels.actionCenterPage = "displays"
    }

    Item {
        width: parent.width
        height: 6
    }

    SystemCard {
        width: parent.width
    }

    Item {
        width: parent.width
        height: 6
    }

    Item {
        width: parent.width
        height: 26

        SectionTitle {
            anchors.verticalCenter: parent.verticalCenter
            text: Notifications.count > 0 ? I18n.t("section.notificationsWithCount", { count: Notifications.count }) : I18n.t("section.notifications")
        }

        Row {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.t("notifications.dnd")
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }

            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Notifications.dnd
                onToggled: Notifications.dnd = !Notifications.dnd
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifications.count > 0
                icon: Icons.trash
                iconColor: Theme.muted
                tooltip: I18n.t("notifications.clearAll")
                onClicked: Notifications.clearAll()
            }
        }
    }

    Label {
        visible: Notifications.count === 0
        text: I18n.t("notifications.empty")
        color: Theme.muted
        topPadding: 2
        bottomPadding: 4
    }

    Repeater {
        model: ScriptModel {
            values: Notifications.history
        }

        NotificationCard {
            required property var modelData
            width: parent.width
            notification: modelData
            onActivated: Panels.closeActionCenter()
        }
    }
}
