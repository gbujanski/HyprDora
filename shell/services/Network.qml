pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking as QsNet

Singleton {
    id: root

    readonly property var wifiDevice: QsNet.Networking.devices.values.find(d => d.type === QsNet.DeviceType.Wifi) ?? null
    readonly property var activeNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    readonly property bool wifiEnabled: QsNet.Networking.wifiEnabled
    readonly property bool hardwareEnabled: QsNet.Networking.wifiHardwareEnabled
    readonly property bool connected: activeNetwork !== null
    readonly property string ssid: activeNetwork?.name ?? ""
    readonly property real signal: activeNetwork?.signalStrength ?? 0

    // Bieżąca sieć, potem zapisane, potem najsilniejszy sygnał (zaokrąglony,
    // żeby lista nie przeskakiwała przy drobnych wahaniach).
    readonly property var networks: {
        const list = wifiDevice?.networks.values.filter(n => n.name !== "") ?? [];
        const rank = n => (n.connected ? 2 : n.known ? 1 : 0);
        const level = n => Math.round(n.signalStrength * 4);
        return list.sort((a, b) => rank(b) - rank(a) || level(b) - level(a) || a.name.localeCompare(b.name));
    }

    // Skanowanie zużywa energię, więc działa tylko przy otwartej stronie Wi-Fi.
    property bool scanRequested: false
    onScanRequestedChanged: applyScanner()
    onWifiDeviceChanged: applyScanner()

    function applyScanner() {
        if (wifiDevice) wifiDevice.scannerEnabled = scanRequested;
    }

    // Stan formularza i łączenia. SSID sieci, dla której pokazano formularz hasła.
    property string promptSsid: ""
    property bool hiddenPrompt: false
    property string busySsid: ""
    property string errorSsid: ""
    property string errorMessage: ""

    function setWifiEnabled(enabled) {
        QsNet.Networking.wifiEnabled = enabled;
    }

    function needsPassword(network) {
        return network.security !== QsNet.WifiSecurityType.Open
            && network.security !== QsNet.WifiSecurityType.Owe;
    }

    // Formularz obsługuje tylko hasło współdzielone. Pozostałe tryby (firmowe EAP,
    // przestarzałe WEP) trzeba skonfigurować w nmcli lub nmtui.
    function isSupported(network) {
        switch (network.security) {
        case QsNet.WifiSecurityType.Open:
        case QsNet.WifiSecurityType.Owe:
        case QsNet.WifiSecurityType.Sae:
        case QsNet.WifiSecurityType.Wpa2Psk:
        case QsNet.WifiSecurityType.WpaPsk:
            return true;
        default:
            return false;
        }
    }

    function securityLabel(network) {
        switch (network.security) {
        case QsNet.WifiSecurityType.Open: return "Otwarta";
        case QsNet.WifiSecurityType.Owe: return "Otwarta, szyfrowana";
        case QsNet.WifiSecurityType.Sae: return "WPA3";
        case QsNet.WifiSecurityType.Wpa2Psk: return "WPA2";
        case QsNet.WifiSecurityType.WpaPsk: return "WPA";
        case QsNet.WifiSecurityType.Wpa2Eap:
        case QsNet.WifiSecurityType.WpaEap:
        case QsNet.WifiSecurityType.Wpa3SuiteB192: return "Firmowa (EAP)";
        case QsNet.WifiSecurityType.StaticWep:
        case QsNet.WifiSecurityType.DynamicWep: return "WEP";
        default: return "Nieznane";
        }
    }

    function clearError() {
        errorSsid = "";
        errorMessage = "";
    }

    function closePrompt() {
        promptSsid = "";
        hiddenPrompt = false;
    }

    function fail(ssid, message) {
        busySsid = "";
        errorSsid = ssid;
        errorMessage = message;
    }

    // Kliknięcie sieci na liście.
    function activate(network) {
        clearError();
        closePrompt();
        if (network.connected) return;
        if (network.known) {
            connectKnown(network);
        } else if (!isSupported(network)) {
            fail(network.name, "Ten typ zabezpieczeń wymaga konfiguracji przez nmcli lub nmtui.");
        } else if (needsPassword(network)) {
            promptSsid = network.name;
        } else {
            connectNew(network.name, "", false);
        }
    }

    function connectKnown(network) {
        busySsid = network.name;
        knownWatcher.sawConnecting = false;
        knownWatcher.network = network;
        knownTimeout.restart();
        network.connect();
    }

    function connectNew(ssid, password, hidden) {
        if (helper.running) return;
        clearError();
        closePrompt();
        busySsid = ssid;
        helper.pendingRequest = JSON.stringify({ ssid: ssid, password: password, hidden: hidden });
        helper.resultReceived = false;
        helper.running = true;
    }

    function disconnectActive() {
        clearError();
        activeNetwork?.disconnect();
    }

    function forget(network) {
        clearError();
        network.forget();
    }

    function messageForHelper(result) {
        switch (result.reason) {
        case "wrong_password": return "Nieprawidłowe hasło.";
        case "not_found": return "Sieć jest poza zasięgiem.";
        case "timeout": return "Sieć nie odpowiedziała na czas.";
        case "rejected": return "NetworkManager odrzucił ustawienia sieci.";
        case "no_device": return "Nie znaleziono karty Wi-Fi.";
        default: return "Nie udało się połączyć.";
        }
    }

    Process {
        id: helper

        property string pendingRequest: ""
        property bool resultReceived: false

        command: ["python3", "-I", Quickshell.shellPath("scripts/nm-connect.py")]
        stdinEnabled: true

        // Żądanie zawiera hasło: przechodzi tylko przez stdin i nie jest nigdzie zachowywane.
        onStarted: {
            write(pendingRequest + "\n");
            pendingRequest = "";
        }

        stdout: SplitParser {
            onRead: line => {
                helper.resultReceived = true;
                const ssid = root.busySsid;
                try {
                    const result = JSON.parse(line);
                    if (result.ok) root.busySsid = "";
                    else root.fail(ssid, root.messageForHelper(result));
                    console.info("wifi: wynik pomocnika:", result.ok ? "ok" : result.reason,
                        result.activeReason ?? "", result.deviceReason ?? "");
                } catch (e) {
                    root.fail(ssid, "Nie udało się połączyć.");
                }
            }
        }

        onExited: {
            if (!resultReceived && root.busySsid !== "") root.fail(root.busySsid, "Nie udało się połączyć.");
        }
    }

    QtObject {
        id: knownWatcher
        property var network: null
        property bool sawConnecting: false
    }

    Connections {
        target: knownWatcher.network
        ignoreUnknownSignals: true

        function onStateChanged() {
            const network = knownWatcher.network;
            if (network.state === QsNet.NetworkState.Connecting) {
                knownWatcher.sawConnecting = true;
            } else if (network.state === QsNet.NetworkState.Connected) {
                root.finishKnown();
            } else if (network.state === QsNet.NetworkState.Disconnected && knownWatcher.sawConnecting) {
                const badSecret = network.nmReason === QsNet.NMConnectionStateReason.NoSecrets
                    || network.nmReason === QsNet.NMConnectionStateReason.LoginFailed;
                const ssid = network.name;
                root.finishKnown();
                root.fail(ssid, badSecret
                    ? "Zapisane hasło nie działa. Zapomnij sieć i połącz się ponownie."
                    : "Nie udało się połączyć.");
            }
        }
    }

    Timer {
        id: knownTimeout
        interval: 45000
        onTriggered: {
            const ssid = knownWatcher.network?.name ?? "";
            root.finishKnown();
            root.fail(ssid, "Sieć nie odpowiedziała na czas.");
        }
    }

    function finishKnown() {
        knownTimeout.stop();
        knownWatcher.network = null;
        busySsid = "";
    }

    IpcHandler {
        target: "network"

        function describe(): string {
            return JSON.stringify({
                enabled: root.wifiEnabled,
                hardware: root.hardwareEnabled,
                ssid: root.ssid,
                scanning: root.wifiDevice?.scannerEnabled ?? false,
                busy: root.busySsid,
                prompt: root.promptSsid,
                error: root.errorMessage,
                networks: root.networks.map(n => ({
                    name: n.name,
                    signal: Math.round(n.signalStrength * 100),
                    known: n.known,
                    connected: n.connected,
                    security: root.securityLabel(n)
                }))
            });
        }
        // Bez hasła: argumenty wywołania IPC są widoczne w liście procesów.
        function prompt(ssid: string): void { root.clearError(); root.promptSsid = ssid; }
        function connectOpen(ssid: string): void { root.connectNew(ssid, "", false); }
    }
}
