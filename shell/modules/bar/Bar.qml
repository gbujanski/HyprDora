import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components

PanelWindow {
    id: bar

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.background
    WlrLayershell.namespace: "hyprdora-bar"

    Workspaces {
        anchors {
            left: parent.left
            leftMargin: 6
            verticalCenter: parent.verticalCenter
        }
        screen: bar.modelData
    }

    Row {
        anchors.centerIn: parent
        spacing: 2

        Clock {
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.modelData
        }

        BarButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Notifications.dnd ? Icons.bellOff : Notifications.count > 0 ? Icons.bellBadge : Icons.bell
            label: Notifications.count > 0 ? String(Notifications.count) : ""
            contentColor: Panels.notificationsOpen || Notifications.count > 0 ? Theme.accent : Theme.foreground
            tooltip: Notifications.dnd ? I18n.t("notifications.dnd") : Notifications.count > 0 ? I18n.t("notifications.count", {
                count: Notifications.count
            }) : I18n.t("notifications.title")
            onClicked: Panels.toggleNotifications(bar.modelData)
        }

        // Shown while something plays or is paused; opens the player controls.
        BarButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: Media.hasPlayer
            icon: Media.player?.isPlaying ? Icons.music : Icons.pause
            label: Media.player?.trackTitle || Media.player?.identity || ""
            labelMaxWidth: 180
            contentColor: Panels.mediaOpen ? Theme.accent : Theme.foreground
            tooltip: [Media.player?.trackArtist, Media.player?.trackTitle].filter(Boolean).join(" – ")
            onClicked: Panels.toggleMedia(bar.modelData)
        }
    }

    Row {
        anchors {
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.spacing

        BarButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: Capture.recording
            icon: Icons.record
            label: Capture.elapsedText
            contentColor: Theme.error
            tooltip: I18n.t("capture.stop")
            onClicked: Capture.stopRecording()
        }

        Tray {
            anchors.verticalCenter: parent.verticalCenter
            barWindow: bar
        }

        StatusIcons {
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.modelData
        }
    }
}
