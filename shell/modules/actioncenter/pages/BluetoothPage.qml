import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Column {
    id: page

    spacing: 12

    Component.onCompleted: Bluetooth.pageOpen = true
    Component.onDestruction: {
        Bluetooth.cancelPairing();
        Bluetooth.pageOpen = false;
        Bluetooth.errorMessage = "";
    }

    readonly property var request: Bluetooth.request
    readonly property string requestKind: request?.kind ?? ""
    readonly property bool needsInput: requestKind === "pin" || requestKind === "passkey"

    onRequestChanged: {
        codeField.clear();
        // Read directly from the request, since dependent bindings may still be stale here.
        const kind = request?.kind;
        if (kind === "pin" || kind === "passkey") Qt.callLater(() => codeField.focusInput());
        else page.forceActiveFocus();
    }

    function submitCode() {
        if (codeField.text !== "") Bluetooth.answer(true, codeField.text);
    }

    Item {
        width: parent.width
        height: 26

        Label {
            anchors.verticalCenter: parent.verticalCenter
            font.weight: Font.Medium
            text: !Bluetooth.hasAdapter ? I18n.t("bluetooth.noAdapterLong")
                : Bluetooth.blocked ? I18n.t("bluetooth.blocked") : "Bluetooth"
            color: Bluetooth.hasAdapter && !Bluetooth.blocked ? Theme.foreground : Theme.warning
        }

        Switch {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            checked: Bluetooth.enabled
            active: Bluetooth.hasAdapter && !Bluetooth.blocked
            onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
        }
    }

    ErrorBanner {
        width: parent.width
        text: Bluetooth.errorMessage
    }

    // Kept outside the lists so a discovery refresh cannot interrupt it.
    Rectangle {
        width: parent.width
        visible: page.request !== null
        height: requestLayout.implicitHeight + 20
        radius: Theme.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.accent

        Column {
            id: requestLayout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 10
            }
            spacing: 8

            Label {
                width: parent.width
                elide: Text.ElideRight
                font.weight: Font.Medium
                text: I18n.t("bluetooth.pairing", { device: page.request?.device ?? "" })
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.muted
                text: {
                    switch (page.requestKind) {
                    case "confirm": return I18n.t("bluetooth.prompt.confirm");
                    case "display": return I18n.t("bluetooth.prompt.display");
                    case "pin": return I18n.t("bluetooth.prompt.pin");
                    case "passkey": return I18n.t("bluetooth.prompt.passkey");
                    case "authorize": return I18n.t("bluetooth.prompt.authorize");
                    case "authorize-service": return I18n.t("bluetooth.prompt.authorizeService");
                    default: return "";
                    }
                }
            }

            Label {
                visible: page.requestKind === "confirm" || page.requestKind === "display"
                text: page.request?.value ?? ""
                font.pixelSize: 24
                font.weight: Font.DemiBold
                font.letterSpacing: 2
            }

            TextField {
                id: codeField
                width: parent.width
                visible: page.needsInput
                placeholder: page.requestKind === "pin" ? "PIN" : I18n.t("bluetooth.code")
                onAccepted: page.submitCode()
                onCancelled: Bluetooth.cancelPairing()
            }

            Row {
                anchors.right: parent.right
                spacing: 6

                TextButton {
                    text: page.requestKind === "display" || page.needsInput ? I18n.t("common.cancel") : I18n.t("bluetooth.reject")
                    onClicked: Bluetooth.cancelPairing()
                }

                TextButton {
                    visible: page.requestKind !== "display"
                    primary: true
                    active: !page.needsInput || codeField.text !== ""
                    text: page.needsInput ? "OK" : page.requestKind === "confirm" ? I18n.t("bluetooth.confirm") : I18n.t("bluetooth.allow")
                    onClicked: {
                        if (page.needsInput) page.submitCode();
                        else Bluetooth.answer(true, "");
                    }
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: Bluetooth.enabled && Bluetooth.pairedDevices.length > 0

        SectionTitle { text: I18n.t("section.paired") }

        Repeater {
            model: ScriptModel {
                values: Bluetooth.pairedDevices
            }

            BluetoothRow {
                required property var modelData
                width: parent.width
                device: modelData
            }
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: Bluetooth.enabled

        SectionTitle { text: I18n.t("section.available") }

        Label {
            visible: Bluetooth.discoveredDevices.length === 0
            text: Bluetooth.discovering ? I18n.t("bluetooth.searching") : I18n.t("bluetooth.noneFound")
            color: Theme.muted
            topPadding: 4
            bottomPadding: 4
        }

        Repeater {
            model: ScriptModel {
                values: Bluetooth.discoveredDevices
            }

            BluetoothRow {
                required property var modelData
                width: parent.width
                device: modelData
            }
        }
    }
}
