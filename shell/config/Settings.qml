pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.base

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

    // Idle steps in seconds; 0 turns a step off. Suspend applies only on battery.
    readonly property int idleDim: overrides.idle?.dim ?? 240
    readonly property int idleLock: overrides.idle?.lock ?? 300
    readonly property int idleSuspend: overrides.idle?.suspend ?? 900

    // Sound recorded with the screen; both off by default.
    readonly property bool captureSystemAudio: overrides.capture?.systemAudio ?? false
    readonly property bool captureMicrophone: overrides.capture?.microphone ?? false

    // Command that runs a program in the default terminal, chosen in the settings; the program is appended.
    readonly property var terminalCommand: overrides.terminalCommand ?? ["xdg-terminal-exec"]
    readonly property var btopCommand: [...terminalCommand, "btop"]
    // "dark" or "light", for the shell and GTK applications; the terminal stays dark.
    readonly property string theme: overrides.theme ?? "dark"
    // The wallpaper's path; left out, HyprDora's default. Wallpaper shows it and keeps it.
    readonly property string wallpaper: typeof overrides.wallpaper === "string" ? overrides.wallpaper : ""
    // Icon theme for applications, the launcher and GTK: one of iconThemes. The shell reads it at start.
    readonly property var iconThemes: ["Papirus", "Adwaita"]
    readonly property string iconTheme: iconThemes.includes(overrides.iconTheme) ? overrides.iconTheme : "Papirus"

    // Days that ordinary updates wait before the bar shows them: 0, 1 or 7. Security updates and HyprDora's own
    // show at once.
    readonly property int updateReminderDays: [0, 1, 7].includes(overrides.updates?.reminderDays) ? overrides.updates.reminderDays : 7

    // Automations set in the settings: { dnd, coffee, mute: schedule, headphones: { enabled },
    // vpn: { enabled, homeNetworks, connection } }; a schedule is { enabled, from, to, days }, with times
    // in minutes after midnight and days numbered 1 (Monday) to 7.
    readonly property var automations: overrides.automations ?? {}

    // Desktop entry ids left out of the launcher because the settings cover them: printer settings open from
    // "more settings" under printers and scanners.
    readonly property var hiddenApplications: overrides.hiddenApplications ?? ["system-config-printer"]

    // Applications quit a few seconds after their last window closes, by Wayland application id: the command
    // that quits each. GNOME Software otherwise stays in the background as a service of about 400 MB.
    // Pointer and keyboard, which Input writes for Hyprland. Touchpad scrolling that moves the content with the
    // fingers, as on a phone; a tap that clicks; pointer speed from -1 to 1 for the mouse and the touchpad.
    readonly property bool touchpadNaturalScroll: overrides.touchpadNaturalScroll ?? false
    readonly property bool touchpadTapToClick: overrides.touchpadTapToClick ?? true
    readonly property real pointerSpeed: Math.max(-1, Math.min(1, Number(overrides.pointerSpeed ?? 0) || 0))
    // Keyboard layouts, the first the default: [{ layout, variant }] as xkb names them, such as
    // { layout: "pl", variant: "" }. Left out, the system's layouts chosen in the installer apply.
    readonly property var keyboardLayouts: overrides.keyboardLayouts ?? null
    readonly property var quitWithLastWindow: overrides.quitWithLastWindow ?? {
        "org.gnome.Software": ["gnome-software", "--quit"]
    }

    // Address the launcher appends a search to when nothing else matches.
    readonly property string webSearchUrl: overrides.webSearchUrl ?? "https://duckduckgo.com/?q="

    /**
     * Parses the settings file.
     * @param {string} text  file contents
     * @returns {object} overrides, empty when the file is invalid
     */
    function parsed(text) {
        try {
            const value = JSON.parse(text);
            if (value !== null && typeof value === "object" && !Array.isArray(value)) {
                delete value["//"];
                return value;
            }
        } catch (e) {}
        console.warn(log, "invalid settings.json, using defaults");
        return {};
    }

    // Whether settings.json exists and is watched.
    property bool fileReady: false
    // Written on top of settings.json, for whoever opens it.
    readonly property var note: ["HyprDora shell settings, saved here by the settings in the action center.", "You may edit or replace this file; a change applies at once.", "A setting not listed keeps its default, so with none listed everything is at its default.", "To go back to the defaults, remove the settings below. Deleting the file does the same: the shell makes it again, with none."]

    /**
     * Saves a top-level setting to settings.json and applies it.
     * @param {string} key  top-level key
     * @param {var} value  new value, or undefined to remove the key
     */
    function set(key, value) {
        const next = Object.assign({}, overrides);
        if (value === undefined)
            delete next[key];
        else
            next[key] = value;
        overrides = next;
        write(next);
    }

    /**
     * Writes settings.json, the note on top.
     * @param {object} values  the settings
     */
    function write(values) {
        file.setText(JSON.stringify(Object.assign({
            "//": note
        }, values), null, 2) + "\n");
    }

    /** Makes settings.json again, with no settings, and watches the new file. */
    function recreate() {
        fileReady = false;
        write({});
        fileReady = true;
    }

    /**
     * Saves one value inside an object setting, keeping its other values.
     * @param {string} key  top-level key of the object
     * @param {string} name  value inside it
     * @param {var} value  new value
     */
    function setIn(key, name, value) {
        const next = Object.assign({}, overrides[key] ?? {});
        next[name] = value;
        set(key, next);
    }

    FileView {
        id: file
        path: `${root.configDir}/hyprdora/settings.json`
        atomicWrites: true
        // Written at once, so a file just made is there to be watched.
        blockWrites: true
        blockLoading: true
        printErrors: false
        onLoaded: {
            root.overrides = root.parsed(text());
            root.fileReady = true;
        }
        // Missing at start or deleted later, it is made again with no settings: watching needs a file, and a
        // deleted folder ends the watch of the old one.
        onLoadFailed: {
            console.info(log, "settings.json is missing; made it with no settings");
            root.overrides = {};
            root.recreate();
        }
        onSaveFailed: error => console.warn(log, "cannot write settings.json:", error)
    }

    // Edited by hand or by another tool, it is read again.
    EventSubscription {
        file: file.path
        enabled: root.fileReady
        onChanged: file.reload()
    }

    LoggingCategory {
        id: log
        name: "hyprdora.settings"
    }
}
