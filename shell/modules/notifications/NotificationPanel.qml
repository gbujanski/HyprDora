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

                Title {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifications.count > 0 ? `${I18n.t("notifications.title")} (${Notifications.count})` : I18n.t("notifications.title")
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

            ScrollArea {
                id: flick

                anchors {
                    top: header.bottom
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 10
                }
                contentHeight: list.implicitHeight

                Column {
                    id: list

                    width: flick.usableWidth
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
            }
        }
    }
}
