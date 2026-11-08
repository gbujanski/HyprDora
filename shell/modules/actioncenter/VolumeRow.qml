import QtQuick
import Quickshell.Services.Pipewire
import qs.config
import qs.components
import qs.services

// Wyciszenie, nazwa i suwak głośności dla jednego węzła PipeWire.
Item {
    id: root

    property PwNode node: null
    property string title: Audio.displayName(node)
    property string emptyTitle: "Brak urządzenia"
    property bool isMicrophone: false
    property bool showChevron: false

    signal chevronClicked()

    readonly property bool available: node?.audio !== undefined && node?.audio !== null
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property real volume: node?.audio?.volume ?? 0

    implicitHeight: 46

    IconButton {
        id: muteButton
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        active: root.available
        icon: root.isMicrophone ? Icons.microphone(root.muted) : Icons.volume(root.volume, root.muted)
        iconColor: root.muted ? Theme.muted : Theme.foreground
        tooltip: root.muted ? "Włącz dźwięk" : "Wycisz"
        onClicked: Audio.toggleNodeMute(root.node)
    }

    Column {
        anchors {
            left: muteButton.right
            right: chevron.visible ? chevron.left : parent.right
            leftMargin: 8
            rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        spacing: 2

        Item {
            width: parent.width
            height: nameLabel.implicitHeight

            Label {
                id: nameLabel
                anchors {
                    left: parent.left
                    right: percent.left
                    rightMargin: 8
                }
                text: root.available ? root.title : root.emptyTitle
                elide: Text.ElideRight
                color: root.available ? Theme.foreground : Theme.muted
            }

            Label {
                id: percent
                anchors.right: parent.right
                visible: root.available
                text: root.muted ? "wyciszone" : `${Math.round(root.volume * 100)}%`
                color: Theme.muted
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        Slider {
            width: parent.width
            active: root.available
            value: root.volume
            onMoved: value => Audio.setNodeVolume(root.node, value)
        }
    }

    IconButton {
        id: chevron
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        visible: root.showChevron
        icon: Icons.chevronRight
        iconColor: Theme.muted
        tooltip: "Urządzenia i aplikacje"
        onClicked: root.chevronClicked()
    }
}
