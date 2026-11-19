import QtQuick
import qs.config

// The heading of a section of a list, with a spinner after it while the list is being looked for.
Label {
    id: root

    property bool busy: false

    color: Theme.muted
    font.pixelSize: Theme.fontSizeSmall
    font.weight: Font.DemiBold
    bottomPadding: 2

    Spinner {
        x: root.leftPadding + root.contentWidth + 6
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -root.bottomPadding / 2
        running: root.busy
        visible: root.busy
    }
}
