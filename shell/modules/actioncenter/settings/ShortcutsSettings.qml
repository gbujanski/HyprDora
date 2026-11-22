import QtQuick
import qs.config
import qs.components
import qs.services

// Keyboard shortcuts and touchpad gestures, in their groups, as the cheat sheet shows them.
Column {
    id: root

    spacing: 2
    Component.onCompleted: Shortcuts.refresh()

    Repeater {
        model: Shortcuts.groups

        Column {
            id: group

            required property var modelData
            required property int index

            width: root.width
            spacing: 0

            SectionTitle {
                leftPadding: 4
                topPadding: group.index > 0 ? 8 : 0
                text: group.modelData.title
            }

            Repeater {
                model: group.modelData.rows

                Item {
                    required property var modelData

                    width: root.width
                    height: 28

                    Label {
                        anchors {
                            left: parent.left
                            right: keys.left
                            leftMargin: 4
                            rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        text: parent.modelData.description
                        elide: Text.ElideRight
                    }

                    Label {
                        id: keys
                        anchors {
                            right: parent.right
                            rightMargin: 4
                            verticalCenter: parent.verticalCenter
                        }
                        text: parent.modelData.keys
                        color: Theme.muted
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
            }
        }
    }
}
