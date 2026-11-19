import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Removable drives under the bar's drive icon, each with a button that removes it safely. Like the other
// panels, a click outside or Esc closes it, and a closed window does not exist.
Scope {
    // Nothing left to show once the last drive is gone.
    Connections {
        target: Drives
        function onDrivesChanged() {
            if (Drives.drives.length === 0)
                Panels.closeDrives();
        }
    }

    Connections {
        target: Panels
        function onDrivesOpenChanged() {
            if (!Panels.drivesOpen)
                closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.drivesOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.drivesOpen

            Component.onCompleted: entered = true

            screen: Panels.drivesScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-drives"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeDrives()
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

                Keys.onEscapePressed: Panels.closeDrives()

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
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                    spacing: 4

                    Repeater {
                        model: ScriptModel {
                            values: Drives.drives
                            objectProp: "id"
                        }

                        DriveRow {
                            width: content.width
                        }
                    }
                }
            }
        }
    }
}
