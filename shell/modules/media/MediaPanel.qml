import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Player controls under the media button next to the clock. Like the other panels, a click outside or Esc
// closes it, and a closed window does not exist.
Scope {
    Connections {
        target: Panels
        function onMediaOpenChanged() {
            if (!Panels.mediaOpen)
                closeDelay.restart();
        }
    }

    // The panel has nothing to show once the last player is gone.
    Connections {
        target: Media
        function onHasPlayerChanged() {
            if (!Media.hasPlayer)
                Panels.closeMedia();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.mediaOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.mediaOpen

            Component.onCompleted: entered = true

            screen: Panels.mediaScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-media"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeMedia()
            }

            Rectangle {
                id: panel

                anchors {
                    top: parent.top
                    topMargin: Theme.panelMargin
                    horizontalCenter: parent.horizontalCenter
                }
                width: Theme.panelWidth
                height: card.implicitHeight + Theme.panelPadding * 2
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: window.shown ? 1 : 0
                focus: true

                Keys.onEscapePressed: Panels.closeMedia()

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

                MediaCard {
                    id: card
                    anchors {
                        fill: parent
                        margins: Theme.panelPadding
                    }
                }
            }
        }
    }
}
