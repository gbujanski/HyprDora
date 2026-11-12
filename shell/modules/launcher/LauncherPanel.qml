import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Application launcher and clipboard history: a search field over a list, near the top of the screen.
// Typing filters, arrows move, Enter runs the selected row; Esc or a click outside closes it.
Scope {
    id: root

    Connections {
        target: Panels
        function onLauncherOpenChanged() {
            if (!Panels.launcherOpen)
                closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.launcherOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.launcherOpen
            readonly property bool clipboardMode: Panels.launcherMode === "clipboard"
            readonly property var rows: clipboardMode ? Launcher.searchClipboard(search.text) : Launcher.search(search.text)

            /**
             * Runs a row and closes the launcher.
             * @param {object} row  result row
             */
            function activate(row) {
                if (!row)
                    return;
                Launcher.activate(row);
                Panels.closeLauncher();
            }

            Component.onCompleted: {
                entered = true;
                if (clipboardMode)
                    Launcher.refreshClipboard();
                search.forceActiveFocus();
            }

            screen: Panels.launcherScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-launcher"
            // Typing must reach the search field at once.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            onClipboardModeChanged: {
                search.text = "";
                if (clipboardMode)
                    Launcher.refreshClipboard();
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeLauncher()
            }

            Rectangle {
                id: panel

                readonly property int rowHeight: 48
                readonly property int visibleRows: 8

                anchors {
                    top: parent.top
                    topMargin: Math.round(parent.height * 0.18)
                    horizontalCenter: parent.horizontalCenter
                }
                width: Math.min(620, parent.width - 2 * Theme.panelMargin)
                height: field.height + (list.count > 0 ? Math.min(list.count, visibleRows) * rowHeight + 16 : empty.implicitHeight + 24) + 12
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: window.shown ? 1 : 0

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

                Item {
                    id: field

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: 6
                    }
                    height: 52

                    Icon {
                        id: searchIcon
                        anchors {
                            left: parent.left
                            leftMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        text: window.clipboardMode ? Icons.clipboard : Icons.search
                        color: Theme.muted
                        font.pixelSize: 20
                    }

                    TextInput {
                        id: search

                        anchors {
                            left: searchIcon.right
                            right: parent.right
                            leftMargin: 12
                            rightMargin: 14
                            verticalCenter: parent.verticalCenter
                        }
                        color: Theme.foreground
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        clip: true

                        onTextChanged: list.currentIndex = 0

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: window.clipboardMode ? I18n.t("launcher.clipboardPlaceholder") : I18n.t("launcher.placeholder")
                            color: Theme.dim
                            font.pixelSize: 18
                        }

                        Keys.onPressed: event => {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                Panels.closeLauncher();
                                break;
                            case Qt.Key_Down:
                            case Qt.Key_Tab:
                                list.currentIndex = Math.min(list.count - 1, list.currentIndex + 1);
                                break;
                            case Qt.Key_Up:
                            case Qt.Key_Backtab:
                                list.currentIndex = Math.max(0, list.currentIndex - 1);
                                break;
                            case Qt.Key_PageDown:
                                list.currentIndex = Math.min(list.count - 1, list.currentIndex + panel.visibleRows);
                                break;
                            case Qt.Key_PageUp:
                                list.currentIndex = Math.max(0, list.currentIndex - panel.visibleRows);
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                window.activate(window.rows[list.currentIndex]);
                                break;
                            case Qt.Key_Delete:
                                // Shift+Delete removes the selected clipboard entry from the history.
                                if (!(window.clipboardMode && event.modifiers & Qt.ShiftModifier))
                                    return;
                                if (window.rows[list.currentIndex])
                                    Launcher.forget(window.rows[list.currentIndex].clip);
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }
                    }
                }

                Rectangle {
                    anchors {
                        top: field.bottom
                        left: parent.left
                        right: parent.right
                    }
                    height: 1
                    color: Theme.surface
                }

                Label {
                    id: empty
                    anchors {
                        top: field.bottom
                        topMargin: 18
                        horizontalCenter: parent.horizontalCenter
                    }
                    visible: list.count === 0
                    text: window.clipboardMode ? I18n.t("launcher.clipboardEmpty") : I18n.t("launcher.empty")
                    color: Theme.muted
                }

                ListView {
                    id: list

                    anchors {
                        top: field.bottom
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: 8
                    }
                    clip: true
                    model: window.rows
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 0
                    currentIndex: 0

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem

                        width: list.width
                        height: panel.rowHeight
                        radius: Theme.radius
                        color: current ? Theme.surface : rowArea.containsMouse ? Theme.surfaceHover : "transparent"

                        Item {
                            id: rowIcon
                            anchors {
                                left: parent.left
                                leftMargin: 10
                                verticalCenter: parent.verticalCenter
                            }
                            width: 32
                            height: 32

                            IconImage {
                                anchors.fill: parent
                                visible: row.modelData.kind === "app"
                                source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable") : ""
                                asynchronous: true
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: row.modelData.kind !== "app"
                                text: ({
                                        calc: Icons.calculator,
                                        command: Icons.shellCommand,
                                        web: Icons.web,
                                        clip: Icons.clipboard
                                    })[row.modelData.kind] ?? ""
                                color: row.current ? Theme.accent : Theme.muted
                                font.pixelSize: 22
                            }
                        }

                        Column {
                            anchors {
                                left: rowIcon.right
                                right: parent.right
                                leftMargin: 12
                                rightMargin: 12
                                verticalCenter: parent.verticalCenter
                            }
                            spacing: 1

                            Label {
                                width: parent.width
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.weight: row.current ? Font.Medium : Font.Normal
                                text: {
                                    const r = row.modelData;
                                    switch (r.kind) {
                                    case "app":
                                        return r.entry.name;
                                    case "calc":
                                        return `= ${Launcher.formatNumber(r.value)}`;
                                    case "command":
                                        return r.command;
                                    case "web":
                                        return r.query;
                                    case "clip":
                                        return r.clip.text.replace(/\s+/g, " ");
                                    }
                                    return "";
                                }
                            }

                            Label {
                                width: parent.width
                                visible: text !== ""
                                elide: Text.ElideRight
                                color: Theme.muted
                                font.pixelSize: Theme.fontSizeSmall
                                text: {
                                    const r = row.modelData;
                                    switch (r.kind) {
                                    case "app":
                                        return r.entry.genericName || r.entry.comment || "";
                                    case "calc":
                                        return I18n.t("launcher.copyResult");
                                    case "command":
                                        return I18n.t("launcher.runCommand");
                                    case "web":
                                        return I18n.t("launcher.searchWeb");
                                    }
                                    return "";
                                }
                            }
                        }

                        MouseArea {
                            id: rowArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.activate(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
