pragma Singleton

import QtQuick
import Quickshell

// Asks for the on-screen indicator of volume or brightness. Only a change the user makes asks for it: the
// keys, the bar's sound icon, a headset's buttons. A change that happens on its own, such as the next
// output's volume after headphones disconnect or the screen dimming when idle, does not.
Singleton {
    id: root

    /**
     * Emitted for each request; the indicator shows the kind's current value.
     * @param {string} kind  "volume", "microphone", "display" or "keyboard"
     */
    signal requested(string kind)

    /**
     * Shows the indicator for a kind.
     * @param {string} kind  "volume", "microphone", "display" or "keyboard"
     */
    function show(kind) {
        requested(kind);
    }
}
