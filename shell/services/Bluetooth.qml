pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBt
import Quickshell.Io

Singleton {
    id: root

    readonly property var adapter: QsBt.Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool blocked: adapter?.state === QsBt.BluetoothAdapterState.Blocked
    readonly property bool discovering: adapter?.discovering ?? false

    // Urządzenia bez nazwy to zwykle anonimowe nadajniki BLE, które tylko zaśmiecają listę.
    readonly property var devices: (adapter?.devices.values ?? [])
        .filter(d => d.paired || d.deviceName !== "")
    readonly property var pairedDevices: devices
        .filter(d => d.paired)
        .sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name))
    readonly property var discoveredDevices: devices
        .filter(d => !d.paired)
        .sort((a, b) => a.name.localeCompare(b.name))
    readonly property var connectedDevices: pairedDevices.filter(d => d.connected)

    property string errorMessage: ""

    // Prośba agenta wymagająca reakcji: { id, kind, device, value } albo null.
    property var request: null

    // Strona Bluetooth: wyszukiwanie, widoczność dla parowania i agent działają tylko wtedy.
    property bool pageOpen: false
    property bool agentReady: false
    property var pairingDevice: null

    readonly property bool poweredOn: adapter?.state === QsBt.BluetoothAdapterState.Enabled

    onPageOpenChanged: applyPageState()
    onAdapterChanged: applyPageState()
    onPoweredOnChanged: applyPageState()

    function applyPageState() {
        if (!adapter || !poweredOn) return;
        adapter.pairable = pageOpen;
        if (adapter.discovering !== pageOpen) adapter.discovering = pageOpen;
    }

    // Tuż po włączeniu BlueZ może odrzucić start wyszukiwania ("Resource Not Ready"),
    // a później zakończyć je sam. Przy otwartej stronie ponawiamy próbę.
    Timer {
        interval: 3000
        repeat: true
        running: root.pageOpen && root.poweredOn && !root.discovering
        onTriggered: root.applyPageState()
    }

    function setEnabled(value) {
        if (adapter) adapter.enabled = value;
    }

    function activate(device) {
        errorMessage = "";
        if (connector.device === device || pairingDevice === device) return;
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            connectDevice(device);
        } else if (pairingDevice === null) {
            if (!agentReady) {
                errorMessage = "Agent parowania nie jest gotowy. Spróbuj za chwilę.";
                return;
            }
            pairingDevice = device;
            device.pair();
        }
    }

    function connectDevice(device) {
        if (connector.running) return;
        connector.device = device;
        connector.retriesLeft = 3;
        connector.attempt();
    }

    // Tekst dla kodów błędów zwracanych przez BlueZ.
    function connectErrorMessage(device, detail) {
        const text = detail ?? "";
        if (text.includes("key-missing") || text.includes("AuthenticationFailed") || text.includes("AuthenticationRejected"))
            return `${device.name}: urządzenie odrzuciło klucz parowania. Spróbuj ponownie, a jeśli to się powtórzy, zapomnij je i sparuj od nowa.`;
        if (text.includes("page-timeout") || text.includes("Host is down") || text.includes("profile-unavailable"))
            return `${device.name}: nie odpowiada. Sprawdź, czy jest włączone i nie jest zajęte przez inne urządzenie.`;
        return `Nie udało się połączyć: ${device.name}.`;
    }

    function forget(device) {
        errorMessage = "";
        device.forget();
    }

    function statusText(device) {
        if (pairingDevice === device || device.pairing) return "Parowanie…";
        // Po parowaniu BlueZ zgłasza Connected już dla samego łącza, jeszcze bez profili.
        if (connector.device === device) return "Łączenie…";
        switch (device.state) {
        case QsBt.BluetoothDeviceState.Connecting: return "Łączenie…";
        case QsBt.BluetoothDeviceState.Disconnecting: return "Rozłączanie…";
        case QsBt.BluetoothDeviceState.Connected:
            return device.batteryAvailable ? `Połączono, bateria ${Math.round(device.battery * 100)}%` : "Połączono";
        }
        return device.paired ? "Sparowano" : "Dostępne";
    }

    function answer(accept, value) {
        if (!request) return;
        agent.write(JSON.stringify({ id: request.id, accept: accept, value: value ?? "" }) + "\n");
        request = null;
    }

    // Anulowanie z karty parowania, także gdy tylko wyświetlamy kod.
    function cancelPairing() {
        if (request?.kind !== "display") answer(false, "");
        request = null;
        pairingDevice?.cancelPair();
    }

    // Koniec parowania: zaufanie pozwala później łączyć się bez pytania.
    Connections {
        target: root.pairingDevice
        ignoreUnknownSignals: true

        function onPairingChanged() {
            const device = root.pairingDevice;
            if (device.pairing) return;
            root.pairingDevice = null;
            root.request = null;
            if (device.paired) {
                device.trusted = true;
                root.connectDevice(device);
            } else {
                root.errorMessage = `Nie udało się sparować: ${device.name}.`;
            }
        }
    }

    // Device1.Connect wywołujemy bezpośrednio. BluetoothDevice.connect() odmawia, gdy
    // Connected jest już prawdą, a tak jest zaraz po parowaniu: łącze działa, ale profile
    // audio nie są uruchomione. Dostajemy też kod błędu, którego moduł nie udostępnia.
    Process {
        id: connector

        property var device: null
        property int retriesLeft: 0

        function attempt() {
            command = ["gdbus", "call", "--system", "--dest", "org.bluez",
                "--object-path", device.dbusPath,
                "--method", "org.bluez.Device1.Connect", "--timeout", "30"];
            running = true;
        }

        stderr: StdioCollector {
            id: connectorErrors
        }

        onExited: exitCode => {
            const current = device;
            if (!current) return;
            const detail = connectorErrors.text;
            const transient = detail.includes("InProgress") || detail.includes("busy");
            if (exitCode !== 0 && transient && retriesLeft > 0) {
                retriesLeft--;
                retryTimer.restart();
                return;
            }
            device = null;
            if (exitCode !== 0) {
                root.errorMessage = root.connectErrorMessage(current, detail);
                console.warn("bluetooth: łączenie nieudane:", detail.trim());
            }
        }
    }

    Timer {
        id: retryTimer
        interval: 2000
        onTriggered: if (connector.device) connector.attempt()
    }

    Process {
        id: agent

        command: ["python3", "-I", Quickshell.shellPath("scripts/bt-agent.py")]
        running: root.pageOpen || root.pairingDevice !== null
        stdinEnabled: true

        onRunningChanged: {
            if (!running) {
                root.agentReady = false;
                root.request = null;
            }
        }

        stdout: SplitParser {
            onRead: line => {
                let message;
                try {
                    message = JSON.parse(line);
                } catch (e) {
                    console.warn("bt-agent: nieczytelna linia");
                    return;
                }
                switch (message.event) {
                case "ready":
                    root.agentReady = true;
                    break;
                case "request":
                    root.request = message;
                    break;
                case "display":
                    root.request = { kind: "display", device: message.device, value: message.value };
                    break;
                case "cancel":
                    root.request = null;
                    break;
                case "error":
                    root.errorMessage = "Nie udało się uruchomić agenta parowania.";
                    console.warn("bt-agent:", message.detail);
                    break;
                }
            }
        }
    }

    IpcHandler {
        target: "bluetooth"

        function describe(): string {
            return JSON.stringify({
                adapter: root.adapter?.name ?? null,
                enabled: root.enabled,
                discovering: root.discovering,
                pairable: root.adapter?.pairable ?? null,
                agentReady: root.agentReady,
                connecting: connector.device?.name ?? null,
                request: root.request ? root.request.kind : null,
                error: root.errorMessage,
                paired: root.pairedDevices.map(d => d.name),
                discovered: root.discoveredDevices.length
            });
        }
        function setEnabled(value: bool): void { root.setEnabled(value); }
        function connectDevice(address: string): bool {
            const device = root.devices.find(d => d.address === address);
            if (device) root.connectDevice(device);
            return device !== undefined;
        }
        function answer(accept: bool, value: string): void { root.answer(accept, value); }
    }
}
