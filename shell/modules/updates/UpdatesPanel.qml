import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// The list of updates under the update icon: Fedora's own packages, then security updates, then other
// repositories and Flatpaks. The first ten show; "show all" unfolds the rest, which scrolls when long.
// The install buttons stay in view below the list.
Scope {
    id: root

    readonly property int preview: 10

    Connections {
        target: Panels
        function onUpdatesOpenChanged() {
            if (!Panels.updatesOpen)
                closeDelay.restart();
        }
    }

    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: Panels.updatesOpen || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && Panels.updatesOpen
            property bool showAll: false

            // Rows of the list: a heading per group, then its packages; cut to the preview unless unfolded.
            readonly property var rows: {
                const all = [];
                for (const group of Updates.groups) {
                    all.push({
                        heading: I18n.t(`updates.group.${group.key}`),
                        count: group.items.length
                    });
                    for (const item of group.items)
                        all.push(item);
                }
                if (showAll)
                    return all;
                const cut = [];
                let packages = 0;
                for (const row of all) {
                    if (!row.heading && ++packages > root.preview)
                        break;
                    cut.push(row);
                }
                // A heading with nothing under it is left out.
                return cut[cut.length - 1]?.heading ? cut.slice(0, -1) : cut;
            }

            Component.onCompleted: entered = true

            screen: Panels.updatesScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Normal
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-updates"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.closeUpdates()
            }

            Rectangle {
                id: panel

                anchors {
                    top: parent.top
                    right: parent.right
                    margins: Theme.panelMargin
                }
                width: Theme.panelWidth
                height: Math.min(header.height + list.contentHeight + more.height + buttons.height + 4 * 10 + 2 * Theme.panelPadding, window.height - 2 * Theme.panelMargin)
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: window.shown ? 1 : 0
                focus: true

                Keys.onEscapePressed: Panels.closeUpdates()

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

                Label {
                    id: header
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                    text: I18n.t("updates.title", {
                        count: Updates.count
                    })
                    font.pixelSize: Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                }

                Flickable {
                    id: list

                    anchors {
                        top: header.bottom
                        bottom: more.top
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.panelPadding
                        rightMargin: Theme.panelPadding
                        topMargin: 10
                        bottomMargin: 6
                    }
                    contentWidth: width
                    contentHeight: rowsColumn.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Rectangle {
                        parent: list
                        anchors.right: parent.right
                        y: list.visibleArea.yPosition * list.height
                        width: 3
                        height: list.visibleArea.heightRatio * list.height
                        radius: 2
                        color: Theme.dim
                        visible: list.contentHeight > list.height
                    }

                    Column {
                        id: rowsColumn

                        width: list.width - (list.contentHeight > list.height ? 8 : 0)

                        Repeater {
                            model: window.rows

                            Item {
                                required property var modelData
                                required property int index
                                readonly property bool heading: !!modelData.heading

                                width: rowsColumn.width
                                // Compact rows, so a long list stays short; headings get a little air above.
                                height: heading ? (index === 0 ? 20 : 28) : 20

                                Label {
                                    anchors {
                                        left: parent.left
                                        bottom: parent.bottom
                                        bottomMargin: 2
                                    }
                                    visible: parent.heading
                                    text: `${parent.modelData.heading ?? ""} · ${parent.modelData.count ?? ""}`
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                }

                                Label {
                                    anchors {
                                        left: parent.left
                                        right: version.left
                                        rightMargin: 8
                                        verticalCenter: parent.verticalCenter
                                    }
                                    visible: !parent.heading
                                    text: parent.modelData.name ?? ""
                                    elide: Text.ElideRight
                                }

                                Label {
                                    id: version
                                    anchors {
                                        right: parent.right
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: Math.min(implicitWidth, parent.width * 0.45)
                                    visible: !parent.heading
                                    text: parent.modelData.version ?? ""
                                    color: Theme.muted
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideLeft
                                }
                            }
                        }
                    }
                }

                TextButton {
                    id: more
                    anchors {
                        bottom: buttons.top
                        left: parent.left
                        leftMargin: Theme.panelPadding
                        bottomMargin: 10
                    }
                    visible: Updates.count > root.preview && !window.showAll
                    height: visible ? implicitHeight : 0
                    text: I18n.t("updates.showAll", {
                        count: Updates.count
                    })
                    onClicked: window.showAll = true
                }

                // Always in view, however long the list.
                Column {
                    id: buttons

                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                    spacing: 6

                    TextButton {
                        width: parent.width
                        primary: true
                        text: I18n.t("updates.installNow")
                        active: !Updates.installing
                        onClicked: {
                            Panels.closeUpdates();
                            Updates.install();
                        }
                    }

                    TextButton {
                        width: parent.width
                        text: I18n.t("updates.atRestart")
                        active: Updates.packages > 0 && Updates.preparing === ""
                        onClicked: {
                            Panels.closeUpdates();
                            Updates.installOffline("reboot");
                        }
                    }

                    TextButton {
                        width: parent.width
                        text: I18n.t("updates.atPoweroff")
                        active: Updates.packages > 0 && Updates.preparing === ""
                        onClicked: {
                            Panels.closeUpdates();
                            Updates.installOffline("poweroff");
                        }
                    }
                }
            }
        }
    }
}
