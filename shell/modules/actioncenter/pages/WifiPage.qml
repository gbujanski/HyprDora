import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Column {
    id: page

    signal scrollToTop()

    spacing: 12

    Component.onCompleted: Network.scanRequested = true
    Component.onDestruction: {
        Network.scanRequested = false;
        Network.closePrompt();
        Network.clearError();
    }

    readonly property bool formVisible: Network.promptSsid !== "" || Network.hiddenPrompt

    onFormVisibleChanged: {
        if (formVisible) {
            scrollToTop();
            Qt.callLater(() => Network.hiddenPrompt ? ssidField.focusInput() : passwordField.focusInput());
        } else {
            ssidField.clear();
            passwordField.clear();
            // Fokus wraca na stronę, żeby Esc nadal działał.
            page.forceActiveFocus();
        }
    }

    function cancelForm() {
        Network.closePrompt();
    }

    function submitForm() {
        if (!canSubmit) return;
        const ssid = Network.hiddenPrompt ? ssidField.text.trim() : Network.promptSsid;
        const password = passwordField.text;
        const hidden = Network.hiddenPrompt;
        passwordField.clear();
        Network.connectNew(ssid, password, hidden);
    }

    // WPA wymaga od 8 do 63 znaków. Ukryta sieć może nie mieć hasła.
    readonly property bool passwordValid: {
        const length = passwordField.text.length;
        if (Network.hiddenPrompt && length === 0) return true;
        return length >= 8 && length <= 63;
    }
    readonly property bool canSubmit: passwordValid
        && (!Network.hiddenPrompt || ssidField.text.trim() !== "")

    Item {
        width: parent.width
        height: 26

        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: !Network.hardwareEnabled ? "Wi-Fi zablokowane sprzętowo" : "Wi-Fi"
            color: Network.hardwareEnabled ? Theme.foreground : Theme.warning
            font.weight: Font.Medium
        }

        Switch {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            checked: Network.wifiEnabled
            active: Network.hardwareEnabled
            onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
        }
    }

    ErrorBanner {
        width: parent.width
        text: Network.errorMessage === "" ? ""
            : Network.errorSsid !== "" ? `${Network.errorSsid}: ${Network.errorMessage}` : Network.errorMessage
    }

    // Formularz leży poza listą: odświeżenie skanu nie może skasować wpisywanego hasła.
    Rectangle {
        width: parent.width
        visible: page.formVisible
        height: form.implicitHeight + 20
        radius: Theme.radius
        color: "transparent"
        border.width: 1
        border.color: Theme.surface

        Column {
            id: form
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
                text: Network.hiddenPrompt ? "Sieć ukryta" : `Hasło do sieci ${Network.promptSsid}`
            }

            TextField {
                id: ssidField
                width: parent.width
                visible: Network.hiddenPrompt
                placeholder: "Nazwa sieci"
                onAccepted: page.submitForm()
                onCancelled: page.cancelForm()
            }

            TextField {
                id: passwordField
                width: parent.width
                secret: true
                placeholder: Network.hiddenPrompt ? "Hasło (puste, gdy sieć otwarta)" : "Hasło"
                onAccepted: page.submitForm()
                onCancelled: page.cancelForm()
            }

            Row {
                anchors.right: parent.right
                spacing: 6

                TextButton {
                    text: "Anuluj"
                    onClicked: page.cancelForm()
                }

                TextButton {
                    text: "Połącz"
                    primary: true
                    active: page.canSubmit
                    onClicked: page.submitForm()
                }
            }
        }
    }

    Column {
        width: parent.width
        spacing: 2
        visible: Network.wifiEnabled

        SectionTitle { text: "SIECI" }

        Label {
            visible: Network.networks.length === 0
            text: "Szukanie sieci…"
            color: Theme.muted
            topPadding: 4
            bottomPadding: 4
        }

        // ScriptModel zachowuje wiersze przy zmianie kolejności i odświeżaniu sygnału.
        Repeater {
            model: ScriptModel {
                values: Network.networks
            }

            WifiRow {
                required property var modelData
                width: parent.width
                network: modelData
            }
        }

        ListRow {
            width: parent.width
            text: "Połącz z siecią ukrytą"
            trailingIcon: Icons.plus
            onClicked: {
                Network.clearError();
                Network.promptSsid = "";
                Network.hiddenPrompt = true;
            }
        }
    }
}
