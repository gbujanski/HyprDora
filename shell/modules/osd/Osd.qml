import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Volume and brightness indicator. It shows only when asked through Indicator, for a change the user made
// (keys, the bar's sound icon), and then follows the current value, so it never shows for a change that
// happens on its own. The one exception reads PipeWire: a Bluetooth headset with its own volume buttons
// changes the volume directly, which counts as the user's when the output has stayed the same for a while,
// so switching outputs, as when headphones disconnect, does not show it.
Scope {
    id: root

    property string kind: ""
    property bool shown: false

    // When the default output last changed, in milliseconds.
    property real sinkChangedAt: Date.now()
    readonly property int settleTime: 3000

    readonly property string icon: {
        switch (kind) {
        case "volume":
            return Icons.volume(Audio.volume, Audio.muted);
        case "microphone":
            return Icons.microphone(Audio.sourceMuted);
        case "display":
            return Icons.brightness;
        case "keyboard":
            return Icons.keyboard;
        }
        return "";
    }
    readonly property real value: {
        switch (kind) {
        case "volume":
            return Audio.muted ? 0 : Audio.volume;
        case "display":
            return Brightness.display.level;
        case "keyboard":
            return Brightness.keyboard.level;
        }
        return 0;
    }
    readonly property string title: {
        switch (kind) {
        case "volume":
            return Audio.muted ? I18n.t("osd.muted") : `${Math.round(Audio.volume * 100)}%`;
        case "microphone":
            return Audio.sourceMuted ? I18n.t("osd.micMuted") : I18n.t("osd.micOn");
        case "display":
        case "keyboard":
            return `${Math.round(value * 100)}%`;
        }
        return "";
    }
    readonly property bool showBar: kind !== "microphone"

    /**
     * Shows the indicator for a kind, unless a panel with the same controls is open.
     * @param {string} kindName  "volume", "microphone", "display" or "keyboard"
     */
    function show(kindName) {
        if (Panels.actionCenterOpen || (Panels.soundOpen && (kindName === "volume" || kindName === "microphone")))
            return;
        kind = kindName;
        shown = true;
        hideTimer.restart();
    }

    /**
     * Tells whether the default output is a Bluetooth device.
     * @returns {bool}
     */
    function sinkIsBluetooth() {
        return (Audio.sink?.properties?.["device.api"] ?? "") === "bluez5";
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    Timer {
        id: fadeDelay
        interval: Theme.animFast + 20
    }

    onShownChanged: if (!shown)
        fadeDelay.restart()

    Connections {
        target: Indicator

        function onRequested(kind) {
            root.show(kind);
        }
    }

    Connections {
        target: Audio

        function onSinkChanged() {
            root.sinkChangedAt = Date.now();
        }
        // A headset's own volume buttons, on an output that has not just changed.
        function onVolumeChanged() {
            if (root.sinkIsBluetooth() && Date.now() - root.sinkChangedAt > root.settleTime)
                root.show("volume");
        }
    }

    LazyLoader {
        active: root.shown || fadeDelay.running

        PanelWindow {
            screen: Panels.focusedScreen()
            anchors.bottom: true
            margins.bottom: 72
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: 300
            implicitHeight: 52
            color: "transparent"
            // An empty mask lets clicks through to windows below.
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "hyprdora-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: visibleState.on ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animFast
                    }
                }

                QtObject {
                    id: visibleState
                    property bool on: false
                    Component.onCompleted: on = Qt.binding(() => root.shown)
                }

                Icon {
                    id: osdIcon
                    anchors {
                        left: parent.left
                        leftMargin: 18
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.icon
                    font.pixelSize: 20
                }

                Rectangle {
                    id: track
                    anchors {
                        left: osdIcon.right
                        right: valueLabel.left
                        leftMargin: 12
                        rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    visible: root.showBar
                    height: 6
                    radius: 3
                    color: Theme.surface

                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, root.value))
                        radius: parent.radius
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animFast
                            }
                        }
                    }
                }

                Label {
                    id: valueLabel
                    anchors {
                        right: root.showBar ? parent.right : undefined
                        rightMargin: 18
                        left: root.showBar ? undefined : osdIcon.right
                        leftMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.title
                    font.weight: Font.Medium
                }
            }
        }
    }

    IpcHandler {
        target: "osd"

        function describe(): string {
            return JSON.stringify({
                shown: root.shown,
                kind: root.kind,
                title: root.title,
                value: root.value
            });
        }
        function show(kind: string): void {
            Indicator.show(kind);
        }
    }
}
