import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Pytanie o zachowanie zmian. Osobne okno na każdym ekranie, bo panel może właśnie
// tracić swój monitor, a potwierdzenie musi być widoczne na tym, który działa.
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
                        text: "Zachować te ustawienia ekranu?"
                        font.pixelSize: Theme.fontSizeTitle
                        font.weight: Font.DemiBold
                    }

                    Label {
                        text: `Automatyczny powrót za ${Displays.secondsLeft} s`
                        color: Theme.muted
                        bottomPadding: 8
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 6

                        TextButton {
                            text: "Cofnij (Esc)"
                            onClicked: Displays.revertChange()
                        }

                        TextButton {
                            text: "Zachowaj (Enter)"
                            primary: true
                            onClicked: Displays.keepChange()
                        }
                    }
                }
            }
        }
    }
}
