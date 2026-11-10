import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Selection overlay for screenshots and recording, one window per screen.
Variants {
    model: Capture.overlayOpen ? Quickshell.screens : []

    PanelWindow {
        id: window

        required property ShellScreen modelData

        readonly property bool hasToolbar: modelData === Capture.overlayScreen
        readonly property var target: Capture.targetFor(modelData)

        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "hyprdora-capture"
        WlrLayershell.keyboardFocus: hasToolbar ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            focus: window.hasToolbar

            Keys.onEscapePressed: Capture.close()
            Keys.onReturnPressed: Capture.capture()
            Keys.onEnterPressed: Capture.capture()

            Rectangle {
                width: parent.width
                height: window.target ? window.target.y : parent.height
                color: Theme.captureDim
            }

            Rectangle {
                visible: window.target !== null
                y: window.target ? window.target.y + window.target.height : 0
                width: parent.width
                height: parent.height - y
                color: Theme.captureDim
            }

            Rectangle {
                visible: window.target !== null
                y: window.target?.y ?? 0
                width: window.target?.x ?? 0
                height: window.target?.height ?? 0
                color: Theme.captureDim
            }

            Rectangle {
                visible: window.target !== null
                x: window.target ? window.target.x + window.target.width : 0
                y: window.target?.y ?? 0
                width: parent.width - x
                height: window.target?.height ?? 0
                color: Theme.captureDim
            }

            Rectangle {
                visible: window.target !== null
                x: window.target?.x ?? 0
                y: window.target?.y ?? 0
                width: window.target?.width ?? 0
                height: window.target?.height ?? 0
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
            }

            MouseArea {
                id: pointer

                property point origin
                property var moved: null
                readonly property bool isArea: Capture.mode === "area"

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: isArea ? Qt.CrossCursor : Qt.PointingHandCursor

                onPressed: mouse => {
                    origin = Qt.point(mouse.x, mouse.y);
                    const t = window.target;
                    const inside = isArea && t && mouse.x >= t.x && mouse.x < t.x + t.width && mouse.y >= t.y && mouse.y < t.y + t.height;
                    moved = inside ? t : null;
                }
                onPositionChanged: mouse => {
                    if (!pressed) {
                        Capture.hoverAt(window.modelData, mouse.x, mouse.y);
                    } else if (isArea && moved) {
                        const x = Math.max(0, Math.min(window.modelData.width - moved.width, moved.x + mouse.x - origin.x));
                        const y = Math.max(0, Math.min(window.modelData.height - moved.height, moved.y + mouse.y - origin.y));
                        Capture.setArea(window.modelData, x, y, moved.width, moved.height);
                    } else if (isArea) {
                        Capture.setArea(window.modelData, origin.x, origin.y, mouse.x - origin.x, mouse.y - origin.y);
                    }
                }
                onClicked: {
                    if (!isArea)
                        Capture.capture();
                }
            }

            Label {
                anchors.centerIn: parent
                visible: window.hasToolbar && Capture.mode === "area" && Capture.area === null
                text: I18n.t("capture.hint")
                font.pixelSize: Theme.fontSizeTitle
            }

            Rectangle {
                anchors {
                    bottom: parent.bottom
                    bottomMargin: 40
                    horizontalCenter: parent.horizontalCenter
                }
                visible: window.hasToolbar
                width: toolbar.implicitWidth + 16
                height: toolbar.implicitHeight + 16
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surfaceHover

                // Absorbs clicks so they do not reach the selection below.
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                }

                Row {
                    id: toolbar

                    anchors.centerIn: parent
                    spacing: 8

                    SegmentedControl {
                        width: 360
                        anchors.verticalCenter: parent.verticalCenter
                        currentValue: Capture.mode
                        options: [
                            {
                                value: "area",
                                label: I18n.t("capture.area"),
                                icon: Icons.captureArea
                            },
                            {
                                value: "screen",
                                label: I18n.t("capture.screen"),
                                icon: Icons.captureScreen
                            },
                            {
                                value: "window",
                                label: I18n.t("capture.window"),
                                icon: Icons.captureWindow
                            }
                        ]
                        onSelected: value => Capture.mode = value
                    }

                    SegmentedControl {
                        width: 240
                        anchors.verticalCenter: parent.verticalCenter
                        currentValue: Capture.kind
                        options: [
                            {
                                value: "screenshot",
                                label: I18n.t("capture.screenshot"),
                                icon: Icons.camera
                            },
                            {
                                value: "record",
                                label: I18n.t("capture.record"),
                                icon: Icons.video
                            }
                        ]
                        onSelected: value => Capture.kind = value
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Capture.kind === "record"
                        icon: Icons.volume(Settings.captureSystemAudio ? 1 : 0, !Settings.captureSystemAudio)
                        iconColor: Settings.captureSystemAudio ? Theme.accent : Theme.muted
                        tooltip: I18n.t(Settings.captureSystemAudio ? "capture.systemAudioOn" : "capture.systemAudioOff")
                        onClicked: Settings.setIn("capture", "systemAudio", !Settings.captureSystemAudio)
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Capture.kind === "record"
                        icon: Icons.microphone(!Settings.captureMicrophone)
                        iconColor: Settings.captureMicrophone ? Theme.accent : Theme.muted
                        tooltip: I18n.t(Settings.captureMicrophone ? "capture.microphoneOn" : "capture.microphoneOff")
                        onClicked: Settings.setIn("capture", "microphone", !Settings.captureMicrophone)
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Capture.kind === "record" ? Icons.video : Icons.camera
                        iconColor: !Capture.canCapture ? Theme.dim : Capture.kind === "record" ? Theme.error : Theme.accent
                        active: Capture.canCapture
                        tooltip: I18n.t(Capture.kind === "record" ? "capture.startRecording" : "capture.take")
                        onClicked: Capture.capture()
                    }

                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Icons.close
                        iconColor: Theme.muted
                        tooltip: I18n.t("common.cancel")
                        onClicked: Capture.close()
                    }
                }
            }
        }
    }
}
