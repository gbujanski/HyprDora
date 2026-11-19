import QtQuick
import qs.config

// A row of a list of things: an icon, a title and a subtitle, buttons on the right (trailing) and more lines
// under the subtitle (details). A highlighted row, such as the connected network, has a background and a
// stronger title; any row lights up under the pointer when it can be clicked.
Rectangle {
    id: root

    property string icon: ""
    property color iconColor: highlighted ? Theme.accent : Theme.foreground
    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.muted
    property bool highlighted: false
    // Whether a click does something; a row that only shows lights up neither.
    property bool interactive: true
    // Space before the icon, as for a partition under its drive.
    property real indent: 0
    property alias trailing: actions.data
    property alias details: extra.data
    readonly property bool hovered: area.containsMouse

    signal clicked

    implicitHeight: Math.max(subtitle !== "" ? 44 : 34, texts.implicitHeight + 12)
    radius: Theme.radius
    color: highlighted || (interactive && area.containsMouse) ? Theme.surface : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0)

    Behavior on color {
        ColorAnimation {
            duration: Theme.animFast
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Icon {
        id: rowIcon
        anchors {
            left: parent.left
            leftMargin: 10 + root.indent
            verticalCenter: parent.verticalCenter
        }
        visible: root.icon !== ""
        text: root.icon
        color: root.iconColor
    }

    Column {
        id: texts
        anchors {
            left: rowIcon.visible ? rowIcon.right : parent.left
            right: actions.left
            leftMargin: rowIcon.visible ? 10 : 10 + root.indent
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }

        Label {
            width: parent.width
            text: root.title
            font.weight: root.highlighted ? Font.Medium : Font.Normal
            elide: Text.ElideRight
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: root.subtitle
            color: root.subtitleColor
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
        }

        Column {
            id: extra
            width: parent.width
        }
    }

    Row {
        id: actions
        anchors {
            right: parent.right
            rightMargin: 4
            verticalCenter: parent.verticalCenter
        }
        spacing: 2
    }
}
