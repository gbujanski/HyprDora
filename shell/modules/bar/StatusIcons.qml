import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

Row {
    id: root

    required property ShellScreen screen

    /**
     * Tells whether a panel is open under this bar, so the icon that opened it lights up.
     * @param {string} name  panel name
     * @returns {bool}
     */
    function opened(name) {
        return Panels.isOpen(name) && Panels.currentScreen === screen;
    }

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
        contentColor: root.opened("vpn") ? Theme.accent : Theme.foreground
        tooltip: Vpn.statusTooltip
        onClicked: Panels.toggle("vpn", root.screen)
    }

    // While a removable drive is plugged in: the drives, each with a button that removes it safely.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Drives.drives.length > 0
        icon: Icons.usbDrive
        contentColor: root.opened("drives") ? Theme.accent : Theme.foreground
        tooltip: I18n.t("drives.tooltip")
        onClicked: Panels.toggle("drives", root.screen)
    }

    // While an external screen is connected: its settings, the same as in the settings menu.
    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Displays.hasExternal
        icon: Icons.monitor
        contentColor: root.opened("displays") ? Theme.accent : Theme.foreground
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

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        visible: Bluetooth.enabled
        icon: Bluetooth.statusIcon
        contentColor: root.opened("bluetooth") ? Theme.accent : Bluetooth.connectedDevices.length > 0 ? Theme.foreground : Theme.muted
        tooltip: Bluetooth.statusTooltip
        onClicked: Panels.toggle("bluetooth", root.screen)
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Network.statusIcon
        contentColor: root.opened("wifi") ? Theme.accent : Network.connected ? Theme.foreground : Theme.muted
        tooltip: Network.statusTooltip
        onClicked: Panels.toggle("wifi", root.screen)
    }

    BarButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Icons.volume(Audio.volume, Audio.muted)
        label: `${Math.round(Audio.volume * 100)}%`
        contentColor: root.opened("sound") ? Theme.accent : Audio.muted ? Theme.muted : Theme.foreground
        tooltip: Audio.displayName(Audio.sink)
        onClicked: Panels.toggle("sound", root.screen)
        onScrolled: direction => {
            Audio.changeVolume(direction * 0.05);
            Indicator.show("volume");
        }
    }

    // The power profile, when not balanced, and the battery, as one button: both open the battery panel,
    // which holds the profiles, so they light up together.
    BarButton {
        id: powerButton

        readonly property bool profileShown: Power.profile !== PowerProfile.Balanced
        readonly property string batteryTooltip: !Power.hasBattery ? "" : Power.full ? I18n.t("battery.full") : Power.secondsLeft <= 0 ? "" : Power.charging ? I18n.t("battery.timeToFull", {
            time: Power.formatTime(Power.secondsLeft)
        }) : I18n.t("battery.timeLeft", {
            time: Power.formatTime(Power.secondsLeft)
        })

        anchors.verticalCenter: parent.verticalCenter
        visible: profileShown || Power.hasBattery
        icon: !profileShown ? "" : Power.profile === PowerProfile.Performance ? Icons.performance : Icons.powerSaver
        contentColor: root.opened("battery") ? Theme.accent : Power.profile === PowerProfile.Performance ? Theme.warning : Theme.accent
        tooltip: [!profileShown ? "" : Power.profile === PowerProfile.Performance ? I18n.t("power.profilePerformanceTooltip") : I18n.t("power.profileSaverTooltip"), batteryTooltip].filter(Boolean).join("\n")
        onClicked: Panels.toggle("battery", root.screen)

        // A bolt while on power; color only when low on battery, at the same levels as the warnings.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: Power.hasBattery
            spacing: 5

            readonly property color batteryColor: root.opened("battery") ? Theme.accent : !UPower.onBattery ? Theme.foreground : Power.level <= Settings.batteryCritical ? Theme.error : Power.level <= Settings.batteryLow ? Theme.warning : Theme.foreground

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.battery(Power.level, !UPower.onBattery)
                color: parent.batteryColor
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(Power.level * 100)}%`
                color: parent.batteryColor
            }
        }
    }

    // HyprDora's mark opens the action center, green while it is open.
    BarButton {
        id: actionCenterButton
        anchors.verticalCenter: parent.verticalCenter
        contentColor: root.opened("actioncenter") ? Theme.accent : Theme.foreground
        tooltip: I18n.t("actionCenter.title")
        onClicked: Panels.toggleActionCenter(root.screen, "main")

        LogoMark {
            anchors.verticalCenter: parent.verticalCenter
            color: actionCenterButton.contentColor
        }
    }
}
