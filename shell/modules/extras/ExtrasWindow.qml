import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Applications to install beyond the base system, in groups, each ticked or not; at the first HyprDora
// session it welcomes the user. Then the default applications, such as the browser, among those installed and
// those ticked. Installing asks for the administrator password once and shows each item's progress; a failed
// one says why and stays ticked, to try again. Esc, the close button or a click outside closes it, except
// while installing.
Scope {
    LazyLoader {
        active: Extras.windowOpen

        PanelWindow {
            id: window

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
            WlrLayershell.namespace: "hyprdora-extras"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            MouseArea {
                anchors.fill: parent
                onClicked: Extras.close()
            }

            Rectangle {
                id: panel

                anchors.centerIn: parent
                width: Math.min(620, parent.width - 2 * Theme.panelMargin)
                height: Math.min(parent.height * 0.85, header.height + list.contentHeight + footer.height + 2 * Theme.panelPadding + 16)
                radius: Theme.panelRadius
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                focus: true

                Keys.onEscapePressed: Extras.close()

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
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 30

                        Title {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Extras.welcome ? I18n.t("extras.welcomeTitle") : I18n.t("extras.title")
                        }

                        IconButton {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            visible: !Extras.busy
                            icon: Icons.close
                            iconColor: Theme.muted
                            onClicked: Extras.close()
                        }
                    }

                    Label {
                        width: parent.width
                        text: Extras.step === "defaults" ? I18n.t("extras.defaultsInstruction") : I18n.t("extras.instruction")
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        visible: Extras.step === "apps"
                        spacing: 6
                        bottomPadding: 4

                        TextButton {
                            text: I18n.t("extras.selectAll")
                            active: !Extras.busy
                            onClicked: Extras.selectAll(true)
                        }

                        TextButton {
                            text: I18n.t("extras.selectNone")
                            active: !Extras.busy
                            onClicked: Extras.selectAll(false)
                        }
                    }
                }

                Flickable {
                    id: list

                    anchors {
                        top: header.bottom
                        bottom: footer.top
                        left: parent.left
                        right: parent.right
                        leftMargin: Theme.panelPadding - 4
                        rightMargin: Theme.panelPadding - 4
                        topMargin: 4
                        bottomMargin: 8
                    }
                    clip: true
                    contentHeight: Extras.step === "defaults" ? kinds.implicitHeight : groups.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: groups

                        width: list.width
                        spacing: 10
                        visible: Extras.step !== "defaults"

                        Repeater {
                            model: Extras.groups

                            Column {
                                id: group

                                required property var modelData

                                width: groups.width
                                spacing: 2

                                SectionTitle {
                                    leftPadding: 4
                                    text: I18n.t(`extras.group.${group.modelData.id}`)
                                }

                                Repeater {
                                    model: group.modelData.items

                                    Rectangle {
                                        id: row

                                        required property var modelData
                                        readonly property string itemId: modelData.id
                                        readonly property bool installed: Extras.installed[itemId] === true
                                        readonly property bool ticked: Extras.selected[itemId] === true && !installed
                                        readonly property string itemState: Extras.progress[itemId] ?? ""
                                        readonly property bool clickable: !installed && Extras.step === "apps"

                                        width: group.width
                                        height: 46
                                        radius: Theme.radius
                                        color: clickable && rowArea.containsMouse ? Theme.surface : "transparent"

                                        // A tick box, or what installing the item came to.
                                        Item {
                                            id: mark

                                            anchors {
                                                left: parent.left
                                                leftMargin: 8
                                                verticalCenter: parent.verticalCenter
                                            }
                                            width: 20
                                            height: 20

                                            Rectangle {
                                                anchors.fill: parent
                                                visible: row.itemState !== "installing" && row.itemState !== "waiting"
                                                radius: 5
                                                color: row.ticked ? Theme.accent : "transparent"
                                                border.width: row.ticked || row.installed ? 0 : 1.5
                                                border.color: Theme.muted

                                                Icon {
                                                    anchors.centerIn: parent
                                                    visible: row.ticked || row.installed
                                                    text: Icons.check
                                                    color: row.ticked ? Theme.accentText : Theme.accent
                                                    font.pixelSize: 16
                                                }
                                            }

                                            Spinner {
                                                anchors.centerIn: parent
                                                running: row.itemState === "installing"
                                                visible: row.itemState === "installing" || row.itemState === "waiting"
                                            }
                                        }

                                        Column {
                                            anchors {
                                                left: mark.right
                                                right: status.left
                                                leftMargin: 12
                                                rightMargin: 8
                                                verticalCenter: parent.verticalCenter
                                            }
                                            spacing: 1

                                            Label {
                                                width: parent.width
                                                text: I18n.t(`extras.${row.itemId}`)
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                width: parent.width
                                                text: row.itemState === "failed" ? (Extras.errors[row.itemId] ?? "") : I18n.t(`extras.${row.itemId}.description`)
                                                color: row.itemState === "failed" ? Theme.warning : Theme.muted
                                                font.pixelSize: Theme.fontSizeSmall
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Label {
                                            id: status

                                            anchors {
                                                right: parent.right
                                                rightMargin: 10
                                                verticalCenter: parent.verticalCenter
                                            }
                                            text: row.installed ? I18n.t("extras.installed") : row.itemState === "waiting" ? I18n.t("extras.waiting") : row.itemState === "failed" ? I18n.t("extras.failed") : ""
                                            color: row.itemState === "failed" ? Theme.warning : Theme.muted
                                            font.pixelSize: Theme.fontSizeSmall
                                        }

                                        MouseArea {
                                            id: rowArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: row.clickable
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Extras.setSelected(row.itemId, !row.ticked)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // The default application of each kind with something to choose from.
                    Column {
                        id: kinds

                        width: list.width
                        spacing: 10
                        visible: Extras.step === "defaults"

                        Repeater {
                            model: DefaultApps.kinds.filter(k => Extras.candidates(k.id).length > 0)

                            Column {
                                id: kind

                                required property var modelData

                                width: kinds.width
                                spacing: 2

                                SectionTitle {
                                    leftPadding: 4
                                    text: I18n.t(`defaultApps.${kind.modelData.id}`).toUpperCase()
                                }

                                Repeater {
                                    model: Extras.candidates(kind.modelData.id)

                                    ListRow {
                                        required property var modelData

                                        width: kind.width
                                        text: modelData.name
                                        trailingIcon: modelData.itemId !== "" ? Icons.download : ""
                                        selected: Extras.defaults[kind.modelData.id] === modelData.desktop
                                        onClicked: Extras.chooseDefault(kind.modelData.id, modelData.desktop)
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: footer

                    anchors {
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: Theme.panelPadding
                    }
                    height: 34

                    Label {
                        anchors {
                            left: parent.left
                            right: buttons.left
                            rightMargin: 12
                            verticalCenter: parent.verticalCenter
                        }
                        visible: !Network.online
                        text: I18n.t("extras.offline")
                        color: Theme.warning
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                    }

                    Row {
                        id: buttons

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 6

                        Spinner {
                            anchors.verticalCenter: parent.verticalCenter
                            running: Extras.busy
                            visible: Extras.busy
                        }

                        TextButton {
                            visible: !Extras.busy && Extras.step !== "defaults"
                            text: Extras.step === "apps" && Extras.welcome ? I18n.t("extras.later") : I18n.t("extras.close")
                            onClicked: Extras.close()
                        }

                        TextButton {
                            visible: !Extras.busy && Extras.step !== "apps"
                            text: I18n.t("extras.back")
                            onClicked: Extras.step = "apps"
                        }

                        TextButton {
                            visible: Extras.step === "apps"
                            primary: true
                            text: I18n.t("extras.next")
                            onClicked: Extras.toDefaults()
                        }

                        TextButton {
                            visible: Extras.step === "defaults"
                            primary: true
                            text: Extras.selectedIds.length > 0 ? I18n.t("extras.install", {
                                count: Extras.selectedIds.length
                            }) : I18n.t("extras.save")
                            active: Network.online || Extras.selectedIds.length === 0
                            onClicked: Extras.finish()
                        }
                    }
                }
            }
        }
    }
}
