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
        tooltip: Power.profile === PowerProfile.Performance ? I18n.t("power.profilePerformanceTooltip") : I18n.t("power.profileSaverTooltip")
        onClicked: Panels.toggleActionCenter(root.screen, "main")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Bluetooth.enabled
        icon: Bluetooth.connectedDevices.length > 0 ? Icons.bluetoothConnected : Icons.bluetooth
        contentColor: Bluetooth.connectedDevices.length > 0 ? Theme.foreground : Theme.muted
        tooltip: Bluetooth.connectedDevices.length > 0 ? Bluetooth.connectedDevices.map(d => d.name).join(", ") : I18n.t("bluetooth.on")
        onClicked: Panels.toggleActionCenter(root.screen, "bluetooth")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Network.connected ? Icons.wifi(Network.signal) : Icons.wifiOff
        contentColor: Network.connected ? Theme.foreground : Theme.muted
        tooltip: Network.busySsid !== "" ? I18n.t("wifi.connectingTo", {
            ssid: Network.busySsid
        }) : Network.connected ? `${Network.ssid} (${Math.round(Network.signal * 100)}%)` : Network.wifiEnabled ? I18n.t("wifi.notConnected") : I18n.t("wifi.off")
        onClicked: Panels.toggleActionCenter(root.screen, "wifi")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.volume(Audio.volume, Audio.muted)
        label: `${Math.round(Audio.volume * 100)}%`
        contentColor: Audio.muted ? Theme.muted : Theme.foreground
        tooltip: Audio.displayName(Audio.sink)
        onClicked: Panels.toggleAudio(root.screen, "output")
        onScrolled: direction => Audio.changeVolume(direction * 0.05)
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Power.hasBattery
        icon: Icons.battery(Power.level, Power.charging)
        label: `${Math.round(Power.level * 100)}%`
        contentColor: Power.charging || Power.full ? Theme.accent : Power.level <= 0.15 ? Theme.error : Power.level <= 0.30 ? Theme.warning : Theme.foreground
        tooltip: Power.full ? I18n.t("battery.full") : Power.secondsLeft <= 0 ? "" : Power.charging ? I18n.t("battery.timeToFull", {
            time: Power.formatTime(Power.secondsLeft)
        }) : I18n.t("battery.timeLeft", {
            time: Power.formatTime(Power.secondsLeft)
        })
        interactive: false
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.tune
        contentColor: Panels.actionCenterOpen ? Theme.accent : Theme.foreground
        tooltip: I18n.t("actionCenter.title")
        onClicked: Panels.toggleActionCenter(root.screen, "main")
    }
}
