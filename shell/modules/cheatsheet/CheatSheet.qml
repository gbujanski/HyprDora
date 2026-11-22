import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The keyboard shortcuts over the whole screen, their groups in columns, as SUPER + / brings them up. The
// same key, Esc or a click closes it.
Scope {
    id: root

    readonly property bool open: Panels.isOpen("cheatsheet")
    // The screen it opened on, kept while it fades out.
    property var screen: null

    onOpenChanged: {
        if (open) {
            screen = Panels.currentScreen;
            Shortcuts.refresh();
        } else {
            closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: root.open || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && root.open

            Component.onCompleted: entered = true

            screen: root.screen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-cheatsheet"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Rectangle {
                id: backdrop

                anchors.fill: parent
                color: Theme.background
                opacity: window.shown ? 0.94 : 0
                focus: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animPanel
                    }
                }

                Keys.onEscapePressed: Panels.close("cheatsheet")

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: Panels.close("cheatsheet")
                }
            }

            // As many columns as the screen holds, each group added to the shortest so far, in order.
            Row {
                id: columns

                readonly property int columnWidth: 360
                readonly property int count: Math.max(1, Math.min(Shortcuts.groups.length, Math.floor((window.width - 96 + spacing) / (columnWidth + spacing))))
                readonly property var split: {
                    const result = Array.from({
                        length: count
                    }, () => []);
                    const heights = result.map(() => 0);
                    for (const group of Shortcuts.groups) {
                        const shortest = heights.indexOf(Math.min(...heights));
                        result[shortest].push(group);
                        heights[shortest] += group.rows.length + 2;
                    }
                    return result;
                }

                anchors.centerIn: parent
                spacing: 32
                opacity: backdrop.opacity / 0.94

                Repeater {
                    model: columns.split

                    Column {
                        required property var modelData

                        width: columns.columnWidth
                        spacing: 20

                        Repeater {
                            model: parent.modelData

                            Column {
                                id: group

                                required property var modelData

                                width: columns.columnWidth

                                SectionTitle {
                                    text: group.modelData.title
                                    bottomPadding: 6
                                }

                                Repeater {
                                    model: group.modelData.rows

                                    Item {
                                        required property var modelData

                                        width: columns.columnWidth
                                        height: 26

                                        Label {
                                            anchors {
                                                left: parent.left
                                                right: keys.left
                                                rightMargin: 12
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: parent.modelData.description
                                            elide: Text.ElideRight
                                        }

                                        Label {
                                            id: keys
                                            anchors {
                                                right: parent.right
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: parent.modelData.keys
                                            color: Theme.accent
                                            font.weight: Font.Medium
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
