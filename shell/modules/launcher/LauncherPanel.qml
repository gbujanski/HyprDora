import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

// Application launcher and clipboard history: a search field over a list, near the top of the screen.
// Typing filters, arrows move, Enter runs the selected row; Esc or a click outside closes it.
BarPanel {
    id: frame

    name: "launcher"
    side: "center"
    topMargin: Math.round((window?.height ?? 0) * 0.18)
    panelWidth: Math.min(620, (window?.width ?? 620) - 2 * Theme.panelMargin)
    padding: 0
    // Typing must reach the search field at once, and the launcher sits over the bar's area too.
    exclusiveKeyboard: true
    belowBar: false

    content: Component {
        Item {
            id: launcher

            readonly property int rowHeight: 48
            readonly property int visibleRows: 8
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
                Panels.close("launcher");
            }

            Component.onCompleted: {
                if (clipboardMode)
                    Launcher.refreshClipboard();
                search.forceActiveFocus();
            }

            implicitHeight: field.height + (list.count > 0 ? Math.min(list.count, visibleRows) * rowHeight + 16 : empty.implicitHeight + 24) + 12

            onClipboardModeChanged: {
                search.text = "";
                if (clipboardMode)
                    Launcher.refreshClipboard();
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
                    text: launcher.clipboardMode ? Icons.clipboard : Icons.search
                    color: Theme.muted
                    font.pixelSize: Theme.iconSizeLarge
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
                    font.pixelSize: Theme.fontSizeLarge
                    clip: true

                    onTextChanged: list.currentIndex = 0

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: launcher.clipboardMode ? I18n.t("launcher.clipboardPlaceholder") : I18n.t("launcher.placeholder")
                        color: Theme.dim
                        font.pixelSize: Theme.fontSizeLarge
                    }

                    Keys.onPressed: event => {
                        switch (event.key) {
                        case Qt.Key_Escape:
                            Panels.close("launcher");
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
                            list.currentIndex = Math.min(list.count - 1, list.currentIndex + launcher.visibleRows);
                            break;
                        case Qt.Key_PageUp:
                            list.currentIndex = Math.max(0, list.currentIndex - launcher.visibleRows);
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            launcher.activate(launcher.rows[list.currentIndex]);
                            break;
                        case Qt.Key_Delete:
                            // Shift+Delete removes the selected clipboard entry from the history.
                            if (!(launcher.clipboardMode && event.modifiers & Qt.ShiftModifier))
                                return;
                            if (launcher.rows[list.currentIndex])
                                Launcher.forget(launcher.rows[list.currentIndex].clip);
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
                text: launcher.clipboardMode ? I18n.t("launcher.clipboardEmpty") : I18n.t("launcher.empty")
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
                model: launcher.rows
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 0
                currentIndex: 0

                delegate: Rectangle {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem

                    width: list.width
                    height: launcher.rowHeight
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
                            font.pixelSize: Theme.iconSizeImage
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
                        onClicked: launcher.activate(row.modelData)
                    }
                }
            }
        }
    }
}
