import QtQuick
import qs.config

// Quick settings tile: a click toggles, the arrow opens a subpage.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    property bool enabledTile: true
    // A tile without its own page has no arrow.
    property bool showChevron: true

    signal toggled
    signal opened

    implicitHeight: 56
    radius: Theme.radius + 4
    color: active ? Theme.accentSoft : Theme.surface

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabledTile
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Icon {
        id: tileIcon
        anchors {
            left: parent.left
            leftMargin: 12
            verticalCenter: parent.verticalCenter
        }
        text: root.icon
        font.pixelSize: Theme.iconSizeLarge
        color: root.active ? Theme.accent : Theme.muted
    }

    Column {
        anchors {
            left: tileIcon.right
            right: chevron.visible ? chevron.left : parent.right
            leftMargin: 10
            rightMargin: 2
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            text: root.title
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            text: root.subtitle
            color: Theme.muted
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }

    IconButton {
        id: chevron
        anchors {
            right: parent.right
            rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        visible: root.showChevron
        icon: Icons.chevronRight
        iconColor: Theme.muted
        // A switched-on tile is green, so the arrow lights up in green too.
        hoverColor: root.active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : Theme.surfaceHover
        onClicked: root.opened()
    }
}
