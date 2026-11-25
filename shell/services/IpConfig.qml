import QtQuick
import Quickshell
import Quickshell.Io

// The IP settings of one saved NetworkManager connection, wired or Wi-Fi: IPv4 automatic or set by hand,
// DNS from the network or the user's own servers, and IPv6 automatic or off. load() reads them; save()
// writes them and, while the connection is up, brings it up again so they apply at once.
Scope {
    id: root

    property string uuid: ""
    // Whether the connection is up now, so saving applies it.
    property bool active: false

    property bool loaded: false
    // "auto" or "manual".
    property string method: "auto"
    // An address with its prefix, such as 192.168.1.20/24, and the gateway, while set by hand.
    property string address: ""
    property string gateway: ""
    // The user's own DNS servers, such as 1.1.1.1, 9.9.9.9; empty for the network's.
    property string dns: ""
    property bool ipv6: true
    property bool busy: writer.running
    property string error: ""

    /** The settings were read, at first and after each save. */
    signal settingsRead
    /** New settings were written and applied. */
    signal saved

    onUuidChanged: load()

    /** Reads the connection's settings. */
    function load() {
        if (uuid === "" || reader.running)
            return;
        reader.command = ["env", "LC_ALL=C", "nmcli", "-g", "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.ignore-auto-dns,ipv6.method", "connection", "show", uuid];
        reader.running = true;
    }

    /**
     * Writes new settings and applies them.
     * @param {object} values  { method, address, gateway, dns, ipv6 } as the properties above
     */
    function save(values) {
        if (uuid === "" || writer.running)
            return;
        const manual = values.method === "manual";
        const own = values.dns.trim() !== "";
        const servers = values.dns.split(/[\s,]+/).filter(Boolean).join(",");
        const args = ["ipv4.method", manual ? "manual" : "auto", "ipv4.addresses", manual ? values.address.trim() : "", "ipv4.gateway", manual ? values.gateway.trim() : "", "ipv4.dns", own ? servers : "", "ipv4.ignore-auto-dns", own ? "yes" : "no", "ipv6.method", values.ipv6 ? "auto" : "disabled"];
        // Brought up again only while up, as that is what applies the change.
        const up = active ? ' && nmcli connection up "$connection" >/dev/null' : "";
        error = "";
        writer.command = ["sh", "-c", 'connection=$1; shift; nmcli connection modify "$connection" "$@"' + up, "hyprdora-ip", uuid, ...args];
        writer.running = true;
    }

    property Process reader: Process {
        stdout: StdioCollector {
            // One value per line: method, addresses, gateway, DNS servers, whether the network's DNS is
            // ignored, IPv6's method. Lists are comma separated; only the first address is shown.
            onStreamFinished: {
                const [method, addresses, gateway, dns, ignoreAutoDns, ipv6] = text.split("\n");
                root.method = method === "manual" ? "manual" : "auto";
                root.address = (addresses ?? "").split(",")[0].trim();
                root.gateway = (gateway ?? "").trim();
                root.dns = ignoreAutoDns === "yes" ? (dns ?? "").split(",").map(s => s.trim()).filter(Boolean).join(", ") : "";
                root.ipv6 = ipv6 !== "disabled" && ipv6 !== "ignore";
                root.loaded = true;
                root.settingsRead();
            }
        }
    }

    property Process writer: Process {
        stderr: StdioCollector {
            id: writeErrors
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.error = writeErrors.text.trim().split("\n").pop() ?? "";
            else
                root.saved();
            root.load();
        }
    }
}
