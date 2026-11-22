import QtQuick
import qs.components

// One of the action center's pages, such as Wi-Fi's, wherever it shows: in the action center, or on its own
// under its bar icon. It scrolls when long, returns to the top when the page asks or changes, and gives the
// keyboard to the page that wants it, otherwise to focusTarget, so Esc keeps working.
ScrollArea {
    id: root

    property Component page: null
    property Item focusTarget: root

    contentHeight: loader.item?.implicitHeight ?? 0

    Loader {
        id: loader
        width: root.usableWidth
        sourceComponent: root.page
        onSourceComponentChanged: root.contentY = 0
        onLoaded: (item.wantsFocus ? item : root.focusTarget).forceActiveFocus()
    }

    Connections {
        target: loader.item
        ignoreUnknownSignals: true
        function onScrollToTop() {
            root.contentY = 0;
        }
    }
}
