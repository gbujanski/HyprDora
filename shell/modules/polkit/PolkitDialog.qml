import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Polkit
import qs.config
import qs.components
import qs.services

// Password prompt for administrator actions: the session's polkit agent. It only collects the password;
// polkit hands it to its own root helper, which checks it with PAM and reports to polkitd, so nothing here
// can grant an action. The window shows polkit's own message and the action id, unchanged.
// A dev shell runs beside the session's own shell, and a session has one agent, so it does not register.
Scope {
    id: root

    LazyLoader {
        active: !Quickshell.env("HYPRDORA_SHELL")

        Scope {
            PolkitAgent {
                id: agent
            }

            PolkitWindow {
                agent: agent
            }
        }
    }

    component PolkitWindow: Scope {
        id: host

        required property var agent
        readonly property var flow: agent.flow

        LazyLoader {
            active: host.agent.isActive && host.flow !== null

            PanelWindow {
                id: window

                property bool capsLock: false

                /** Sends the typed password and clears the field. */
                function submit() {
                    if (!host.flow?.isResponseRequired)
                        return;
                    host.flow.submit(field.text);
                    field.clear();
                }

                /** Cancels the request; the program that asked gets a refusal. */
                function cancel() {
                    field.clear();
                    host.flow?.cancelAuthenticationRequest();
                }

                screen: Panels.focusedScreen()
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: Qt.rgba(0, 0, 0, 0.45)
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "hyprdora-polkit"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                Component.onCompleted: {
                    Panels.closeActionCenter();
                    field.focusInput();
                    capsReader.running = true;
                }

                // Caps Lock state is read from Hyprland while the window is open.
                Timer {
                    interval: 500
                    repeat: true
                    running: true
                    onTriggered: {
                        if (!capsReader.running)
                            capsReader.running = true;
                    }
                }

                Process {
                    id: capsReader
                    command: ["hyprctl", "-j", "devices"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            try {
                                window.capsLock = JSON.parse(text).keyboards.some(k => k.main && k.capsLock);
                            } catch (e) {}
                        }
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(440, parent.width - 2 * Theme.panelMargin)
                    height: content.implicitHeight + 2 * Theme.panelPadding
                    radius: Theme.panelRadius
                    color: Theme.background
                    border.width: 1
                    border.color: Theme.surface

                    Column {
                        id: content

                        anchors {
                            fill: parent
                            margins: Theme.panelPadding
                        }
                        spacing: 10

                        Label {
                            text: I18n.t("polkit.title")
                            font.pixelSize: Theme.fontSizeTitle
                            font.weight: Font.DemiBold
                        }

                        Label {
                            width: parent.width
                            text: host.flow?.message ?? ""
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            width: parent.width
                            text: host.flow?.actionId ?? ""
                            color: Theme.muted
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideMiddle
                        }

                        TextField {
                            id: field

                            width: parent.width
                            placeholder: I18n.t("polkit.password")
                            secret: !(host.flow?.responseVisible ?? false)
                            enabled: host.flow?.isResponseRequired ?? false

                            onAccepted: window.submit()
                            onCancelled: window.cancel()
                        }

                        Label {
                            width: parent.width
                            visible: text !== ""
                            wrapMode: Text.WordWrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: host.flow?.failed || host.flow?.supplementaryIsError ? Theme.error : Theme.warning
                            text: host.flow?.failed ? I18n.t("polkit.wrongPassword") : host.flow?.supplementaryIsError ? host.flow.supplementaryMessage : window.capsLock ? I18n.t("polkit.capsLock") : ""
                        }

                        Row {
                            anchors.right: parent.right
                            spacing: 6

                            TextButton {
                                text: I18n.t("common.cancel")
                                onClicked: window.cancel()
                            }

                            TextButton {
                                text: I18n.t("polkit.authenticate")
                                primary: true
                                active: host.flow?.isResponseRequired ?? false
                                onClicked: window.submit()
                            }
                        }
                    }
                }
            }
        }
    }
}
