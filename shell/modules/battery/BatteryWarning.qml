import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.services

// Low-battery warnings shown as toasts that stay until closed. They stay out of the history, so an old
// warning never lingers there. Each threshold warns once per discharge; plugging in closes the warning.
Scope {
    id: root

    // 0: none, 1: low, 2: critical.
    property int warned: 0
    property int notificationId: 0

    // The level is 0 until UPower data loads, which would be a false alarm. Translations load after
    // startup too, and a warning sent before them would have no text.
    readonly property bool ready: I18n.loaded && Power.hasBattery && (Power.battery?.ready ?? false)
    readonly property bool discharging: ready && UPower.onBattery && !Power.charging
    readonly property int severity: !discharging ? 0 : Power.level <= Settings.batteryCritical ? 2 : Power.level <= Settings.batteryLow ? 1 : 0

    onReadyChanged: evaluate()
    onSeverityChanged: evaluate()
    onDischargingChanged: evaluate()
    Component.onCompleted: evaluate()

    function evaluate() {
        if (!ready)
            return;
        if (!discharging) {
            if (warned > 0)
                close();
            warned = 0;
            return;
        }
        // Escalate only, so jitter around a threshold does not repeat the warning.
        if (severity > warned) {
            warned = severity;
            send(severity);
        }
    }

    function send(level) {
        const critical = level >= 2;
        const percent = Math.round(Power.level * 100);
        const time = Power.secondsLeft > 0 ? I18n.t("battery.warning.timeLeft", {
            time: Power.formatTime(Power.secondsLeft)
        }) : "";
        const summary = critical ? I18n.t("battery.warning.criticalTitle") : I18n.t("battery.warning.lowTitle");
        const body = I18n.t("battery.warning.level", {
            percent,
            time
        }) + " " + (critical ? I18n.t("battery.warning.criticalBody") : I18n.t("battery.warning.lowBody"));
        // Neither level expires on its own, so it cannot be missed, and both show during Do Not Disturb.
        const command = ["notify-send", "--print-id", "--transient", `--hint=boolean:${Notifications.ignoreDndHint}:true`, `--app-name=${I18n.t("battery.appName")}`, ...Notifications.glyphArgs(Icons.battery(Power.level, false), critical ? "error" : "warning"), `--urgency=${critical ? "critical" : "normal"}`, "--expire-time=0"];
        // Critical replaces the low warning instead of adding a second one.
        if (notificationId > 0)
            command.push(`--replace-id=${notificationId}`);
        command.push(summary, body);
        sender.command = command;
        sender.running = true;
    }

    function close() {
        if (notificationId <= 0)
            return;
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.CloseNotification", String(notificationId)]);
        notificationId = 0;
    }

    Process {
        id: sender
        stdout: StdioCollector {
            onStreamFinished: {
                const id = parseInt(text.trim());
                if (!isNaN(id))
                    root.notificationId = id;
            }
        }
    }

    IpcHandler {
        target: "batterywarning"

        function describe(): string {
            return JSON.stringify({
                ready: root.ready,
                discharging: root.discharging,
                level: Power.level,
                severity: root.severity,
                warned: root.warned,
                notificationId: root.notificationId
            });
        }
    }
}
