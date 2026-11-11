import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Quick settings: toggles, sliders and shortcuts. Notifications and the media player have their own panels
// next to the clock, and display settings live in the settings menu.
Column {
    spacing: 6

    Grid {
        id: tiles

        width: parent.width
        columns: 2
        spacing: 6

        readonly property real tileWidth: (width - spacing) / 2

        Tile {
            width: tiles.tileWidth
            icon: Network.connected ? Icons.wifi(Network.signal) : Icons.wifiOff
            title: "Wi-Fi"
            subtitle: Network.busySsid !== "" ? I18n.t("status.connecting") : !Network.hardwareEnabled ? I18n.t("wifi.tile.blocked") : !Network.wifiEnabled ? I18n.t("wifi.tile.off") : Network.connected ? Network.ssid : I18n.t("wifi.notConnected")
            active: Network.wifiEnabled
            enabledTile: Network.hardwareEnabled
            onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
            onOpened: Panels.actionCenterPage = "wifi"
        }

        Tile {
            width: tiles.tileWidth
            icon: !Bluetooth.enabled ? Icons.bluetoothOff : Bluetooth.connectedDevices.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth
            title: "Bluetooth"
            subtitle: !Bluetooth.hasAdapter ? I18n.t("bluetooth.noAdapter") : Bluetooth.blocked ? I18n.t("bluetooth.tile.blocked") : !Bluetooth.enabled ? I18n.t("bluetooth.tile.off") : Bluetooth.connectedDevices.length === 1 ? Bluetooth.connectedDevices[0].name : Bluetooth.connectedDevices.length > 1 ? I18n.t("bluetooth.tile.connectedCount", {
                count: Bluetooth.connectedDevices.length
            }) : I18n.t("bluetooth.tile.on")
            active: Bluetooth.enabled
            enabledTile: Bluetooth.hasAdapter && !Bluetooth.blocked
            onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
            onOpened: Panels.actionCenterPage = "bluetooth"
        }
    }

    SegmentedControl {
        width: parent.width
        currentValue: Power.profile
        options: [
            {
                value: PowerProfile.PowerSaver,
                label: I18n.t("power.saver"),
                icon: Icons.powerSaver
            },
            {
                value: PowerProfile.Balanced,
                label: I18n.t("power.balanced"),
                icon: Icons.balanced
            },
            {
                value: PowerProfile.Performance,
                label: I18n.t("power.performance"),
                icon: Icons.performance,
                enabled: Power.hasPerformance
            }
        ]
        onSelected: value => Power.setProfile(value)
    }

    Item {
        width: parent.width
        height: 2
    }

    AudioSection {
        width: parent.width
    }

    AudioSection {
        width: parent.width
        isMicrophone: true
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

    Item {
        width: parent.width
        height: 4
    }

    SystemCard {
        width: parent.width
    }

    Item {
        width: parent.width
        height: 30

        Row {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            IconButton {
                icon: Icons.camera
                iconColor: Theme.muted
                tooltip: I18n.t("capture.title")
                onClicked: Capture.open()
            }

            IconButton {
                id: settingsButton
                icon: Icons.settings
                iconColor: Panels.settingsMenuOpen ? Theme.accent : Theme.muted
                tooltip: I18n.t("settings.title")
                Component.onCompleted: Panels.settingsButton = settingsButton
                onClicked: Panels.settingsMenuOpen = !Panels.settingsMenuOpen
            }
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
}
