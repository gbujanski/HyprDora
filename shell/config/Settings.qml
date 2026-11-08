pragma Singleton

import QtQuick
import Quickshell

// User-adjustable values.
Singleton {
    readonly property string language: "auto"

    // Coordinates rather than a city name, so results do not depend on a place search.
    readonly property string weatherPlace: "Warszawa"
    readonly property real weatherLatitude: 52.23
    readonly property real weatherLongitude: 21.01
    readonly property int weatherInterval: 30 * 60 * 1000
    readonly property int weatherRetry: 5 * 60 * 1000
    // Older results are hidden so the bar never passes them off as current.
    readonly property int weatherMaxAge: 3 * 60 * 60 * 1000

    // Minimum delay in ms between month changes when scrolling the calendar.
    readonly property int calendarScrollDelay: 100

    // Backlight power, as a fraction of maximum, used for 0% on the slider and keys.
    readonly property real brightnessMinimum: 0.016

    // Battery warning thresholds as a charge fraction, matching UPower.conf.
    readonly property real batteryLow: 0.20
    readonly property real batteryCritical: 0.05

    readonly property int statsInterval: 2000

    readonly property var btopCommand: ["alacritty", "--class", "systui", "-e", "btop"]
}
