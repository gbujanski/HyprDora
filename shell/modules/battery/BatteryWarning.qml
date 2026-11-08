import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.services

// Ostrzeżenia o niskiej baterii jako zwykłe powiadomienia (przez notify-send),
// więc trafiają do toastów i historii. Każdy próg ostrzega raz na rozładowanie;
// podłączenie zasilacza zamyka ostrzeżenie i zeruje stan.
Scope {
    id: root

    // 0: brak ostrzeżenia, 1: niski poziom, 2: krytyczny.
    property int warned: 0
    property int notificationId: 0

    // Przed wczytaniem danych UPower poziom wynosi 0, co dałoby fałszywy alarm.
    readonly property bool ready: Power.hasBattery && (Power.battery?.ready ?? false)
    readonly property bool discharging: ready && UPower.onBattery && !Power.charging
    readonly property int severity: !discharging ? 0
        : Power.level <= Settings.batteryCritical ? 2
        : Power.level <= Settings.batteryLow ? 1
        : 0

    onSeverityChanged: evaluate()
    onDischargingChanged: evaluate()
    Component.onCompleted: evaluate()

    function evaluate() {
        if (!ready) return;
        if (!discharging) {
            if (warned > 0) close();
            warned = 0;
            return;
        }
        // Tylko eskalacja: wahania wokół progu nie powtarzają ostrzeżenia.
        if (severity > warned) {
            warned = severity;
            send(severity);
        }
    }

    function send(level) {
        const critical = level >= 2;
        const percent = Math.round(Power.level * 100);
        const time = Power.secondsLeft > 0 ? `, ok. ${Power.formatTime(Power.secondsLeft)}` : "";
        const summary = critical ? "Bateria prawie rozładowana" : "Niski poziom baterii";
        const body = `Zostało ${percent}%${time}. `
            + (critical ? "Zapisz pracę i podłącz zasilacz." : "Podłącz zasilacz.");
        // Krytyczne nie znika samo i przebija się przez Nie przeszkadzać.
        // Niskie też nie znika samo (-t 0), żeby nie dało się go przeoczyć.
        const command = ["notify-send", "--print-id", "--app-name=Bateria",
            `--icon=${critical ? "battery-empty" : "battery-caution"}`,
            `--urgency=${critical ? "critical" : "normal"}`, "--expire-time=0"];
        // Krytyczne zastępuje niskie zamiast dokładać drugie.
        if (notificationId > 0) command.push(`--replace-id=${notificationId}`);
        command.push(summary, body);
        sender.command = command;
        sender.running = true;
    }

    function close() {
        if (notificationId <= 0) return;
        Quickshell.execDetached(["gdbus", "call", "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.CloseNotification", String(notificationId)]);
        notificationId = 0;
    }

    Process {
        id: sender
        stdout: StdioCollector {
            onStreamFinished: {
                const id = parseInt(text.trim());
                if (!isNaN(id)) root.notificationId = id;
            }
        }
    }

    IpcHandler {
        target: "batterywarning"

        function describe(): string {
            return JSON.stringify({ ready: root.ready, discharging: root.discharging, level: Power.level, severity: root.severity, warned: root.warned, notificationId: root.notificationId });
        }
    }
}
