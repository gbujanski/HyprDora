import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

Scope {
    // Przy otwartym centrum akcji te same powiadomienia są widoczne na liście.
    LazyLoader {
        active: Notifications.popups.length > 0 && !Panels.actionCenterOpen

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
            WlrLayershell.namespace: "gui-demo-notifications"
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

                        Behavior on opacity { NumberAnimation { duration: Theme.animPanel } }

                        Timer {
                            id: lifetime
                            interval: Notifications.popupTimeout(card.modelData)
                            running: interval > 0 && !card.hovered
                            onTriggered: Notifications.endPopup(card.modelData)
                        }

                        // Podmiana treści (replaces_id) wydłuża życie toastu.
                        Connections {
                            target: card.modelData
                            function onSummaryChanged() { lifetime.restart(); }
                            function onBodyChanged() { lifetime.restart(); }
                        }
                    }
                }
            }
        }
    }
}
