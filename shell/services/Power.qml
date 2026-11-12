pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config

Singleton {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real level: battery?.percentage ?? 0
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: battery?.state === UPowerDeviceState.FullyCharged

    // Seconds until empty or full; 0 when unknown.
    readonly property real secondsLeft: charging ? (battery?.timeToFull ?? 0) : (battery?.timeToEmpty ?? 0)

    // Draw or charging power in watts; 0 when unknown.
    readonly property real rate: Math.abs(battery?.changeRate ?? 0)

    // Only the physical battery reports health, not UPower's aggregate device.
    readonly property var physicalBattery: UPower.devices.values.find(d => d.isLaptopBattery) ?? null
    readonly property real health: physicalBattery?.healthSupported ? physicalBattery.healthPercentage / 100 : 0

    readonly property string stateText: full ? I18n.t("battery.full") : charging ? I18n.t("battery.state.charging") : !UPower.onBattery ? I18n.t("battery.state.notCharging") : I18n.t("battery.state.discharging")

    // Whether the time to empty or to full is known and worth showing.
    readonly property bool timeKnown: !full && secondsLeft > 0

    // State with the time left, such as "Discharging · 3 h 20 min left".
    readonly property string summary: stateText + (!timeKnown ? "" : " · " + I18n.t(charging ? "battery.untilFull" : "battery.remaining", {
            time: formatTime(secondsLeft)
        }))

    // Clock time of empty or full, power and health, as one line; empty when none is known.
    readonly property string details: {
        const parts = [];
        if (timeKnown)
            parts.push(I18n.t(charging ? "battery.fullAt" : "battery.emptyAt", {
                time: endClock(secondsLeft)
            }));
        if (rate > 0.05)
            parts.push(I18n.t(charging ? "battery.chargeRate" : "battery.drawRate", {
                watts: rate.toLocaleString(I18n.locale, "f", 1)
            }));
        if (health > 0)
            parts.push(I18n.t("battery.health", {
                percent: Math.round(health * 100)
            }));
        const text = parts.join(" · ");
        return text === "" ? "" : text[0].toUpperCase() + text.slice(1);
    }

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    /**
     * Sets the power profile.
     * @param {int} value  PowerProfile value
     */
    function setProfile(value) {
        PowerProfiles.profile = value;
    }

    /**
     * Returns the clock time when the battery empties or fills.
     * @param {real} seconds  time remaining
     * @returns {string} empty when unknown
     */
    function endClock(seconds) {
        if (!(seconds > 0))
            return "";
        return new Date(Date.now() + seconds * 1000).toLocaleTimeString(I18n.locale, "HH:mm");
    }

    /**
     * Formats a duration in hours and minutes.
     * @param {real} seconds  duration
     * @returns {string}
     */
    function formatTime(seconds) {
        const minutes = Math.round(seconds / 60);
        const h = Math.floor(minutes / 60);
        const m = minutes % 60;
        return h > 0 ? I18n.t("time.hoursMinutes", {
            hours: h,
            minutes: m
        }) : I18n.t("time.minutes", {
            minutes: m
        });
    }

    IpcHandler {
        target: "power"

        function describe(): string {
            return JSON.stringify({
                level: root.level,
                state: root.stateText,
                secondsLeft: root.secondsLeft,
                rate: root.rate,
                health: root.health
            });
        }
        function profile(): string {
            return PowerProfile.toString(root.profile);
        }
        function setProfile(name: string): bool {
            const values = {
                saver: PowerProfile.PowerSaver,
                balanced: PowerProfile.Balanced,
                performance: PowerProfile.Performance
            };
            if (values[name] === undefined)
                return false;
            root.setProfile(values[name]);
            return true;
        }
    }
}
