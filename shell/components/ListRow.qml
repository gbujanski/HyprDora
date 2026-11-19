import QtQuick
import qs.config

// A list row with text alone, optionally marked as selected with a check; the simplest ItemRow.
ItemRow {
    id: root

    property string text: ""
    property string trailingIcon: ""
    property bool selected: false

    title: text
    highlighted: selected

    trailing: Icon {
        anchors.verticalCenter: parent.verticalCenter
        rightPadding: 6
        text: root.selected ? Icons.check : root.trailingIcon
        color: root.selected ? Theme.accent : Theme.muted
    }
}
