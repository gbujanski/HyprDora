pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Defaults, overridden by ~/.config/hyprdora/settings.json. Saving the file applies it.
Singleton {
    id: root

    property var overrides: ({})

    readonly property string configDir: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`

    // "auto" follows the system language when a translation exists.
    readonly property string language: overrides.language ?? "auto"

    // Coordinates rather than a city name, so results do not depend on a place search.
    // Weather stays hidden until a location is set.
    readonly property var weather: overrides.weather ?? null
    readonly property bool hasWeatherLocation: typeof weather?.latitude === "number" && typeof weather?.longitude === "number"
    readonly property string weatherPlace: weather?.place ?? ""
    readonly property real weatherLatitude: weather?.latitude ?? 0
    readonly property real weatherLongitude: weather?.longitude ?? 0
    readonly property int weatherInterval: 30 * 60 * 1000
    readonly property int weatherRetry: 5 * 60 * 1000
    // Older results are hidden so the bar never passes them off as current.
    readonly property int weatherMaxAge: 3 * 60 * 60 * 1000

    // Minimum delay in ms between month changes when scrolling the calendar.
    readonly property int calendarScrollDelay: overrides.calendarScrollDelay ?? 100

    // Backlight power, as a fraction of maximum, used for 0% on the slider and keys.
    readonly property real brightnessMinimum: overrides.brightnessMinimum ?? 0.016

    // Battery warning thresholds as a charge fraction, matching UPower.conf.
    readonly property real batteryLow: 0.20
    readonly property real batteryCritical: 0.05

    readonly property int statsInterval: 2000

    // Command that runs a program in a terminal; the program is appended.
    readonly property var terminalCommand: overrides.terminalCommand ?? ["alacritty", "--class", "systui", "-e"]
    readonly property var btopCommand: [...terminalCommand, "btop"]

    /**
     * Parses the settings file.
     * @param {string} text  file contents
     * @returns {object} overrides, empty when the file is invalid
     */
    function parsed(text) {
        try {
            const value = JSON.parse(text);
            if (value !== null && typeof value === "object" && !Array.isArray(value)) return value;
        } catch (e) {}
        console.warn("settings: invalid settings.json, using defaults");
        return {};
    }

    FileView {
        path: `${root.configDir}/hyprdora/settings.json`
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.overrides = root.parsed(text())
        onLoadFailed: root.overrides = {}
    }
}
