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
        // Bezpośrednio z prośby: powiązania zależne mogą być tu jeszcze nieaktualne.
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
            text: !Bluetooth.hasAdapter ? "Brak adaptera Bluetooth"
                : Bluetooth.blocked ? "Bluetooth zablokowany" : "Bluetooth"
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

    // Karta leży poza listami: odświeżenie wyszukiwania nie może jej przerwać.
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
                text: `Parowanie: ${page.request?.device ?? ""}`
            }

            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.muted
                text: {
                    switch (page.requestKind) {
                    case "confirm": return "Czy ten sam kod widać na urządzeniu?";
                    case "display": return "Wpisz ten kod na urządzeniu:";
                    case "pin": return "Podaj PIN urządzenia.";
                    case "passkey": return "Podaj kod widoczny na urządzeniu (do 6 cyfr).";
                    case "authorize": return "Zezwolić na sparowanie?";
                    case "authorize-service": return "Urządzenie chce użyć usługi. Zezwolić?";
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
                placeholder: page.requestKind === "pin" ? "PIN" : "Kod"
                onAccepted: page.submitCode()
                onCancelled: Bluetooth.cancelPairing()
            }

            Row {
                anchors.right: parent.right
                spacing: 6

                TextButton {
                    text: page.requestKind === "display" || page.needsInput ? "Anuluj" : "Odrzuć"
                    onClicked: Bluetooth.cancelPairing()
                }

                TextButton {
                    visible: page.requestKind !== "display"
                    primary: true
                    active: !page.needsInput || codeField.text !== ""
                    text: page.needsInput ? "OK" : page.requestKind === "confirm" ? "Potwierdź" : "Zezwól"
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

        SectionTitle { text: "SPAROWANE" }

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

        SectionTitle { text: "DOSTĘPNE" }

        Label {
            visible: Bluetooth.discoveredDevices.length === 0
            text: Bluetooth.discovering ? "Szukanie urządzeń…" : "Nie znaleziono urządzeń"
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
