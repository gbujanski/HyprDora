pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBt
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var adapter: QsBt.Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool blocked: adapter?.state === QsBt.BluetoothAdapterState.Blocked
    readonly property bool discovering: adapter?.discovering ?? false

    // Unnamed devices are usually anonymous BLE beacons that only clutter the list.
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

    // Agent request awaiting a response: { id, kind, device, value } or null.
    property var request: null

    // Discovery, pairability and the agent run only while the Bluetooth page is open.
    property bool pageOpen: false
    property bool agentReady: false
    property var pairingDevice: null

    readonly property bool poweredOn: adapter?.state === QsBt.BluetoothAdapterState.Enabled

    onPageOpenChanged: applyPageState()
    onAdapterChanged: applyPageState()
    onPoweredOnChanged: applyPageState()

    /** Applies pairable and discovery state from the page state. */
    function applyPageState() {
        if (!adapter || !poweredOn) return;
        adapter.pairable = pageOpen;
        if (adapter.discovering !== pageOpen) adapter.discovering = pageOpen;
    }

    // Right after power-on, BlueZ can reject discovery ("Resource Not Ready") and later end it
    // by itself, so it is retried while the page is open.
    Timer {
        interval: 3000
        repeat: true
        running: root.pageOpen && root.poweredOn && !root.discovering
        onTriggered: root.applyPageState()
    }

    /**
     * Powers the adapter on or off.
     * @param {bool} value  new state
     */
    function setEnabled(value) {
        if (adapter) adapter.enabled = value;
    }

    /**
     * Handles a click on a device: disconnects, connects or starts pairing.
     * @param {BluetoothDevice} device  clicked device
     */
    function activate(device) {
        errorMessage = "";
        if (connector.device === device || pairingDevice === device) return;
        if (device.connected) {
            device.disconnect();
        } else if (device.paired) {
            connectDevice(device);
        } else if (pairingDevice === null) {
            if (!agentReady) {
                errorMessage = I18n.t("bluetooth.agentNotReady");
                return;
            }
            pairingDevice = device;
            device.pair();
        }
    }

    /**
     * Starts a connection attempt with retries.
     * @param {BluetoothDevice} device  device to connect
     */
    function connectDevice(device) {
        if (connector.running) return;
        connector.device = device;
        connector.retriesLeft = 3;
        connector.attempt();
    }

    /**
     * Maps a BlueZ error to a user message.
     * @param {BluetoothDevice} device  affected device
     * @param {string} detail  BlueZ error text
     * @returns {string}
     */
    function connectErrorMessage(device, detail) {
        const text = detail ?? "";
        if (text.includes("key-missing") || text.includes("AuthenticationFailed") || text.includes("AuthenticationRejected"))
            return I18n.t("bluetooth.error.keyRejected", { device: device.name });
        if (text.includes("page-timeout") || text.includes("Host is down") || text.includes("profile-unavailable"))
            return I18n.t("bluetooth.error.noResponse", { device: device.name });
        return I18n.t("bluetooth.error.connectFailed", { device: device.name });
    }

    /**
     * Removes a device's pairing.
     * @param {BluetoothDevice} device  device to forget
     */
    function forget(device) {
        errorMessage = "";
        device.forget();
    }

    /**
     * Returns the status line for a device.
     * @param {BluetoothDevice} device  device to describe
     * @returns {string}
     */
    function statusText(device) {
        if (pairingDevice === device || device.pairing) return I18n.t("bluetooth.status.pairing");
        // After pairing, BlueZ reports Connected for the bare link, before profiles are up.
        if (connector.device === device) return I18n.t("status.connecting");
        switch (device.state) {
        case QsBt.BluetoothDeviceState.Connecting: return I18n.t("status.connecting");
        case QsBt.BluetoothDeviceState.Disconnecting: return I18n.t("bluetooth.status.disconnecting");
        case QsBt.BluetoothDeviceState.Connected:
            return device.batteryAvailable ? I18n.t("bluetooth.status.connectedBattery", { percent: Math.round(device.battery * 100) }) : I18n.t("bluetooth.status.connected");
        }
        return device.paired ? I18n.t("bluetooth.status.paired") : I18n.t("bluetooth.status.available");
    }

    /**
     * Sends the response to the pending agent request.
     * @param {bool} accept  whether to accept
     * @param {string} value  PIN or passkey, if requested
     */
    function answer(accept, value) {
        if (!request) return;
        agent.write(JSON.stringify({ id: request.id, accept: accept, value: value ?? "" }) + "\n");
        request = null;
    }

    /** Cancels pairing, including when only a code is displayed. */
    function cancelPairing() {
        if (request?.kind !== "display") answer(false, "");
        request = null;
        pairingDevice?.cancelPair();
    }

    // Trusting the device allows later connections without a prompt.
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
                root.errorMessage = I18n.t("bluetooth.error.pairFailed", { device: device.name });
            }
        }
    }

    // Device1.Connect is called directly. BluetoothDevice.connect() refuses when Connected is
    // already true, as it is right after pairing, when the link is up but audio profiles are not.
    // This also returns an error code the module does not expose.
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
                console.warn("bluetooth: connection failed:", detail.trim());
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
                    console.warn("bt-agent: unreadable line");
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
                    root.errorMessage = I18n.t("bluetooth.error.agentFailed");
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
