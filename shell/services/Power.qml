pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real level: battery?.percentage ?? 0
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
        || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: battery?.state === UPowerDeviceState.FullyCharged

    // Czas w sekundach do rozładowania albo naładowania; 0, gdy nieznany.
    readonly property real secondsLeft: charging ? (battery?.timeToFull ?? 0) : (battery?.timeToEmpty ?? 0)

    // Pobór (przy rozładowaniu) albo moc ładowania w watach; 0, gdy nieznane.
    readonly property real rate: Math.abs(battery?.changeRate ?? 0)

    // Kondycja zna tylko fizyczna bateria, a nie urządzenie zbiorcze UPower.
    readonly property var physicalBattery: UPower.devices.values.find(d => d.isLaptopBattery) ?? null
    readonly property real health: physicalBattery?.healthSupported ? physicalBattery.healthPercentage / 100 : 0

    readonly property string stateText: full ? "Naładowana"
        : charging ? "Ładowanie"
        : !UPower.onBattery ? "Podłączona, nie ładuje"
        : "Rozładowywanie"

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    function setProfile(value) {
        PowerProfiles.profile = value;
    }

    // Godzina rozładowania albo naładowania, np. „17:40”; pusta, gdy czas nieznany.
    function endClock(seconds) {
        if (!(seconds > 0)) return "";
        return new Date(Date.now() + seconds * 1000).toLocaleTimeString(Qt.locale(), "HH:mm");
    }

    function formatTime(seconds) {
        const minutes = Math.round(seconds / 60);
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        return h > 0 ? `${h} godz. ${m} min` : `${m} min`;
    }

    IpcHandler {
        target: "power"

        function describe(): string {
            return JSON.stringify({ level: root.level, state: root.stateText, secondsLeft: root.secondsLeft, rate: root.rate, health: root.health });
        }
        function profile(): string { return PowerProfile.toString(root.profile); }
        function setProfile(name: string): bool {
            const values = { saver: PowerProfile.PowerSaver, balanced: PowerProfile.Balanced, performance: PowerProfile.Performance };
            if (values[name] === undefined) return false;
            root.setProfile(values[name]);
            return true;
        }
    }
}
