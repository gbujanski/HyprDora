import QtQuick
import Quickshell
import qs.config

// What Wi-Fi, Bluetooth and VPN share: one line saying where the connection stands, worked out the same way
// for each, with an icon and a tooltip, so the bar and the action center's tiles say the same. Each service
// sets its state and its own words; the first that holds is said: connecting, missing hardware, blocked,
// switched off, the connected name, and otherwise idle.
Singleton {
    property bool stateBusy: false
    // Says the hardware is missing, as for no Bluetooth adapter; "" when it is there.
    property string missingText: ""
    property bool stateBlocked: false
    property string blockedText: ""
    property bool stateOn: true
    property string offText: ""
    // What it is connected to, or "" when it is not.
    property string connectedName: ""
    property string idleText: ""

    property string statusIcon: ""
    property string statusTooltip: ""

    readonly property string summary: {
        if (stateBusy)
            return I18n.t("status.connecting");
        if (missingText !== "")
            return missingText;
        if (stateBlocked)
            return blockedText;
        if (!stateOn)
            return offText;
        return connectedName !== "" ? connectedName : idleText;
    }
}
