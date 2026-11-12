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

    // Shown only while updates are waiting; a click installs them in a terminal.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Updates.count > 0
        icon: Icons.update
        label: String(Updates.count)
        contentColor: Theme.accent
        tooltip: I18n.t("updates.tooltip", {
            count: Updates.count
        })
        onClicked: Updates.install()
    }

    // Shown only while coffee is on; a click turns it off.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Idle.paused
        icon: Icons.coffee
        contentColor: Theme.accent
        tooltip: I18n.t("coffee.barTooltip")
        onClicked: Idle.paused = false
    }

    // Privacy indicators: shown only while an application uses the device or captures the screen.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Privacy.microphoneInUse
        interactive: false
        icon: Icons.microphoneOn
        contentColor: Theme.warning
        tooltip: I18n.t("privacy.microphoneApps", {
            apps: Privacy.microphoneApps.join(", ")
        })
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Privacy.cameraInUse
        interactive: false
        icon: Icons.webcam
        contentColor: Theme.warning
        tooltip: I18n.t("privacy.cameraApps", {
            apps: Privacy.cameraApps.join(", ")
        })
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Privacy.screenCaptured
        interactive: false
        icon: Icons.screenShare
        contentColor: Theme.warning
        tooltip: Privacy.screenApps.length > 0 ? I18n.t("privacy.screenApps", {
            apps: Privacy.screenApps.join(", ")
        }) : I18n.t("privacy.screen")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Vpn.connected
        icon: Icons.vpn
        tooltip: I18n.t("vpn.barTooltip", {
            name: Vpn.active?.name ?? ""
        })
        onClicked: Panels.toggleActionCenter(root.screen, "vpn")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Network.wiredConnected
        interactive: false
        icon: Icons.ethernet
        tooltip: I18n.t("network.wired")
    }

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
        // A bolt while on power; color only when low on battery, at the same levels as the warnings.
        icon: Icons.battery(Power.level, !UPower.onBattery)
        label: `${Math.round(Power.level * 100)}%`
        contentColor: !UPower.onBattery ? Theme.foreground : Power.level <= Settings.batteryCritical ? Theme.error : Power.level <= Settings.batteryLow ? Theme.warning : Theme.foreground
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
