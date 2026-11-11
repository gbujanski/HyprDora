import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Notification history under the bell next to the clock. It grows with its content up to the height of
// the screen. Like the other panels, a click outside or Esc closes it, and a closed window does not exist.
Scope {
    id: root

    Connections {
        target: Panels
        function onNotificationsOpenChanged() {
            if (!Panels.notificationsOpen)
                closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.notificationsOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.notificationsOpen

            Component.onCompleted: entered = true

            screen: Panels.notificationsScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-notifications-panel"
            // OnDemand for the same reason as the action center: Exclusive would block the bar.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeNotifications()
            }

            Rectangle {
                id: panel

                anchors {
                    top: parent.top
                    topMargin: Theme.panelMargin
                    horizontalCenter: parent.horizontalCenter
                }
                width: Theme.panelWidth
                height: Math.min(header.height + (Notifications.count > 0 ? list.implicitHeight + 10 : 80) + Theme.panelPadding * 2, window.height - Theme.panelMargin * 2)
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: window.shown ? 1 : 0
                focus: true

                Keys.onEscapePressed: Panels.closeNotifications()

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

                Item {
                    id: header

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                    height: 30

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifications.count > 0 ? `${I18n.t("notifications.title")} (${Notifications.count})` : I18n.t("notifications.title")
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: Font.DemiBold
                    }

                    Row {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 8

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("notifications.dnd")
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
                            tooltip: I18n.t("notifications.clearAll")
                            onClicked: Notifications.clearAll()
                        }
                    }
                }

                Label {
                    anchors {
                        top: header.bottom
                        topMargin: 26
                        horizontalCenter: parent.horizontalCenter
                    }
                    visible: Notifications.count === 0
                    text: I18n.t("notifications.empty")
                    color: Theme.muted
                }

                Flickable {
                    id: flick

                    anchors {
                        top: header.bottom
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.panelPadding
                        rightMargin: Theme.panelPadding
                        topMargin: 10
                        bottomMargin: Theme.panelPadding
                    }
                    contentWidth: width
                    contentHeight: list.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: list

                        width: flick.width - (flick.contentHeight > flick.height ? 8 : 0)
                        spacing: 6

                        Repeater {
                            model: ScriptModel {
                                values: Notifications.history
                            }

                            NotificationCard {
                                required property var modelData
                                width: list.width
                                notification: modelData
                                onActivated: Panels.closeNotifications()
                            }
                        }
                    }

                    Rectangle {
                        parent: flick
                        anchors.right: parent.right
                        y: flick.visibleArea.yPosition * flick.height
                        width: 3
                        height: flick.visibleArea.heightRatio * flick.height
                        radius: 2
                        color: Theme.dim
                        visible: flick.contentHeight > flick.height
                    }
                }
            }
        }
    }
}
