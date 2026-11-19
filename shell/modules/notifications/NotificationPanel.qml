import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Notification history under the bell next to the clock. It grows with its content up to the height of
// the screen, then scrolls.
BarPanel {
    name: "notifications"
    side: "center"

    content: Component {
        Item {
            implicitHeight: header.height + (Notifications.count > 0 ? 10 + list.implicitHeight : 80)

            Item {
                id: header

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
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
                    topMargin: 10
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
                            onActivated: Panels.close("notifications")
                        }
                    }
                }

                Rectangle {
                    parent: flick
                    anchors.right: parent.right
                    y: flick.visibleArea.yPosition * flick.height
                    width: 3
                    height: flick.visibleArea.heightRatio * flick.height
                    radius: Theme.radiusTiny
                    color: Theme.dim
                    visible: flick.contentHeight > flick.height
                }
            }
        }
    }
}
