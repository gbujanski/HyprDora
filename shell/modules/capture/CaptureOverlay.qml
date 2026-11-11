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

            // Small squares on the corners and edge centers of the area, where it can be resized.
            Repeater {
                model: Capture.mode === "area" && window.target ? [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [1, 0.5], [0, 1], [0.5, 1], [1, 1]] : []

                Rectangle {
                    required property var modelData
                    x: window.target.x + window.target.width * modelData[0] - width / 2
                    y: window.target.y + window.target.height * modelData[1] - height / 2
                    width: 8
                    height: 8
                    radius: 2
                    color: Theme.accent
                }
            }

            MouseArea {
                id: pointer

                property point origin
                // Area at the start of a drag, and which of its edges the drag moves; all four move it whole.
                property var start: null
                property var edges: null
                property int hoverShape: Qt.CrossCursor
                readonly property bool isArea: Capture.mode === "area"
                // Distance from an edge, on either side, that still grabs it.
                readonly property int grab: 10

                /**
                 * Returns which edges of the area are under the pointer.
                 * @param {real} x  pointer position
                 * @param {real} y  pointer position
                 * @returns {object or null} { left, right, top, bottom }; all true inside the area; null outside it
                 */
                function edgesAt(x, y) {
                    const t = window.target;
                    if (!isArea || !t)
                        return null;
                    const near = (value, edge) => Math.abs(value - edge) <= grab;
                    const withinX = x >= t.x - grab && x <= t.x + t.width + grab;
                    const withinY = y >= t.y - grab && y <= t.y + t.height + grab;
                    const found = {
                        left: withinY && near(x, t.x),
                        right: withinY && near(x, t.x + t.width),
                        top: withinX && near(y, t.y),
                        bottom: withinX && near(y, t.y + t.height)
                    };
                    if (found.left || found.right || found.top || found.bottom)
                        return found;
                    const inside = x >= t.x && x < t.x + t.width && y >= t.y && y < t.y + t.height;
                    return inside ? {
                        left: true,
                        right: true,
                        top: true,
                        bottom: true
                    } : null;
                }

                /**
                 * Returns the cursor for the edges under the pointer.
                 * @param {object} found  result of edgesAt
                 * @returns {int} Qt cursor shape
                 */
                function cursorFor(found) {
                    if (!isArea)
                        return Qt.PointingHandCursor;
                    if (!found)
                        return Qt.CrossCursor;
                    if (found.left && found.right && found.top && found.bottom)
                        return Qt.SizeAllCursor;
                    if ((found.left && found.top) || (found.right && found.bottom))
                        return Qt.SizeFDiagCursor;
                    if ((found.right && found.top) || (found.left && found.bottom))
                        return Qt.SizeBDiagCursor;
                    return found.left || found.right ? Qt.SizeHorCursor : Qt.SizeVerCursor;
                }

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: hoverShape

                onPressed: mouse => {
                    origin = Qt.point(mouse.x, mouse.y);
                    edges = edgesAt(mouse.x, mouse.y);
                    start = edges ? window.target : null;
                }
                onPositionChanged: mouse => {
                    if (!pressed) {
                        Capture.hoverAt(window.modelData, mouse.x, mouse.y);
                        hoverShape = cursorFor(edgesAt(mouse.x, mouse.y));
                        return;
                    }
                    if (!isArea)
                        return;
                    if (!start) {
                        Capture.setArea(window.modelData, origin.x, origin.y, mouse.x - origin.x, mouse.y - origin.y);
                        return;
                    }
                    const dx = mouse.x - origin.x;
                    const dy = mouse.y - origin.y;
                    if (edges.left && edges.right && edges.top && edges.bottom) {
                        const x = Math.max(0, Math.min(window.modelData.width - start.width, start.x + dx));
                        const y = Math.max(0, Math.min(window.modelData.height - start.height, start.y + dy));
                        Capture.setArea(window.modelData, x, y, start.width, start.height);
                        return;
                    }
                    // Dragging an edge past the opposite one flips the area, which setArea handles.
                    const left = start.x + (edges.left ? dx : 0);
                    const right = start.x + start.width + (edges.right ? dx : 0);
                    const top = start.y + (edges.top ? dy : 0);
                    const bottom = start.y + start.height + (edges.bottom ? dy : 0);
                    Capture.setArea(window.modelData, left, top, right - left, bottom - top);
                }
                onReleased: hoverShape = cursorFor(edgesAt(mouseX, mouseY))
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
