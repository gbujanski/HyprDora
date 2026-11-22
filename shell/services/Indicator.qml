pragma Singleton

import QtQuick
import Quickshell

// Asks for the on-screen indicator of volume, brightness or the keyboard layout. Only a change the user makes
// asks for it: the keys, the bar's sound icon, a headset's buttons, switching the layout. A change that
// happens on its own, such as the next output's volume after headphones disconnect or the screen dimming
// when idle, does not.
Singleton {
    id: root

    /**
     * Emitted for each request; the indicator shows the kind's current value.
     * @param {string} kind  "volume", "microphone", "display", "keyboard" (its backlight) or "layout"
     */
    signal requested(string kind)

    /**
     * Shows the indicator for a kind.
     * @param {string} kind  "volume", "microphone", "display", "keyboard" (its backlight) or "layout"
     */
    function show(kind) {
        requested(kind);
    }
}
