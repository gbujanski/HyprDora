import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// The lock screen, styled like the login screen: black, a ">:" prompt and a blinking block cursor; the password
// is not shown. A wrong password flashes the prompt red, Caps Lock turns it amber, and /help lists commands.
// The prompt is on the screen that had focus when locking; other screens stay black.
Scope {
    id: root

    // The login screen's size, so the two look the same.
    readonly property int terminalFontSize: 16

    property var promptScreen: null

    Connections {
        target: Lock
        function onActiveChanged() {
            if (Lock.active)
                root.promptScreen = Panels.focusedScreen();
        }
    }

    // Always present: hiding it in a loader could drop the lock if the loader went away.
    WlSessionLock {
        id: sessionLock

        locked: Lock.active

        WlSessionLockSurface {
            id: surface

            color: "black"

            Item {
                id: content

                property bool failed: false
                property bool capsLock: false
                property bool helpShown: false
                readonly property bool hasPrompt: surface.screen === root.promptScreen || root.promptScreen === null
                readonly property color promptColor: failed ? Theme.error : capsLock ? Theme.warning : Theme.accent

                readonly property var commands: ["/help", "/suspend", "/reboot", "/poweroff"]

                /**
                 * Runs a command typed at the prompt.
                 * @param {string} command  one of commands
                 */
                function run(command) {
                    switch (command.slice(1)) {
                    case "help":
                        helpShown = !helpShown;
                        break;
                    case "suspend":
                        Quickshell.execDetached(["systemctl", "suspend"]);
                        break;
                    case "reboot":
                        Quickshell.execDetached(["systemctl", "reboot"]);
                        break;
                    case "poweroff":
                        Quickshell.execDetached(["systemctl", "poweroff"]);
                        break;
                    }
                }

                anchors.fill: parent

                Connections {
                    target: Lock
                    function onFailuresChanged() {
                        content.failed = true;
                        failTimer.restart();
                    }
                }

                Timer {
                    id: failTimer
                    interval: 500
                    onTriggered: content.failed = false
                }

                // Caps Lock state is read from Hyprland after each key.
                Process {
                    id: capsReader
                    command: ["hyprctl", "-j", "devices"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                content.capsLock = JSON.parse(text).keyboards.some(k => k.main && k.capsLock);
                            } catch (e) {}
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    visible: content.hasPrompt
                    spacing: 10

                    Text {
                        text: ">:"
                        color: content.promptColor
                        font.family: "monospace"
                        font.pixelSize: root.terminalFontSize
                        font.bold: true
                    }

                    TextInput {
                        id: input

                        width: 300
                        color: content.promptColor
                        font.family: "monospace"
                        font.pixelSize: root.terminalFontSize
                        // Nothing typed is shown, commands included, so no part of a password can ever appear.
                        echoMode: TextInput.NoEcho
                        focus: content.hasPrompt
                        readOnly: Lock.checking

                        cursorDelegate: Rectangle {
                            id: cursorBlock
                            width: 8
                            height: 32
                            color: content.promptColor

                            Timer {
                                interval: 500
                                running: true
                                repeat: true
                                onTriggered: cursorBlock.visible = !cursorBlock.visible
                            }
                        }

                        // Caps Lock turns on when pressed but off only when released, so both are read.
                        Keys.onPressed: event => {
                            if (!capsReader.running)
                                capsReader.running = true;
                        }
                        Keys.onReleased: event => {
                            if (!capsReader.running)
                                capsReader.running = true;
                        }

                        onAccepted: {
                            // Only an exact command runs; any other text, even one starting with a slash, is a password.
                            if (content.commands.includes(text))
                                content.run(text);
                            else
                                Lock.tryUnlock(text);
                            text = "";
                        }

                        Component.onCompleted: {
                            forceActiveFocus();
                            capsReader.running = true;
                        }
                    }
                }

                Column {
                    anchors {
                        bottom: parent.bottom
                        bottomMargin: 20
                        horizontalCenter: parent.horizontalCenter
                    }
                    visible: content.hasPrompt && content.helpShown
                    spacing: 6

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: content.promptColor
                        font.family: "monospace"
                        font.pixelSize: root.terminalFontSize
                        text: "SYSTEM CMDS:   /help   |   /poweroff   |   /reboot   |   /suspend"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: content.promptColor
                        font.family: "monospace"
                        font.pixelSize: root.terminalFontSize
                        text: "RECOVERY:   Ctrl+Alt+F3 console   |   hyprdora -h   |   hyprdora rollback"
                    }
                }
            }
        }
    }
}
