import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// System restore: the snapshots taken before changes, newest first. A click asks for confirmation, then the
// helper replaces the system and restarts. Esc, the close button or a click outside closes the window.
Scope {
    LazyLoader {
        active: SystemRestore.windowOpen

        PanelWindow {
            id: window

            // The snapshot waiting for confirmation, or null.
            property var chosen: null

            /** Closes the window unless a restore is under way. */
            function close() {
                if (SystemRestore.busy !== "restore")
                    SystemRestore.windowOpen = false;
            }

            screen: Panels.focusedScreen()
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: Qt.rgba(0, 0, 0, 0.45)
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-system-restore"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            MouseArea {
                anchors.fill: parent
                onClicked: window.close()
            }

            Rectangle {
                id: panel

                anchors.centerIn: parent
                width: Math.min(620, parent.width - 2 * Theme.panelMargin)
                height: Math.min(parent.height * 0.75, header.height + list.contentHeight + confirm.height + 48)
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                focus: true

                Keys.onEscapePressed: window.chosen ? window.chosen = null : window.close()

                // Absorbs clicks so they do not reach the closing area.
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: header

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 30

                        Title {
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.t("restore.title")
                        }

                        IconButton {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            icon: Icons.close
                            iconColor: Theme.muted
                            onClicked: window.close()
                        }
                    }

                    Label {
                        width: parent.width
                        bottomPadding: 6
                        text: SystemRestore.snapshots.length > 0 ? I18n.t("restore.instruction") : I18n.t("restore.empty")
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }
                }

                ListView {
                    id: list

                    anchors {
                        top: header.bottom
                        bottom: confirm.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding - 4
                        topMargin: 4
                    }
                    clip: true
                    spacing: 2
                    boundsBehavior: Flickable.StopAtBounds
                    model: SystemRestore.snapshots

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        readonly property bool chosen: window.chosen?.number === modelData.number

                        width: list.width
                        height: 52
                        radius: Theme.radius
                        color: chosen || rowArea.containsMouse ? Theme.surface : "transparent"

                        Column {
                            anchors {
                                left: parent.left
                                right: parent.right
                                leftMargin: 10
                                rightMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 2

                            Label {
                                width: parent.width
                                text: row.modelData.description
                                elide: Text.ElideRight
                                font.weight: row.chosen ? Font.Medium : Font.Normal
                            }

                            Item {
                                width: parent.width
                                height: kindLabel.implicitHeight

                                Label {
                                    id: kindLabel
                                    anchors {
                                        left: parent.left
                                        right: dateLabel.left
                                        rightMargin: 12
                                    }
                                    text: row.modelData.kind
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }

                                Label {
                                    id: dateLabel
                                    anchors.right: parent.right
                                    text: row.modelData.date.toLocaleString(I18n.locale, Locale.ShortFormat)
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeSmall
                                }
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: SystemRestore.busy === ""
                            onClicked: window.chosen = row.modelData
                        }
                    }
                }

                // The confirmation, under the list so the list stays in place.
                Rectangle {
                    id: confirm

                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                    visible: window.chosen !== null
                    height: visible ? confirmLayout.implicitHeight + 24 : 0
                    radius: Theme.radius
                    color: Theme.surface

                    Column {
                        id: confirmLayout

                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: 12
                        }
                        spacing: 6

                        Label {
                            width: parent.width
                            text: I18n.t("restore.confirmTitle", {
                                date: window.chosen?.date.toLocaleString(I18n.locale, Locale.ShortFormat) ?? ""
                            })
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            width: parent.width
                            bottomPadding: 6
                            text: I18n.t("restore.confirmBody")
                            color: Theme.muted
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: 6

                            Spinner {
                                anchors.verticalCenter: parent.verticalCenter
                                running: SystemRestore.busy === "restore"
                            }

                            ConfirmButton {
                                text: I18n.t("common.cancel")
                                selected: true
                                onClicked: window.chosen = null
                            }

                            ConfirmButton {
                                text: I18n.t("restore.confirmButton")
                                danger: true
                                onClicked: {
                                    if (window.chosen)
                                        SystemRestore.restore(window.chosen.number);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
