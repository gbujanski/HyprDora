pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The wallpaper, drawn by hyprpaper on every monitor. The settings keep its path, and hyprpaper.conf gets it for
// the next session; a picture is set from the settings, from the file manager or through IPC.
Singleton {
    id: root

    // HyprDora's own wallpapers, and the one shown when none is chosen.
    readonly property string folder: "/usr/share/hyprdora/assets"
    readonly property string defaultPath: `${folder}/hyprdora-wallpaper.jpg`
    readonly property string current: Settings.wallpaper || defaultPath

    /** Asks for a picture with a file dialog and sets it, then shows the appearance settings again. */
    function choose() {
        if (!picker.running)
            picker.running = true;
    }

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
        Settings.set("wallpaper", path === defaultPath ? undefined : path);
        config.setText(`splash = false\nipc = true\n\nwallpaper {\n    monitor =\n    path = ${path}\n    fit_mode = cover\n}\n`);
        return true;
    }

    Process {
        id: applier
        onExited: Quickshell.execDetached(["hyprctl", "hyprpaper", "unload", "unused"])
    }

    // zenity rather than QtQuick.Dialogs, whose dialog does not open from a shell without a window.
    Process {
        id: picker
        command: ["zenity", "--file-selection", `--title=${I18n.t("appearance.chooseWallpaper")}`, `--file-filter=${I18n.t("appearance.images")} | *.jpg *.jpeg *.png *.webp`]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path !== "")
                    root.set(path);
                Panels.openSettings("appearance");
            }
        }
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
