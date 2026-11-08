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
            subtitle: Network.busySsid !== "" ? "Łączenie…"
                : !Network.hardwareEnabled ? "Zablokowane"
                : !Network.wifiEnabled ? "Wyłączone"
                : Network.connected ? Network.ssid : "Brak połączenia"
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
            subtitle: !Bluetooth.hasAdapter ? "Brak adaptera"
                : Bluetooth.blocked ? "Zablokowany"
                : !Bluetooth.enabled ? "Wyłączony"
                : Bluetooth.connectedDevices.length === 1 ? Bluetooth.connectedDevices[0].name
                : Bluetooth.connectedDevices.length > 1 ? `Połączono: ${Bluetooth.connectedDevices.length}`
                : "Włączony"
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
            text: "ZASILANIE"
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
                tooltip: "Zablokuj"
                onClicked: Session.runById("lock")
            }

            IconButton {
                icon: Icons.power
                iconColor: Theme.muted
                tooltip: "Zablokuj, uśpij, wyłącz"
                onClicked: Panels.actionCenterPage = "power"
            }
        }
    }

    SegmentedControl {
        width: parent.width
        currentValue: Power.profile
        options: [
            { value: PowerProfile.PowerSaver, label: "Oszczędny", icon: Icons.powerSaver },
            { value: PowerProfile.Balanced, label: "Zrównoważony", icon: Icons.balanced },
            { value: PowerProfile.Performance, label: "Wydajny", icon: Icons.performance, enabled: Power.hasPerformance }
        ]
        onSelected: value => Power.setProfile(value)
    }

    Item {
        width: parent.width
        height: 6
    }

    SectionTitle {
        text: "DŹWIĘK"
    }

    VolumeRow {
        width: parent.width
        node: Audio.sink
        emptyTitle: "Brak wyjścia dźwięku"
        showChevron: true
        onChevronClicked: Panels.actionCenterPage = "audio"
    }

    VolumeRow {
        width: parent.width
        node: Audio.source
        emptyTitle: "Brak mikrofonu"
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
        text: "PODŚWIETLENIE"
    }

    LevelRow {
        width: parent.width
        visible: Brightness.display.available
        icon: Icons.brightness
        title: "Ekran"
        value: Brightness.display.level
        onMoved: value => Brightness.display.setLevel(value)
    }

    LevelRow {
        width: parent.width
        visible: Brightness.keyboard.available
        icon: Icons.keyboard
        title: "Klawiatura"
        value: Brightness.keyboard.level
        onMoved: value => Brightness.keyboard.setLevel(value)
    }

    ListRow {
        width: parent.width
        text: Displays.monitors.length > 1 ? `Monitory (${Displays.monitors.length})` : "Monitory"
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
            text: Notifications.count > 0 ? `POWIADOMIENIA (${Notifications.count})` : "POWIADOMIENIA"
        }

        Row {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Nie przeszkadzać"
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
                tooltip: "Wyczyść wszystkie"
                onClicked: Notifications.clearAll()
            }
        }
    }

    Label {
        visible: Notifications.count === 0
        text: "Brak powiadomień"
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
