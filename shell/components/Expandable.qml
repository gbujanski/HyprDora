import QtQuick
import qs.config

// A row that unfolds more rows, such as a list of choices, as GNOME's quick settings do: the row stays as it
// is, and what it unfolds opens in a box of its own under it, a little lighter than the panel, with an
// optional title. Nothing in the row moves or narrows, and the box makes clear where the unfolded rows end.
// The row goes in header; what unfolds is the content, laid out contentWidth wide.
Column {
    id: root

    property bool expanded: false
    // Shown at the top of the box, as a section title; none when empty.
    property string boxTitle: ""
    property alias header: headerSlot.data
    default property alias content: contentColumn.data
    readonly property int inset: 6
    readonly property real contentWidth: width - 2 * inset

    spacing: 4
    // Room before whatever follows the box.
    bottomPadding: expanded ? 4 : 0

    Item {
        id: headerSlot
        width: root.width
        height: childrenRect.height
    }

    Rectangle {
        width: root.width
        height: boxColumn.implicitHeight + 2 * root.inset
        visible: root.expanded
        radius: Theme.radius + 2
        color: Theme.surfaceLow

        Column {
            id: boxColumn

            x: root.inset
            y: root.inset
            width: root.contentWidth
            spacing: 2

            SectionTitle {
                visible: root.boxTitle !== ""
                leftPadding: 4
                bottomPadding: 2
                text: root.boxTitle
            }

            Column {
                id: contentColumn
                width: parent.width
                spacing: 2
            }
        }
    }
}
