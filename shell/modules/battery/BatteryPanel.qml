import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.config
import qs.components
import qs.services

// Battery state and power profiles under the battery icon, and under the power profile icon. Without a
// battery, as on a desktop, it holds the profiles alone. Like the other panels, a click outside or Esc closes
// it, and a closed window does not exist.
Scope {
    Connections {
        target: Panels
        function onBatteryOpenChanged() {
            if (!Panels.batteryOpen)
                closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.batteryOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.batteryOpen

            Component.onCompleted: entered = true

            screen: Panels.batteryScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-battery"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeBattery()
            }

            Rectangle {
                id: panel

                anchors {
                    top: parent.top
                    right: parent.right
                    margins: Theme.panelMargin
                }
                width: Theme.panelWidth
                height: content.implicitHeight + Theme.panelPadding * 2
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: window.shown ? 1 : 0
                focus: true

                Keys.onEscapePressed: Panels.closeBattery()

                transform: Translate {
                    y: window.shown ? 0 : -12
                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.animPanel
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animPanel
                    }
                }

                // Absorbs clicks so they do not reach the closing area.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                }

                Column {
                    id: content

                    anchors {
                        fill: parent
                        margins: Theme.panelPadding
                    }
                    spacing: 12

                    Row {
                        width: parent.width
                        visible: Power.hasBattery
                        spacing: 12

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.battery(Power.level, !UPower.onBattery)
                            font.pixelSize: 34
                            color: UPower.onBattery && Power.level <= Settings.batteryCritical ? Theme.error : UPower.onBattery && Power.level <= Settings.batteryLow ? Theme.warning : Theme.foreground
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 46
                            spacing: 2

                            Label {
                                text: `${Math.round(Power.level * 100)}%`
                                font.pixelSize: Theme.fontSizeTitle
                                font.weight: Font.DemiBold
                            }

                            Label {
                                width: parent.width
                                text: Power.summary
                                wrapMode: Text.WordWrap
                            }

                            Label {
                                width: parent.width
                                visible: text !== ""
                                text: Power.details
                                color: Theme.muted
                                font.pixelSize: Theme.fontSizeSmall
                                wrapMode: Text.WordWrap
                            }
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
                }
            }
        }
    }
}
