import QtQuick
import qs.config
import qs.components
import qs.services

// IPv4, DNS and IPv6 of one saved connection, for the wired page and a saved Wi-Fi network: each automatic,
// or set by hand. Save writes them and applies them at once while the connection is up; it is offered only
// when something changed and every field set by hand is valid.
Column {
    id: root

    required property string uuid
    property bool active: false

    /** New settings were written and applied. */
    signal saved

    // What the form shows, taken from the connection once read.
    property string method: "auto"
    property string address: ""
    property string gateway: ""
    property bool ownDns: false
    property string dns: ""
    property bool ipv6: true

    readonly property bool changed: config.loaded && (method !== config.method || ipv6 !== config.ipv6 || ownDns !== (config.dns !== "") || (method === "manual" && (address !== config.address || gateway !== config.gateway)) || (ownDns && dns !== config.dns))
    readonly property bool valid: (method === "auto" || (isAddress(address, true) && (gateway === "" || isAddress(gateway, false)))) && (!ownDns || (dns.split(/[\s,]+/).filter(Boolean).length > 0 && dns.split(/[\s,]+/).filter(Boolean).every(s => isAddress(s, false))))

    /**
     * Whether text is an IPv4 address, such as 192.168.1.20, with a prefix such as /24 when asked for.
     * @param {string} text  what was typed
     * @param {bool} withPrefix  whether a prefix is required
     * @returns {bool}
     */
    function isAddress(text, withPrefix) {
        const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?:\/(\d{1,2}))?$/.exec(text.trim());
        if (!m || [m[1], m[2], m[3], m[4]].some(o => Number(o) > 255))
            return false;
        return withPrefix ? m[5] !== undefined && Number(m[5]) >= 1 && Number(m[5]) <= 32 : m[5] === undefined;
    }

    /** Fills the form from the connection. */
    function reset() {
        method = config.method;
        address = config.address;
        gateway = config.gateway;
        ownDns = config.dns !== "";
        dns = config.dns;
        ipv6 = config.ipv6;
        addressField.text = address;
        gatewayField.text = gateway;
        dnsField.text = dns;
    }

    spacing: 6

    IpConfig {
        id: config
        uuid: root.uuid
        active: root.active
        // A save reads the connection again, so the form then shows what was written.
        onSettingsRead: root.reset()
        onSaved: root.saved()
        Component.onCompleted: load()
    }

    Label {
        text: "IPv4"
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
    }

    SegmentedControl {
        width: root.width
        currentValue: root.method
        options: [
            {
                value: "auto",
                label: I18n.t("ip.automatic")
            },
            {
                value: "manual",
                label: I18n.t("ip.manual")
            }
        ]
        onSelected: value => root.method = value
    }

    TextField {
        id: addressField
        width: root.width
        visible: root.method === "manual"
        placeholder: I18n.t("ip.address")
        onTextChanged: root.address = text
    }

    TextField {
        id: gatewayField
        width: root.width
        visible: root.method === "manual"
        placeholder: I18n.t("ip.gateway")
        onTextChanged: root.gateway = text
    }

    Label {
        topPadding: 4
        text: "DNS"
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
    }

    SegmentedControl {
        width: root.width
        currentValue: root.ownDns
        options: [
            {
                value: false,
                label: I18n.t("ip.automatic")
            },
            {
                value: true,
                label: I18n.t("ip.ownDns")
            }
        ]
        onSelected: value => root.ownDns = value
    }

    TextField {
        id: dnsField
        width: root.width
        visible: root.ownDns
        placeholder: I18n.t("ip.dnsServers")
        onTextChanged: root.dns = text
    }

    Label {
        topPadding: 4
        text: "IPv6"
        color: Theme.muted
        font.pixelSize: Theme.fontSizeSmall
    }

    SegmentedControl {
        width: root.width
        currentValue: root.ipv6
        options: [
            {
                value: true,
                label: I18n.t("ip.automatic")
            },
            {
                value: false,
                label: I18n.t("ip.off")
            }
        ]
        onSelected: value => root.ipv6 = value
    }

    Label {
        width: root.width
        visible: config.error !== ""
        text: config.error
        color: Theme.error
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Row {
        anchors.right: parent.right
        spacing: 6
        topPadding: 4

        Spinner {
            anchors.verticalCenter: parent.verticalCenter
            running: config.busy
            visible: config.busy
        }

        TextButton {
            visible: root.changed && !config.busy
            text: I18n.t("common.cancel")
            onClicked: root.reset()
        }

        TextButton {
            primary: true
            active: root.changed && root.valid && !config.busy
            text: I18n.t("ip.save")
            onClicked: config.save({
                method: root.method,
                address: root.address,
                gateway: root.gateway,
                dns: root.ownDns ? root.dns : "",
                ipv6: root.ipv6
            })
        }
    }
}
