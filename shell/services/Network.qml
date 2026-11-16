pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking as QsNet
import qs.config

Singleton {
    id: root

    readonly property var wifiDevice: QsNet.Networking.devices.values.find(d => d.type === QsNet.DeviceType.Wifi) ?? null
    readonly property var activeNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    readonly property bool wifiEnabled: QsNet.Networking.wifiEnabled
    readonly property bool hardwareEnabled: QsNet.Networking.wifiHardwareEnabled
    readonly property bool connected: activeNetwork !== null
    readonly property string ssid: activeNetwork?.name ?? ""
    readonly property real signal: activeNetwork?.signalStrength ?? 0

    // Current network, then saved ones, then strongest signal (rounded, so the list does not
    // jump on small fluctuations).
    readonly property var networks: {
        const list = wifiDevice?.networks.values.filter(n => n.name !== "") ?? [];
        const rank = n => (n.connected ? 2 : n.known ? 1 : 0);
        const level = n => Math.round(n.signalStrength * 4);
        return list.sort((a, b) => rank(b) - rank(a) || level(b) - level(a) || a.name.localeCompare(b.name));
    }

    // Scanning uses power, so it runs only while the Wi-Fi page is open.
    property bool scanRequested: false
    readonly property bool scanning: wifiDevice?.scannerEnabled ?? false
    // Quickshell.Networking knows only Wi-Fi, so a wired connection is read from nmcli.
    property bool wiredConnected: false

    // Metered ("taryfowe") connections: the system downloads nothing in the background on them. NetworkManager
    // guesses it for an Android hotspot; any saved network can be marked by hand, since a router with a SIM
    // card does not say so. metered is the current connection's state; savedMetered holds each saved Wi-Fi
    // network's own setting by SSID: { uuid, value: "yes" | "no" | "unknown" }.
    property bool metered: false
    property var savedMetered: ({})

    /**
     * Whether a network counts as metered: its own setting, or NetworkManager's guess while connected.
     * @param {object} network  Wi-Fi network
     * @returns {bool}
     */
    function isMetered(network) {
        const value = savedMetered[network.name]?.value ?? "unknown";
        if (value !== "unknown")
            return value === "yes";
        return network.connected && metered;
    }

    /**
     * Marks a saved network as metered or not, for good.
     * @param {object} network  saved Wi-Fi network
     * @param {bool} on  metered
     */
    function setMetered(network, on) {
        const saved = savedMetered[network.name];
        if (!saved)
            return;
        savedMetered = Object.assign({}, savedMetered, {
            [network.name]: {
                uuid: saved.uuid,
                value: on ? "yes" : "no"
            }
        });
        meteredWriter.command = ["nmcli", "connection", "modify", saved.uuid, "connection.metered", on ? "yes" : "no"];
        meteredWriter.running = true;
    }
    onScanRequestedChanged: applyScanner()
    onWifiDeviceChanged: applyScanner()

    /** Starts or stops scanning according to scanRequested. */
    function applyScanner() {
        if (wifiDevice)
            wifiDevice.scannerEnabled = scanRequested;
    }

    // Form and connection state. promptSsid is the network whose password form is shown.
    property string promptSsid: ""
    property bool hiddenPrompt: false
    property string busySsid: ""
    property string errorSsid: ""
    property string errorMessage: ""

    /**
     * Turns Wi-Fi on or off.
     * @param {bool} enabled  new state
     */
    function setWifiEnabled(enabled) {
        QsNet.Networking.wifiEnabled = enabled;
    }

    /**
     * Tells whether a network requires a password.
     * @param {WifiNetwork} network  network to check
     * @returns {bool}
     */
    function needsPassword(network) {
        return network.security !== QsNet.WifiSecurityType.Open && network.security !== QsNet.WifiSecurityType.Owe;
    }

    /**
     * Tells whether the form can handle a network's security. Only shared-key modes are supported; EAP and WEP need nmcli or nmtui.
     * @param {WifiNetwork} network  network to check
     * @returns {bool}
     */
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

    /**
     * Returns a readable security type.
     * @param {WifiNetwork} network  network to describe
     * @returns {string}
     */
    function securityLabel(network) {
        switch (network.security) {
        case QsNet.WifiSecurityType.Open:
            return I18n.t("wifi.security.open");
        case QsNet.WifiSecurityType.Owe:
            return I18n.t("wifi.security.owe");
        case QsNet.WifiSecurityType.Sae:
            return "WPA3";
        case QsNet.WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case QsNet.WifiSecurityType.WpaPsk:
            return "WPA";
        case QsNet.WifiSecurityType.Wpa2Eap:
        case QsNet.WifiSecurityType.WpaEap:
        case QsNet.WifiSecurityType.Wpa3SuiteB192:
            return I18n.t("wifi.security.enterprise");
        case QsNet.WifiSecurityType.StaticWep:
        case QsNet.WifiSecurityType.DynamicWep:
            return "WEP";
        default:
            return I18n.t("wifi.security.unknown");
        }
    }

    /** Clears the connection error. */
    function clearError() {
        errorSsid = "";
        errorMessage = "";
    }

    /** Closes the password form. */
    function closePrompt() {
        promptSsid = "";
        hiddenPrompt = false;
    }

    /**
     * Ends a connection attempt with an error.
     * @param {string} ssid  affected network
     * @param {string} message  user message
     */
    function fail(ssid, message) {
        busySsid = "";
        errorSsid = ssid;
        errorMessage = message;
    }

    /**
     * Handles a click on a network in the list.
     * @param {WifiNetwork} network  clicked network
     */
    function activate(network) {
        clearError();
        closePrompt();
        if (network.connected)
            return;
        if (network.known) {
            connectKnown(network);
        } else if (!isSupported(network)) {
            fail(network.name, I18n.t("wifi.error.unsupported"));
        } else if (needsPassword(network)) {
            promptSsid = network.name;
        } else {
            connectNew(network.name, "", false);
        }
    }

    /**
     * Connects to a saved network and watches the result.
     * @param {WifiNetwork} network  saved network
     */
    function connectKnown(network) {
        busySsid = network.name;
        knownWatcher.sawConnecting = false;
        knownWatcher.network = network;
        knownTimeout.restart();
        network.connect();
    }

    /**
     * Connects to a new network through the helper.
     * @param {string} ssid  network name
     * @param {string} password  password, may be empty
     * @param {bool} hidden  whether the network is hidden
     */
    function connectNew(ssid, password, hidden) {
        if (helper.running)
            return;
        clearError();
        closePrompt();
        busySsid = ssid;
        helper.pendingRequest = JSON.stringify({
            ssid: ssid,
            password: password,
            hidden: hidden
        });
        helper.resultReceived = false;
        helper.running = true;
    }

    /** Disconnects from the current network. */
    function disconnectActive() {
        clearError();
        activeNetwork?.disconnect();
    }

    /**
     * Removes a saved network.
     * @param {WifiNetwork} network  network to forget
     */
    function forget(network) {
        clearError();
        network.forget();
    }

    /**
     * Maps a helper result to a user message.
     * @param {object} result  parsed helper output
     * @returns {string}
     */
    function messageForHelper(result) {
        switch (result.reason) {
        case "wrong_password":
            return I18n.t("wifi.error.wrongPassword");
        case "not_found":
            return I18n.t("wifi.error.notFound");
        case "timeout":
            return I18n.t("wifi.error.timeout");
        case "rejected":
            return I18n.t("wifi.error.rejected");
        case "no_device":
            return I18n.t("wifi.error.noDevice");
        default:
            return I18n.t("wifi.error.failed");
        }
    }

    Process {
        id: helper

        property string pendingRequest: ""
        property bool resultReceived: false

        command: ["python3", "-I", Quickshell.shellPath("scripts/nm-connect.py")]
        stdinEnabled: true

        // The request contains the password: it goes only through stdin and is never stored.
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
                    if (result.ok)
                        root.busySsid = "";
                    else
                        root.fail(ssid, root.messageForHelper(result));
                    console.info("wifi: helper result:", result.ok ? "ok" : result.reason, result.activeReason ?? "", result.deviceReason ?? "");
                } catch (e) {
                    root.fail(ssid, I18n.t("wifi.error.failed"));
                }
            }
        }

        onExited: {
            if (!resultReceived && root.busySsid !== "")
                root.fail(root.busySsid, I18n.t("wifi.error.failed"));
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
                const badSecret = network.nmReason === QsNet.NMConnectionStateReason.NoSecrets || network.nmReason === QsNet.NMConnectionStateReason.LoginFailed;
                const ssid = network.name;
                root.finishKnown();
                root.fail(ssid, badSecret ? I18n.t("wifi.error.savedPassword") : I18n.t("wifi.error.failed"));
            }
        }
    }

    Timer {
        id: knownTimeout
        interval: 45000
        onTriggered: {
            const ssid = knownWatcher.network?.name ?? "";
            root.finishKnown();
            root.fail(ssid, I18n.t("wifi.error.timeout"));
        }
    }

    /** Stops watching a saved-network connection. */
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
                metered: root.metered,
                savedMetered: root.savedMetered,
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
        // No password here: IPC call arguments are visible in the process list.
        function prompt(ssid: string): void {
            root.clearError();
            root.promptSsid = ssid;
        }
        function connectOpen(ssid: string): void {
            root.connectNew(ssid, "", false);
        }
    }

    Process {
        id: wiredCheck
        command: ["env", "LC_ALL=C", "nmcli", "-t", "-f", "TYPE,STATE", "device"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.wiredConnected = text.split("\n").some(line => line === "ethernet:connected")
        }
    }

    Process {
        // setpriv ends the monitor together with the shell, so a restart leaves no stray process.
        command: ["setpriv", "--pdeathsig", "TERM", "env", "LC_ALL=C", "nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: wiredDelay.restart()
        }
    }

    Timer {
        id: wiredDelay
        interval: 500
        onTriggered: {
            if (!wiredCheck.running)
                wiredCheck.running = true;
            if (!meteredCheck.running)
                meteredCheck.running = true;
        }
    }

    // NetworkManager's overall state (1 yes and 3 guessed yes are metered), then each saved Wi-Fi network as
    // "uuid<TAB>metered<TAB>ssid".
    Process {
        id: meteredCheck
        running: true
        command: ["sh", "-c", `export LC_ALL=C
            busctl get-property org.freedesktop.NetworkManager /org/freedesktop/NetworkManager org.freedesktop.NetworkManager Metered 2>/dev/null
            nmcli -t -f UUID,TYPE connection show | while IFS=: read -r uuid type; do
                [ "$type" = 802-11-wireless ] || continue
                printf '%s\t%s\t%s\n' "$uuid" "$(nmcli -g connection.metered connection show "$uuid")" "$(nmcli -g 802-11-wireless.ssid connection show "$uuid")"
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.metered = /^u [13]$/.test((lines[0] ?? "").trim());
                const saved = {};
                for (const line of lines.slice(1)) {
                    const [uuid, value, ssid] = line.split("\t");
                    if (uuid && ssid)
                        saved[ssid] = {
                            uuid: uuid,
                            value: value || "unknown"
                        };
                }
                root.savedMetered = saved;
            }
        }
    }

    Process {
        id: meteredWriter
        onExited: {
            if (!meteredCheck.running)
                meteredCheck.running = true;
        }
    }
}
