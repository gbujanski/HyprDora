import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

Row {
    id: root

    required property ShellScreen screen

    spacing: 0

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Power.profile !== PowerProfile.Balanced
        icon: Power.profile === PowerProfile.Performance ? Icons.performance : Icons.powerSaver
        contentColor: Power.profile === PowerProfile.Performance ? Theme.warning : Theme.accent
        tooltip: Power.profile === PowerProfile.Performance ? "Profil: wydajność" : "Profil: oszczędzanie energii"
        onClicked: Panels.toggleActionCenter(root.screen, "main")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Bluetooth.enabled
        icon: Bluetooth.connectedDevices.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth
        contentColor: Bluetooth.connectedDevices.length > 0 ? Theme.foreground : Theme.muted
        tooltip: Bluetooth.connectedDevices.length > 0
            ? Bluetooth.connectedDevices.map(d => d.name).join(", ")
            : "Bluetooth włączony"
        onClicked: Panels.toggleActionCenter(root.screen, "bluetooth")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Network.connected ? Icons.wifi(Network.signal) : Icons.wifiOff
        contentColor: Network.connected ? Theme.foreground : Theme.muted
        tooltip: Network.busySsid !== "" ? `Łączenie: ${Network.busySsid}`
            : Network.connected ? `${Network.ssid} (${Math.round(Network.signal * 100)}%)`
            : Network.wifiEnabled ? "Brak połączenia" : "Wi-Fi wyłączone"
        onClicked: Panels.toggleActionCenter(root.screen, "wifi")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.volume(Audio.volume, Audio.muted)
        label: `${Math.round(Audio.volume * 100)}%`
        contentColor: Audio.muted ? Theme.muted : Theme.foreground
        tooltip: Audio.sink?.description ?? ""
        onClicked: Panels.toggleActionCenter(root.screen, "audio")
        onScrolled: direction => Audio.changeVolume(direction * 0.05)
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Power.hasBattery
        icon: Icons.battery(Power.level, Power.charging)
        label: `${Math.round(Power.level * 100)}%`
        contentColor: Power.charging || Power.full ? Theme.accent
            : Power.level <= 0.15 ? Theme.error
            : Power.level <= 0.30 ? Theme.warning
            : Theme.foreground
        tooltip: Power.full ? "Naładowana"
            : Power.secondsLeft <= 0 ? ""
            : Power.charging ? `Do naładowania: ${Power.formatTime(Power.secondsLeft)}`
            : `Pozostało: ${Power.formatTime(Power.secondsLeft)}`
        onClicked: Panels.toggleActionCenter(root.screen, "main")
    }

    // Centrum akcji i licznik powiadomień.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Notifications.dnd ? Icons.bellOff : Notifications.count > 0 ? Icons.bellBadge : Icons.bell
        label: Notifications.count > 0 ? String(Notifications.count) : ""
        contentColor: Panels.actionCenterOpen || Notifications.count > 0 ? Theme.accent : Theme.foreground
        tooltip: Notifications.dnd ? "Nie przeszkadzać" : Notifications.count > 0 ? `Powiadomienia: ${Notifications.count}` : "Centrum akcji"
        onClicked: Panels.toggleActionCenter(root.screen, "main")
    }
}
