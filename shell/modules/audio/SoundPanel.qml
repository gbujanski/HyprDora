import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The sound controls under the bar's sound icon, the same as in the action center. Like the other panels, a
// click outside or Esc closes it, and a closed window does not exist.
Scope {
    Connections {
        target: Panels
        function onSoundOpenChanged() {
            if (!Panels.soundOpen)
                closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.soundOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.soundOpen

            Component.onCompleted: entered = true

            screen: Panels.soundScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-sound"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeSound()
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

                Keys.onEscapePressed: Panels.closeSound()

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

                SoundControls {
                    id: content
                    expanded: true

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                }
            }
        }
    }
}
