import QtQuick
import Quickshell.Widgets
import qs.config
import qs.components
import qs.services

Rectangle {
    id: root

    readonly property var player: Media.player

    implicitHeight: 92 + (Media.canShowPosition ? 26 : 0)
    radius: Theme.panelRadius - 2
    color: Theme.surface

    ClippingRectangle {
        id: art
        anchors {
            left: parent.left
            top: parent.top
            margins: 10
        }
        width: 72
        height: 72
        radius: Theme.radius
        color: Theme.surfaceHover

        Image {
            id: artImage
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            sourceSize.width: 144
            sourceSize.height: 144
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }

        Icon {
            anchors.centerIn: parent
            visible: !artImage.visible
            text: Icons.music
            color: Theme.muted
            font.pixelSize: 28
        }
    }

    Column {
        anchors {
            left: art.right
            right: parent.right
            top: parent.top
            leftMargin: 10
            rightMargin: 10
            topMargin: 10
        }
        spacing: 1

        Label {
            width: parent.width
            text: root.player?.trackTitle || root.player?.identity || ""
            textFormat: Text.PlainText
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            text: root.player?.trackArtist || root.player?.identity || ""
            textFormat: Text.PlainText
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }

        Row {
            topPadding: 4
            spacing: 2

            IconButton {
                icon: Icons.previous
                active: root.player?.canGoPrevious ?? false
                tooltip: "Poprzedni"
                onClicked: root.player.previous()
            }

            IconButton {
                icon: root.player?.isPlaying ? Icons.pause : Icons.play
                active: root.player?.canTogglePlaying ?? false
                tooltip: root.player?.isPlaying ? "Wstrzymaj" : "Odtwarzaj"
                onClicked: root.player.togglePlaying()
            }

            IconButton {
                icon: Icons.next
                active: root.player?.canGoNext ?? false
                tooltip: "Następny"
                onClicked: root.player.next()
            }

            IconButton {
                visible: Media.players.length > 1
                icon: Icons.swap
                iconColor: Theme.muted
                tooltip: `Przełącz odtwarzacz (${root.player?.identity ?? ""})`
                onClicked: Media.cyclePlayer()
            }
        }
    }

    Item {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: 10
            rightMargin: 10
            bottomMargin: 6
        }
        height: 20
        visible: Media.canShowPosition

        Label {
            id: elapsed
            anchors.verticalCenter: parent.verticalCenter
            text: Media.formatTime(root.player?.position ?? 0)
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
        }

        Slider {
            anchors {
                left: elapsed.right
                right: total.left
                leftMargin: 8
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            active: root.player?.canSeek ?? false
            value: Media.progress
            onMoved: value => Media.seek(value)
        }

        Label {
            id: total
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            text: Media.formatTime(root.player?.length ?? 0)
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
