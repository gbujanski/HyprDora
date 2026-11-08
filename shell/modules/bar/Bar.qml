import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

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
    WlrLayershell.namespace: "gui-demo-bar"

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

        WeatherButton {
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.modelData
        }

        Clock {
            anchors.verticalCenter: parent.verticalCenter
            screen: bar.modelData
        }
    }

    Row {
        anchors {
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.spacing

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
