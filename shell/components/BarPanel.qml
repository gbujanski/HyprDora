import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// The frame every panel at the bar shares: a window over the screen, so a click outside the panel closes it
// and the bar stays clickable; the panel's background, slide and fade; Esc to close. It opens and closes
// with Panels by its name, and a closed panel's window does not exist.
//
// The contents come as a Component, laid out inside the padding; the panel is as tall as their
// implicitHeight, at most the screen's height less the margins, which availableHeight gives the contents
// so they can scroll within it. They get the keyboard first, so they may handle Esc themselves and leave
// it unaccepted to close the panel. Things placed beside the panel, such as a menu, come as `beside`,
// over the whole window.
Scope {
    id: root

    // The panel's name in Panels.
    required property string name
    // "right", under the bar's right end, or "center", under the clock.
    property string side: "right"
    property real panelWidth: Theme.panelWidth
    // From the top of the window; under the bar unless set.
    property real topMargin: Theme.panelMargin
    property real padding: Theme.panelPadding
    // The action center slides in from the side; the others drop down.
    property bool slideSideways: false
    // The launcher takes all keys; the others leave the bar clickable.
    property bool exclusiveKeyboard: false
    // Whether the window keeps clear of the bar, so the bar stays clickable while the panel is open.
    property bool belowBar: true

    property Component content: null
    property Component beside: null

    // For the contents: whether the panel is shown (false while it fades out), the panel item, the window,
    // and the height the contents may take.
    readonly property bool open: Panels.isOpen(name)
    property bool shown: false
    property Item panel: null
    property var window: null
    property real availableHeight: 0
    // The loaded contents, to give them the keyboard back.
    property Item contentItem: null

    // A click on the panel's background, not on anything in it.
    signal backgroundClicked

    /** Gives the keyboard back to the contents, as after a page that held it went away. */
    function focusContents() {
        (contentItem ?? panel)?.forceActiveFocus();
    }

    // The screen the panel opened on, kept while it fades out, so it does not jump to the next panel's.
    property var screen: null
    onOpenChanged: {
        if (open)
            screen = Panels.currentScreen;
        else
            closeDelay.restart();
    }
    Component.onCompleted: {
        if (open)
            screen = Panels.currentScreen;
    }

    // The window outlives closing briefly so the animation can finish.
    Timer {
        id: closeDelay
        interval: Theme.animPanel + 20
    }

    LazyLoader {
        active: root.open || closeDelay.running

        PanelWindow {
            id: window

            property bool entered: false
            readonly property bool shown: entered && root.open

            Component.onCompleted: {
                entered = true;
                root.window = window;
            }
            Component.onDestruction: {
                if (root.window === window) {
                    root.window = null;
                    root.panel = null;
                    root.contentItem = null;
                    root.shown = false;
                }
            }
            onShownChanged: root.shown = shown

            screen: root.screen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: root.belowBar ? ExclusionMode.Normal : ExclusionMode.Ignore
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: `hyprdora-${root.name}`
            // OnDemand, not Exclusive, except where asked: with Exclusive, Hyprland routes every click to this
            // layer and the bar stops reacting. Focus still reaches the panel on open, so Esc works.
            WlrLayershell.keyboardFocus: root.exclusiveKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

            Binding {
                target: root
                property: "availableHeight"
                value: window.height - root.topMargin - Theme.panelMargin - 2 * root.padding
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: Panels.close(root.name)
            }

            FocusScope {
                id: panel

                Component.onCompleted: {
                    root.panel = panel;
                    forceActiveFocus();
                }

                x: root.side === "center" ? Math.round((window.width - width) / 2) : window.width - width - Theme.panelMargin
                y: root.topMargin
                width: root.panelWidth
                height: Math.min((loader.item?.implicitHeight ?? 0) + 2 * root.padding, window.height - root.topMargin - Theme.panelMargin)
                opacity: window.shown ? 1 : 0

                Keys.onEscapePressed: Panels.close(root.name)

                transform: Translate {
                    x: root.slideSideways && !window.shown ? 16 : 0
                    y: !root.slideSideways && !window.shown ? -12 : 0
                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.animPanel
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.animPanel
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animPanel
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.panelRadius
                    color: Theme.background
                    border.width: 1
                    border.color: Theme.surface
                }

                // Absorbs clicks so they do not reach the closing area.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    onClicked: root.backgroundClicked()
                }

                Loader {
                    id: loader
                    anchors {
                        fill: parent
                        margins: root.padding
                    }
                    focus: true
                    sourceComponent: root.content
                    onLoaded: root.contentItem = item
                }
            }

            Loader {
                anchors.fill: parent
                sourceComponent: root.beside
            }
        }
    }
}
