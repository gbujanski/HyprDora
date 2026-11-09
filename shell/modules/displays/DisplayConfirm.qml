import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// One window per screen: the panel's monitor may be going away, and the prompt must be visible on one that works.
Scope {
    Variants {
        model: Displays.pending ? Quickshell.screens : []

        PanelWindow {
            id: window

            required property ShellScreen modelData

            screen: modelData
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 380
            implicitHeight: 136
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-display-confirm"
            WlrLayershell.keyboardFocus: modelData === Panels.focusedScreen() ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.accent
                focus: true

                Keys.onReturnPressed: Displays.keepChange()
                Keys.onEnterPressed: Displays.keepChange()
                Keys.onEscapePressed: Displays.revertChange()

                Column {
                    anchors {
                        fill: parent
                        margins: 16
                    }
                    spacing: 6

                    Label {
                        text: I18n.t("displays.confirmTitle")
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text: I18n.t("displays.revertIn", {
                            seconds: Displays.secondsLeft
                        })
                        color: Theme.muted
                        bottomPadding: 8
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 6

                        TextButton {
                            text: I18n.t("displays.revert")
                            onClicked: Displays.revertChange()
                        }

                        TextButton {
                            text: I18n.t("displays.keep")
                            primary: true
                            onClicked: Displays.keepChange()
                        }
                    }
                }
            }
        }
    }
}
