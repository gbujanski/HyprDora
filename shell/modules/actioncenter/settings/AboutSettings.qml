import QtQuick
import qs.config
import qs.components
import qs.services

// The computer's name, which a click turns into a field, and what the computer is, with a button that copies
// it all as text.
Column {
    id: root

    property bool editing: false

    spacing: 2

    Component.onCompleted: SystemInfo.refresh()

    function startEditing() {
        nameField.text = SystemInfo.name;
        editing = true;
        nameField.focusInput();
    }

    function save() {
        editing = false;
        if (nameField.text.trim() !== SystemInfo.name)
            SystemInfo.setName(nameField.text);
    }

    Item {
        width: root.width
        height: 40

        // The name, with a pencil; a click starts editing.
        Rectangle {
            anchors.fill: parent
            visible: !root.editing
            radius: Theme.radius
            color: nameArea.containsMouse ? Theme.surface : "transparent"

            Label {
                anchors {
                    left: parent.left
                    right: pencil.left
                    leftMargin: 8
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                text: SystemInfo.name
                font.pixelSize: Theme.fontSizeTitle
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Spinner {
                anchors {
                    right: pencil.left
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                running: SystemInfo.saving
            }

            Icon {
                id: pencil
                anchors {
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }
                text: Icons.edit
                color: Theme.muted
            }

            MouseArea {
                id: nameArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !SystemInfo.saving
                onClicked: root.startEditing()
            }
        }

        TextField {
            id: nameField
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            visible: root.editing
            onAccepted: root.save()
            onCancelled: root.editing = false
        }
    }

    Label {
        width: root.width
        visible: root.editing && SystemInfo.networkName(nameField.text) !== ""
        leftPadding: 8
        bottomPadding: 4
        text: SystemInfo.networkName(nameField.text)
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
        elide: Text.ElideRight
    }

    ErrorBanner {
        width: root.width
        text: SystemInfo.error
    }

    Item {
        width: 1
        height: 6
    }

    Repeater {
        model: SystemInfo.rows

        Item {
            required property var modelData

            width: root.width
            height: Math.max(22, value.implicitHeight + 4)

            Label {
                id: label
                anchors {
                    left: parent.left
                    leftMargin: 8
                    top: parent.top
                    topMargin: 2
                }
                width: 110
                text: parent.modelData.label
                color: Theme.muted
                elide: Text.ElideRight
            }

            Label {
                id: value
                anchors {
                    left: label.right
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                    top: parent.top
                    topMargin: 2
                }
                text: parent.modelData.value
                horizontalAlignment: Text.AlignRight
                wrapMode: Text.Wrap
            }
        }
    }

    Item {
        width: 1
        height: 6
    }

    TextButton {
        anchors.right: parent.right
        text: copiedTimer.running ? I18n.t("about.copied") : I18n.t("about.copy")
        onClicked: {
            SystemInfo.copy();
            copiedTimer.restart();
        }
    }

    Timer {
        id: copiedTimer
        interval: 1500
    }
}
