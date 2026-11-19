import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The list of updates under the update icon: Fedora's own packages, then security updates, then other
// repositories and Flatpaks. The first ten show; "show all" unfolds the rest, which scrolls when long.
// The install buttons stay in view below the list.
BarPanel {
    id: root

    readonly property int preview: 10

    name: "updates"

    content: Component {
        Item {
            id: content

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

            implicitHeight: header.height + list.contentHeight + more.height + buttons.height + 3 * 10

            Label {
                id: header
                anchors {
                    top: parent.top
                    left: parent.left
                    right: size.left
                    rightMargin: 8
                }
                elide: Text.ElideRight
                text: I18n.t("updates.title", {
                    count: Updates.count
                })
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
            }

            // How much the updates download, to choose between now and later.
            Row {
                id: size
                anchors {
                    right: parent.right
                    verticalCenter: header.verticalCenter
                }
                spacing: 4
                visible: Updates.downloadSize > 0

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.download
                    color: Theme.muted
                    font.pixelSize: 14
                }

                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Updates.formatSize(Updates.downloadSize)
                    color: Theme.muted
                }
            }

            Flickable {
                id: list

                anchors {
                    top: header.bottom
                    bottom: more.top
                    left: parent.left
                    right: parent.right
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
                        model: content.rows

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
                    bottomMargin: 10
                }
                visible: Updates.count > root.preview && !content.showAll
                height: visible ? implicitHeight : 0
                text: I18n.t("updates.showAll", {
                    count: Updates.count
                })
                onClicked: content.showAll = true
            }

            // Always in view, however long the list.
            Column {
                id: buttons

                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                }
                spacing: 6

                TextButton {
                    width: parent.width
                    primary: true
                    text: I18n.t("updates.installNow")
                    active: !Updates.installing
                    onClicked: {
                        Panels.close("updates");
                        Updates.install();
                    }
                }

                TextButton {
                    width: parent.width
                    text: I18n.t("updates.atRestart")
                    active: Updates.packages > 0 && Updates.preparing === ""
                    onClicked: {
                        Panels.close("updates");
                        Updates.installOffline("reboot");
                    }
                }

                TextButton {
                    width: parent.width
                    text: I18n.t("updates.atPoweroff")
                    active: Updates.packages > 0 && Updates.preparing === ""
                    onClicked: {
                        Panels.close("updates");
                        Updates.installOffline("poweroff");
                    }
                }
            }
        }
    }
}
