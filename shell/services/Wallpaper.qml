pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    /**
     * Shows an image on all monitors and keeps it across restarts.
     * @param {string} path  absolute image path
     * @returns {bool} whether the path was accepted
     */
    function set(path) {
        // A comma or newline would change the meaning of the hyprpaper command or config.
        if (!path.startsWith("/") || /[,\n]/.test(path)) {
            console.warn(log, "unsupported path:", path);
            return false;
        }
        applier.command = ["hyprctl", "hyprpaper", "wallpaper", `,${path},cover`];
        applier.running = true;
        config.setText(`splash = false\nipc = true\n\nwallpaper {\n    monitor =\n    path = ${path}\n    fit_mode = cover\n}\n`);
        return true;
    }

    Process {
        id: applier
        onExited: Quickshell.execDetached(["hyprctl", "hyprpaper", "unload", "unused"])
    }

    FileView {
        id: config
        path: `${Settings.configDir}/hypr/hyprpaper.conf`
        blockLoading: true
        printErrors: false
        onSaveFailed: error => console.warn(log, "could not save hyprpaper.conf:", FileViewError.toString(error))
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): bool {
            return root.set(path);
        }
    }

    LoggingCategory {
        id: log
        name: "hyprdora.wallpaper"
    }
}
