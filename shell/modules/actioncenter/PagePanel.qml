import QtQuick
import qs.components

// An action center page on its own under its bar icon, such as Wi-Fi's: the same page, without the way back
// to the action center.
BarPanel {
    id: root

    // A heading above the page; none when empty, as a page's own first row usually names it.
    property string title: ""
    property Component page: null

    content: Component {
        Item {
            id: layout

            implicitHeight: (header.visible ? header.height + 10 : 0) + view.contentHeight
            focus: true

            Title {
                id: header
                visible: root.title !== ""
                text: root.title
            }

            PageView {
                id: view
                anchors {
                    top: header.visible ? header.bottom : parent.top
                    topMargin: header.visible ? 10 : 0
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                }
                page: root.page
                focusTarget: layout
            }
        }
    }
}
