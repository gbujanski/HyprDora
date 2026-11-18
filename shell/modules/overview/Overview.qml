import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Overview of windows and workspaces, as Mission Control on a Mac: F3 or three fingers up. The windows of the
// current workspace spread over the screen with live previews; a click or Enter switches to one. Workspaces
// are a strip at the top: a click switches to one, and a window dragged onto one moves there without
// following it. Arrows choose a window, Esc closes.
Scope {
    id: root

    Connections {
        target: Panels
        function onOverviewOpenChanged() {
            if (!Panels.overviewOpen)
                closeDelay.restart();
            else
                Hyprland.refreshToplevels();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.overviewOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.overviewOpen
            readonly property var monitor: Hyprland.monitorFor(screen)
            readonly property int currentWorkspace: monitor?.activeWorkspace?.id ?? 1
            // Windows of the current workspace on this monitor, in the order Hyprland lists them.
            readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace?.id === currentWorkspace && t.wayland)
            property int selected: 0
            // Live previews running now: one per window, and the small copy while one is dragged.
            property int dragCopies: 0
            readonly property int liveCaptures: windows.length + dragCopies

            // The privacy indicator counts these previews out of the screen captures it warns about.
            onLiveCapturesChanged: Privacy.ownWindowCaptures = liveCaptures
            Component.onDestruction: Privacy.ownWindowCaptures = 0
            // The window being dragged, by address, while it is over the workspace strip.
            property string dragging: ""

            // Always 1-5, plus any higher workspace that exists, as on the bar.
            readonly property var workspaceIds: {
                const ids = [1, 2, 3, 4, 5];
                for (const ws of Hyprland.workspaces.values) {
                    if (ws.id > 0 && !ids.includes(ws.id))
                        ids.push(ws.id);
                }
                return ids.sort((a, b) => a - b);
            }

            /**
             * Switches to a window and closes the overview.
             * @param {HyprlandToplevel} toplevel  window
             */
            function activate(toplevel) {
                if (!toplevel)
                    return;
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${toplevel.address}" })`);
                Panels.closeOverview();
            }

            /**
             * Switches to a workspace and closes the overview.
             * @param {int} id  workspace
             */
            function showWorkspace(id) {
                Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
                Panels.closeOverview();
            }

            /**
             * Moves a window to a workspace without following it.
             * @param {string} address  window address, without 0x
             * @param {int} id  workspace
             */
            function moveWindow(address, id) {
                Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${id}, window = "address:0x${address}", follow = false })`);
                Hyprland.refreshToplevels();
            }

            /**
             * An application's icon from its window class.
             * @param {HyprlandToplevel} toplevel  window
             * @returns {string}
             */
            function iconOf(toplevel) {
                const appClass = toplevel?.lastIpcObject?.class ?? toplevel?.wayland?.appId ?? "";
                const entry = DesktopEntries.heuristicLookup(appClass);
                return Quickshell.iconPath(entry?.icon ?? appClass, "application-x-executable");
            }

            Component.onCompleted: {
                entered = true;
                Privacy.ownWindowCaptures = liveCaptures;
            }
            onWindowsChanged: selected = Math.min(selected, Math.max(0, windows.length - 1))

            screen: Panels.overviewScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-overview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Rectangle {
                id: backdrop

                anchors.fill: parent
                color: Theme.background
                opacity: window.shown ? 0.92 : 0
                focus: true

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animPanel
                    }
                }

                Keys.onEscapePressed: Panels.closeOverview()
                Keys.onReturnPressed: window.activate(window.windows[window.selected])
                Keys.onEnterPressed: window.activate(window.windows[window.selected])
                Keys.onPressed: event => {
                    const count = window.windows.length;
                    if (count === 0)
                        return;
                    const columns = grid.columns;
                    let next = window.selected;
                    if (event.key === Qt.Key_Right)
                        next = Math.min(count - 1, next + 1);
                    else if (event.key === Qt.Key_Left)
                        next = Math.max(0, next - 1);
                    else if (event.key === Qt.Key_Down)
                        next = Math.min(count - 1, next + columns);
                    else if (event.key === Qt.Key_Up)
                        next = Math.max(0, next - columns);
                    else
                        return;
                    window.selected = next;
                    event.accepted = true;
                }

                // A click on the empty background closes the overview.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: Panels.closeOverview()
                }
            }

            // Workspaces.
            Row {
                id: strip

                anchors {
                    top: parent.top
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 24
                }
                spacing: 12
                opacity: backdrop.opacity / 0.92

                Repeater {
                    model: window.workspaceIds

                    Rectangle {
                        id: workspaceTile

                        required property int modelData
                        readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === modelData) ?? null
                        readonly property bool current: modelData === window.currentWorkspace
                        readonly property var apps: (workspace?.toplevels.values ?? []).slice(0, 6)

                        width: Math.min(160, (window.width - 48 - strip.spacing * (window.workspaceIds.length - 1)) / window.workspaceIds.length)
                        height: width * 9 / 16
                        radius: Theme.radius
                        color: drop.containsDrag ? Theme.surfaceHover : Theme.surface
                        border.width: current || drop.containsDrag ? 2 : 1
                        border.color: current || drop.containsDrag ? Theme.accent : Theme.surfaceHover

                        Label {
                            anchors {
                                left: parent.left
                                top: parent.top
                                margins: 6
                            }
                            text: workspaceTile.modelData
                            color: workspaceTile.current ? Theme.accent : Theme.muted
                            font.weight: Font.DemiBold
                        }

                        Flow {
                            anchors {
                                fill: parent
                                margins: 8
                                topMargin: 26
                            }
                            spacing: 4

                            Repeater {
                                model: workspaceTile.apps

                                Image {
                                    required property var modelData
                                    width: 24
                                    height: 24
                                    sourceSize.width: 48
                                    sourceSize.height: 48
                                    source: window.iconOf(modelData)
                                    asynchronous: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.showWorkspace(workspaceTile.modelData)
                        }

                        // A window dropped here moves to this workspace.
                        DropArea {
                            id: drop
                            anchors.fill: parent
                            keys: ["hyprdora-window"]
                            onDropped: drag => {
                                if (workspaceTile.modelData !== window.currentWorkspace)
                                    window.moveWindow(drag.source.address, workspaceTile.modelData);
                            }
                        }
                    }
                }
            }

            // The current workspace's windows, in a grid that keeps each window's shape.
            Item {
                id: area

                anchors {
                    top: strip.bottom
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    margins: 40
                }
                opacity: backdrop.opacity / 0.92

                Grid {
                    id: grid

                    readonly property int count: window.windows.length
                    columns: Math.max(1, Math.ceil(Math.sqrt(count * area.width / Math.max(1, area.height) / 1.6)))
                    readonly property int rowCount: Math.max(1, Math.ceil(count / columns))
                    readonly property real cellWidth: (area.width - spacing * (columns - 1)) / columns
                    readonly property real cellHeight: (area.height - spacing * (rowCount - 1)) / rowCount

                    anchors.centerIn: parent
                    spacing: 24

                    Repeater {
                        model: window.windows

                        Item {
                            id: cell

                            required property var modelData
                            required property int index
                            readonly property var size: modelData.lastIpcObject?.size ?? [16, 10]
                            // The window's shape, fitted to the cell below a title line.
                            readonly property real scale: Math.min(grid.cellWidth / Math.max(1, size[0]), (grid.cellHeight - 28) / Math.max(1, size[1]), 1)

                            width: grid.cellWidth
                            height: grid.cellHeight

                            Item {
                                id: tile

                                readonly property bool chosen: window.selected === cell.index || hover.containsMouse

                                width: Math.max(80, cell.size[0] * cell.scale)
                                height: Math.max(50, cell.size[1] * cell.scale) + 28
                                x: (cell.width - width) / 2
                                y: (cell.height - height) / 2
                                // Dimmed while a small copy of it is dragged.
                                opacity: hover.drag.active ? 0.35 : 1

                                Rectangle {
                                    id: frame
                                    anchors {
                                        left: parent.left
                                        right: parent.right
                                        top: parent.top
                                        bottom: titleRow.top
                                        bottomMargin: 6
                                    }
                                    radius: Theme.radius
                                    color: Theme.surface
                                    border.width: tile.chosen ? 2 : 0
                                    border.color: Theme.accent
                                    clip: true

                                    ScreencopyView {
                                        anchors {
                                            fill: parent
                                            margins: tile.chosen ? 2 : 0
                                        }
                                        captureSource: cell.modelData.wayland
                                        live: true
                                    }
                                }

                                Row {
                                    id: titleRow
                                    anchors {
                                        bottom: parent.bottom
                                        horizontalCenter: parent.horizontalCenter
                                    }
                                    width: Math.min(implicitWidth, parent.width)
                                    spacing: 6

                                    Image {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        height: 18
                                        sourceSize.width: 36
                                        sourceSize.height: 36
                                        source: window.iconOf(cell.modelData)
                                        asynchronous: true
                                    }

                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, tile.width - 24)
                                        text: cell.modelData.title
                                        elide: Text.ElideRight
                                        color: tile.chosen ? Theme.foreground : Theme.muted
                                    }
                                }

                                MouseArea {
                                    id: hover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    drag.target: proxy
                                    // The small copy starts centred under the pointer and follows it.
                                    onPressed: mouse => {
                                        const at = mapToItem(window.contentItem, mouse.x, mouse.y);
                                        proxy.x = at.x - proxy.width / 2;
                                        proxy.y = at.y - proxy.height / 2;
                                    }
                                    onClicked: window.activate(cell.modelData)
                                    // Let go anywhere but on a workspace, nothing moves.
                                    onReleased: proxy.Drag.drop()
                                }
                            }

                            // What is dragged: a small live copy of the window, so a workspace is easy to hit; the
                            // pointer itself picks the workspace it is dropped on.
                            Item {
                                id: proxy

                                // Read by a workspace's DropArea.
                                readonly property string address: cell.modelData.address

                                // Starts false, unlike visible, so the count changes only with a real drag.
                                readonly property bool dragged: hover.drag.active

                                parent: window.contentItem
                                visible: dragged
                                onDraggedChanged: window.dragCopies += dragged ? 1 : -1
                                z: 10
                                width: 180
                                height: Math.min(140, width * cell.size[1] / Math.max(1, cell.size[0]))

                                Drag.active: hover.drag.active
                                Drag.keys: ["hyprdora-window"]
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radius
                                    color: Theme.surface
                                    border.width: 2
                                    border.color: Theme.accent
                                    clip: true

                                    ScreencopyView {
                                        anchors {
                                            fill: parent
                                            margins: 2
                                        }
                                        captureSource: proxy.visible ? cell.modelData.wayland : null
                                        live: true
                                    }
                                }
                            }
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: window.windows.length === 0
                    text: I18n.t("overview.empty")
                    color: Theme.muted
                }
            }
        }
    }
}
