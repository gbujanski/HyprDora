pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

// Applications that keep running after their last window closes, such as GNOME Software, which stays as a
// service of about 400 MB. A few seconds after the last window of one of them closes, its quit command runs;
// it starts again from the launcher. Only an application whose window was seen is stopped.
Singleton {
    id: root

    // Open windows by application id, for the applications in the settings.
    readonly property var windowCounts: {
        const counts = {};
        for (const id of Object.keys(Settings.quitWithLastWindow))
            counts[id] = ToplevelManager.toplevels.values.filter(t => t.appId === id).length;
        return counts;
    }
    // Applications that had a window since they last quit.
    property var seen: ({})

    onWindowCountsChanged: {
        let changed = false;
        const next = Object.assign({}, seen);
        for (const id of Object.keys(windowCounts)) {
            if (windowCounts[id] > 0 && !next[id]) {
                next[id] = true;
                changed = true;
            }
        }
        if (changed)
            seen = next;
        quitDelay.restart();
    }

    Timer {
        id: quitDelay
        interval: 5000
        onTriggered: {
            const next = Object.assign({}, root.seen);
            for (const id of Object.keys(root.windowCounts)) {
                if (root.windowCounts[id] === 0 && next[id]) {
                    Quickshell.execDetached(Settings.quitWithLastWindow[id]);
                    delete next[id];
                }
            }
            root.seen = next;
        }
    }
}
