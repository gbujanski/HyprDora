pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether Caps Lock is on, read from Hyprland when asked: password fields ask after each key, as nothing
// reports the change.
Singleton {
    id: root

    property bool capsLock: false

    /** Reads Caps Lock again. Caps Lock turns on when pressed but off only when released, so ask after both. */
    function readCapsLock() {
        if (!reader.running)
            reader.running = true;
    }

    Process {
        id: reader
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.capsLock = JSON.parse(text).keyboards.some(k => k.main && k.capsLock);
                } catch (e) {}
            }
        }
    }
}
