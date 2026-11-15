pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Applies the theme and icon theme chosen in the settings to GTK and libadwaita applications, and through
// the settings portal to Flatpaks and browsers. The shell follows Theme.light by itself; the terminal stays
// dark. Quickshell reads its icon theme only at start, so a new one restarts the shell.
Singleton {
    id: root

    /** Writes the GTK settings that match the theme; a dev shell leaves the session's settings alone. */
    function apply() {
        if (Quickshell.env("HYPRDORA_SHELL"))
            return;
        const light = Theme.light;
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", light ? "prefer-light" : "prefer-dark"]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", light ? "Adwaita" : "Adwaita-dark"]);
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", Settings.iconTheme]);
    }

    Connections {
        target: Theme
        function onLightChanged() {
            root.apply();
        }
    }

    Connections {
        target: Settings
        function onIconThemeChanged() {
            root.apply();
            if (Settings.iconTheme !== Quickshell.env("QS_ICON_THEME") && !Quickshell.env("HYPRDORA_SHELL"))
                restartDelay.restart();
        }
    }

    // The settings file is written first.
    Timer {
        id: restartDelay
        interval: 500
        onTriggered: Quickshell.execDetached(["systemctl", "--user", "restart", "hyprdora-shell.service"])
    }

    // A theme changed in settings.json while the shell was off still reaches the applications.
    Component.onCompleted: apply()
}
