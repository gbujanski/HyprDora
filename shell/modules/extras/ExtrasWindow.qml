import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Applications to install beyond the base system, in groups, each ticked or not; at the first HyprDora
// session it welcomes the user. It takes the whole screen, with the groups in as many columns as fit. Then
// the default application of each kind, such as the browser, chosen from a list of those installed and
// those ticked. Installing asks for the administrator password once and shows each item's progress; a failed
// one says why and stays ticked, to try again. Esc or the close button closes it, except while installing.
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
            color: Theme.background
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-extras"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                id: page

                // A column is wide enough for an application's name and description.
                readonly property int columnWidth: 360
                readonly property int columnSpacing: 24
                readonly property int columnCount: Math.max(1, Math.min(3, Math.floor((window.width - 64 + columnSpacing) / (columnWidth + columnSpacing))))

                // The groups shared out over the columns, each to the one with the fewest rows so far.
                readonly property var columns: {
                    const result = [];
                    const rows = [];
                    for (let i = 0; i < columnCount; i++) {
                        result.push([]);
                        rows.push(0);
                    }
                    for (const group of Extras.groups) {
                        const shortest = rows.indexOf(Math.min(...rows));
                        result[shortest].push(group);
                        rows[shortest] += group.items.length + 1;
                    }
                    return result;
                }

                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    horizontalCenter: parent.horizontalCenter
                    topMargin: 48
                    bottomMargin: 32
                }
                width: Math.min(parent.width - 64, columnCount * columnWidth + (columnCount - 1) * columnSpacing)
                focus: true

                Keys.onEscapePressed: Extras.close()

                Column {
                    id: header

                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    spacing: 8

                    Item {
                        width: parent.width
                        height: 36

                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Extras.welcome ? I18n.t("extras.welcomeTitle") : I18n.t("extras.title")
                            font.pixelSize: Theme.fontSizeHuge
                            font.weight: Font.DemiBold
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
                        topPadding: 4
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
                        topMargin: 16
                        bottomMargin: 16
                    }
                    clip: true
                    contentHeight: Extras.step === "defaults" ? kinds.implicitHeight : groupColumns.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Row {
                        id: groupColumns

                        visible: Extras.step !== "defaults"
                        spacing: page.columnSpacing

                        Repeater {
                            model: page.columns

                            Column {
                                id: column

                                required property var modelData

                                width: page.columnWidth
                                spacing: 16

                                Repeater {
                                    model: column.modelData

                                    Column {
                                        id: group

                                        required property var modelData

                                        width: column.width
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
                        }
                    }

                    // The default application of each kind with something to choose from, as a list to open.
                    Column {
                        id: kinds

                        width: Math.min(list.width, 560)
                        spacing: 2
                        visible: Extras.step === "defaults"

                        Repeater {
                            model: DefaultApps.kinds.filter(k => Extras.candidates(k.id).length > 0)

                            Dropdown {
                                required property var modelData

                                width: kinds.width
                                title: I18n.t(`defaultApps.${modelData.id}`)
                                options: Extras.candidates(modelData.id).map(c => ({
                                            value: c.desktop,
                                            label: c.itemId !== "" ? I18n.t("extras.toInstall", {
                                                name: c.name
                                            }) : c.name
                                        }))
                                currentValue: Extras.defaults[modelData.id]
                                onSelected: value => Extras.chooseDefault(modelData.id, value)
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

                    // Back comes first; after installing, Close is the main button.
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
                            visible: !Extras.busy && Extras.step !== "apps"
                            text: I18n.t("extras.back")
                            onClicked: Extras.step = "apps"
                        }

                        TextButton {
                            visible: !Extras.busy && Extras.step !== "defaults"
                            primary: Extras.step === "progress"
                            text: Extras.step === "apps" && Extras.welcome ? I18n.t("extras.later") : I18n.t("extras.close")
                            onClicked: Extras.close()
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
