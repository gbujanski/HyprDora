import QtQuick
import qs.config
import qs.components

// A setting with a few choices: its name, the current choice, and the choices beside it in the settings
// menu when hovered or clicked. Without choices it only shows the value. A compact row sits under another
// setting, as a detail of it.
Rectangle {
    id: row

    // The settings menu, which shows the choices.
    property Item menu: null
    property string title: ""
    // The current choice's label.
    property string valueText: ""
    // [{ value, label }], and the current value among them.
    property var options: []
    property var current: null
    // What the setting does, shown above the choices; none when empty.
    property string note: ""
    property bool compact: false
    readonly property bool choosable: options.length > 0
    readonly property bool open: menu?.submenu?.owner === row

    signal selected(var value)

    /** Shows the choices beside the row. */
    function showOptions() {
        if (choosable)
            menu?.openSubmenu(row, options, current, value => row.selected(value), note);
    }

    height: compact ? 30 : 34
    radius: Theme.radius
    color: open || rowArea.containsMouse ? Theme.surface : "transparent"

    Label {
        id: titleLabel
        anchors {
            left: parent.left
            leftMargin: row.compact ? 6 : 8
            verticalCenter: parent.verticalCenter
        }
        text: row.title
        color: Theme.muted
        font.pixelSize: row.compact ? Theme.fontSizeSmall : Theme.fontSize
    }

    Row {
        anchors {
            right: parent.right
            rightMargin: 6
            verticalCenter: parent.verticalCenter
        }
        spacing: 4

        Label {
            anchors.verticalCenter: parent.verticalCenter
            // Takes the space the name leaves free.
            width: Math.min(implicitWidth, row.width - titleLabel.implicitWidth - 50)
            text: row.valueText
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            text: Icons.chevronRight
            color: Theme.muted
            opacity: row.choosable ? 1 : 0
        }
    }

    MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.choosable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onContainsMouseChanged: {
            if (containsMouse)
                row.showOptions();
        }
        onClicked: row.showOptions()
    }
}
