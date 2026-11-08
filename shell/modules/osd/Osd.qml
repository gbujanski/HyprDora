import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Wskaźnik głośności i jasności. Reaguje na samą zmianę wartości, więc działa dla
// klawiszy, wpctl, brightnessctl i innych aplikacji bez osobnego wyzwalania.
Scope {
    id: root

    property string kind: ""
    property string icon: ""
    property string title: ""
    property real value: 0
    property bool showBar: true
    property bool shown: false

    // Odczyty początkowe i zmiana urządzenia to nie są zmiany wykonane przez użytkownika.
    property bool armed: false
    property real lastVolume: -1
    property real lastDisplay: -1
    property real lastKeyboard: -1

    function show(kindName, iconText, titleText, level, bar) {
        if (!armed || Panels.actionCenterOpen) return;
        kind = kindName;
        icon = iconText;
        title = titleText;
        value = level;
        showBar = bar;
        shown = true;
        hideTimer.restart();
    }

    function suspendBriefly() {
        armed = false;
        armTimer.restart();
    }

    function showVolume() {
        root.show("volume", Icons.volume(Audio.volume, Audio.muted),
            Audio.muted ? "Wyciszono" : `${Math.round(Audio.volume * 100)}%`,
            Audio.muted ? 0 : Audio.volume, true);
    }

    Timer {
        id: armTimer
        interval: 1500
        running: true
        onTriggered: {
            root.lastVolume = Audio.volume;
            root.lastDisplay = Brightness.display.level;
            root.lastKeyboard = Brightness.keyboard.level;
            root.armed = true;
        }
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

    onShownChanged: if (!shown) fadeDelay.restart()

    Connections {
        target: Audio

        function onSinkChanged() { root.suspendBriefly(); }
        function onSourceChanged() { root.suspendBriefly(); }

        function onVolumeChanged() {
            if (Math.abs(Audio.volume - root.lastVolume) < 0.001) return;
            root.lastVolume = Audio.volume;
            root.showVolume();
        }
        function onMutedChanged() { root.showVolume(); }
        function onSourceMutedChanged() {
            root.show("microphone", Icons.microphone(Audio.sourceMuted),
                Audio.sourceMuted ? "Mikrofon wyciszony" : "Mikrofon włączony", 0, false);
        }
    }

    Connections {
        target: Brightness.display
        function onLevelChanged() {
            const level = Brightness.display.level;
            if (Math.abs(level - root.lastDisplay) < 0.001) return;
            root.lastDisplay = level;
            root.show("display", Icons.brightness, `${Math.round(level * 100)}%`, level, true);
        }
    }

    Connections {
        target: Brightness.keyboard
        function onLevelChanged() {
            const level = Brightness.keyboard.level;
            if (Math.abs(level - root.lastKeyboard) < 0.001) return;
            root.lastKeyboard = level;
            root.show("keyboard", Icons.keyboard, `${Math.round(level * 100)}%`, level, true);
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
            // Pusta maska przepuszcza kliknięcia do okien pod wskaźnikiem.
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gui-demo-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.background
                border.width: 1
                border.color: Theme.surface
                opacity: visibleState.on ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

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

                        Behavior on width { NumberAnimation { duration: Theme.animFast } }
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
            return JSON.stringify({ shown: root.shown, armed: root.armed, kind: root.kind, title: root.title, value: root.value });
        }
    }
}
