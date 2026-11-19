import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

Scope {
    // The same notifications are listed in the action center while it is open.
    LazyLoader {
        active: Notifications.popups.length > 0 && !Panels.isOpen("actioncenter")

        PanelWindow {
            screen: Panels.focusedScreen()
            anchors {
                top: true
                right: true
            }
            margins {
                top: Theme.panelMargin
                right: Theme.panelMargin
            }
            exclusionMode: ExclusionMode.Normal
            implicitWidth: Theme.panelWidth
            implicitHeight: Math.max(1, column.implicitHeight)
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-notifications"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Column {
                id: column
                width: parent.width
                spacing: 6

                Repeater {
                    model: ScriptModel {
                        values: Notifications.popups
                    }

                    NotificationCard {
                        id: card

                        required property var modelData

                        width: column.width
                        notification: modelData
                        floating: true
                        opacity: 0
                        Component.onCompleted: opacity = 1
                        onActivated: Notifications.endPopup(modelData)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animPanel
                            }
                        }

                        Timer {
                            id: lifetime
                            interval: Notifications.popupTimeout(card.modelData)
                            running: interval > 0 && !card.hovered
                            onTriggered: Notifications.endPopup(card.modelData)
                        }

                        // Replacing the content (replaces_id) extends the toast's lifetime.
                        Connections {
                            target: card.modelData
                            function onSummaryChanged() {
                                lifetime.restart();
                            }
                            function onBodyChanged() {
                                lifetime.restart();
                            }
                        }
                    }
                }
            }
        }
    }
}
