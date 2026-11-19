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

    // Security updates show at once, others after a week; a click lists them, with the install buttons.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Updates.notify
        icon: Icons.update
        label: String(Updates.count)
        contentColor: Updates.securityCount > 0 ? Theme.warning : Theme.accent
        tooltip: Updates.securityCount > 0 ? I18n.t("updates.tooltipSecurity", {
            count: Updates.securityCount
        }) : I18n.t("updates.tooltip", {
            count: Updates.count
        })
        onClicked: Panels.toggle("updates", root.screen)
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
        icon: Vpn.statusIcon
        tooltip: Vpn.statusTooltip
        onClicked: Panels.toggleActionCenter(root.screen, "vpn")
    }

    // While a removable drive is plugged in: the drives, each with a button that removes it safely.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Drives.drives.length > 0
        icon: Icons.usbDrive
        contentColor: Panels.isOpen("drives") ? Theme.accent : Theme.foreground
        tooltip: I18n.t("drives.tooltip")
        onClicked: Panels.toggle("drives", root.screen)
    }

    // While an external screen is connected: its settings, the same as in the settings menu.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Displays.hasExternal
        icon: Icons.monitor
        contentColor: Panels.isOpen("displays") ? Theme.accent : Theme.foreground
        tooltip: I18n.t("settings.displays")
        onClicked: Panels.toggle("displays", root.screen)
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Network.wiredConnected
        interactive: false
        icon: Icons.ethernet
        tooltip: I18n.t("network.wired")
    }

    // A profile other than balanced; the battery panel, which holds the profiles, opens from it.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Power.profile !== PowerProfile.Balanced
        icon: Power.profile === PowerProfile.Performance ? Icons.performance : Icons.powerSaver
        contentColor: Power.profile === PowerProfile.Performance ? Theme.warning : Theme.accent
        tooltip: Power.profile === PowerProfile.Performance ? I18n.t("power.profilePerformanceTooltip") : I18n.t("power.profileSaverTooltip")
        onClicked: Panels.toggle("battery", root.screen)
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Bluetooth.enabled
        icon: Bluetooth.statusIcon
        contentColor: Bluetooth.connectedDevices.length > 0 ? Theme.foreground : Theme.muted
        tooltip: Bluetooth.statusTooltip
        onClicked: Panels.toggleActionCenter(root.screen, "bluetooth")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Network.statusIcon
        contentColor: Network.connected ? Theme.foreground : Theme.muted
        tooltip: Network.statusTooltip
        onClicked: Panels.toggleActionCenter(root.screen, "wifi")
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.volume(Audio.volume, Audio.muted)
        label: `${Math.round(Audio.volume * 100)}%`
        contentColor: Audio.muted ? Theme.muted : Theme.foreground
        tooltip: Audio.displayName(Audio.sink)
        onClicked: Panels.toggle("sound", root.screen)
        onScrolled: direction => {
            Audio.changeVolume(direction * 0.05);
            Indicator.show("volume");
        }
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
        onClicked: Panels.toggle("battery", root.screen)
    }

    // HyprDora's mark opens the action center, green while it is open.
    BarButton {
        id: actionCenterButton
        anchors.verticalCenter: parent.verticalCenter
        contentColor: Panels.isOpen("actioncenter") ? Theme.accent : Theme.foreground
        tooltip: I18n.t("actionCenter.title")
        onClicked: Panels.toggleActionCenter(root.screen, "main")

        LogoMark {
            anchors.verticalCenter: parent.verticalCenter
            color: actionCenterButton.contentColor
        }
    }
}
