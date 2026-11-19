import QtQuick
import qs.config

// A vertically scrolling area with a thin scroll bar on the right while its contents are taller than it.
// The contents take usableWidth, which leaves room for the bar when it shows.
Flickable {
    id: root

    readonly property bool scrolls: contentHeight > height
    readonly property real usableWidth: width - (scrolls ? 8 : 0)

    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Rectangle {
        parent: root
        anchors.right: parent.right
        y: root.visibleArea.yPosition * root.height
        width: 3
        height: root.visibleArea.heightRatio * root.height
        radius: Theme.radiusTiny
        color: Theme.dim
        visible: root.scrolls
    }
}
