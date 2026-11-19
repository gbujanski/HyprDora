import QtQuick
import qs.config
import qs.components
import qs.services

// One removable drive: its name and size with the button that removes it safely, then each of its
// partitions, which a click opens in the file manager. A locked encrypted partition asks for its password
// first. While the drive is in use, the programs holding it are named, with a button to try again.
Column {
    id: root

    required property var modelData
    readonly property var drive: modelData
    readonly property var status: Drives.status[drive.id] ?? null
    readonly property bool removing: status?.state === "removing"
    // The locked partition whose password is being asked for, by device.
    property string asking: ""

    spacing: 2

    Item {
        width: root.width
        height: 36

        Icon {
            id: driveIcon
            anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
            }
            text: root.drive.icon
            font.pixelSize: Theme.iconSizeLarge
        }

        Label {
            anchors {
                left: driveIcon.right
                right: action.left
                leftMargin: 10
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            text: `${root.drive.title} · ${Updates.formatSize(root.drive.size)}`
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Item {
            id: action
            anchors {
                right: parent.right
                rightMargin: 4
                verticalCenter: parent.verticalCenter
            }
            width: 30
            height: 30

            IconButton {
                anchors.fill: parent
                visible: !root.removing
                icon: Icons.eject
                iconColor: Theme.muted
                tooltip: I18n.t("drives.remove")
                active: Drives.current === null
                onClicked: Drives.remove(root.drive)
            }

            Spinner {
                anchors.centerIn: parent
                running: root.removing
                visible: root.removing
            }
        }
    }

    Label {
        width: root.width
        visible: root.status?.state === "busy" || root.status?.state === "failed"
        leftPadding: 38
        text: root.status?.state === "busy" ? ((root.status.users ?? []).length > 0 ? I18n.t("drives.busyUsers", {
                users: root.status.users.join(", ")
            }) : I18n.t("drives.busy")) : I18n.t("drives.failed", {
            message: root.status?.message ?? ""
        })
        color: Theme.warning
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Item {
        width: root.width
        height: retry.implicitHeight
        visible: retry.visible

        TextButton {
            id: retry
            x: 38
            visible: root.status?.state === "busy" || root.status?.state === "failed"
            text: I18n.t("drives.retry")
            onClicked: Drives.remove(root.drive)
        }
    }

    Repeater {
        model: root.drive.volumes

        Column {
            id: volumeItem

            required property var modelData
            readonly property var volume: modelData
            readonly property bool locked: volume.encrypted && !volume.unlocked
            readonly property bool mounted: volume.mountPoints.length > 0
            readonly property var unlockStatus: Drives.unlockStatus[volume.device] ?? null

            width: root.width
            spacing: 4

            Rectangle {
                width: parent.width
                height: 40
                radius: Theme.radius
                color: volumeArea.containsMouse ? Theme.surface : "transparent"

                Icon {
                    id: volumeIcon
                    anchors {
                        left: parent.left
                        leftMargin: 38
                        verticalCenter: parent.verticalCenter
                    }
                    text: volumeItem.locked ? Icons.lock : volumeItem.volume.encrypted ? Icons.lockOpen : Icons.folder
                    color: volumeItem.mounted ? Theme.foreground : Theme.muted
                }

                Column {
                    anchors {
                        left: volumeIcon.right
                        right: parent.right
                        leftMargin: 10
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }

                    Label {
                        width: parent.width
                        text: volumeItem.volume.label || volumeItem.volume.device
                        elide: Text.ElideRight
                    }

                    Label {
                        width: parent.width
                        text: [Updates.formatSize(volumeItem.volume.size), volumeItem.locked ? I18n.t("drives.locked") : volumeItem.mounted ? "" : I18n.t("drives.notMounted")].filter(s => s).join(" · ")
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSmall
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: volumeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.removing
                    onClicked: {
                        if (volumeItem.locked) {
                            root.asking = root.asking === volumeItem.volume.device ? "" : volumeItem.volume.device;
                            return;
                        }
                        Drives.open(volumeItem.volume);
                        Panels.close("drives");
                    }
                }
            }

            // The password of a locked partition; Enter unlocks it, then it opens.
            Item {
                width: parent.width
                height: passwordField.implicitHeight
                visible: root.asking === volumeItem.volume.device && volumeItem.locked

                TextField {
                    id: passwordField
                    anchors {
                        left: parent.left
                        right: parent.right
                        leftMargin: 38
                    }
                    secret: true
                    placeholder: I18n.t("drives.password")
                    onVisibleChanged: if (visible)
                        focusInput()
                    onAccepted: {
                        if (text !== "")
                            Drives.unlock(volumeItem.volume, text);
                        clear();
                    }
                    onCancelled: root.asking = ""
                }
            }

            Label {
                width: parent.width
                visible: volumeItem.unlockStatus !== null
                leftPadding: 38
                text: volumeItem.unlockStatus?.state === "unlocking" ? I18n.t("drives.unlocking") : /passphrase/i.test(volumeItem.unlockStatus?.message ?? "") ? I18n.t("drives.wrongPassword") : I18n.t("drives.unlockFailed", {
                    message: volumeItem.unlockStatus?.message ?? ""
                })
                color: volumeItem.unlockStatus?.state === "failed" ? Theme.warning : Theme.muted
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
            }

            // Once unlocked, the password field goes and the partition opens.
            Connections {
                target: volumeItem
                function onLockedChanged() {
                    if (!volumeItem.locked && root.asking === volumeItem.volume.device)
                        root.asking = "";
                }
            }
        }
    }
}
