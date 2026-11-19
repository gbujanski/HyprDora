pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Which panel is open, and on which screen. Every panel takes the keyboard, so at most one is open: opening
// one closes the others. Panels by name: actioncenter, calendar, notifications, media, battery, sound,
// displays, drives, updates, launcher, overview.
Singleton {
    id: root

    // The open panel's name, or "" when none is.
    property string current: ""
    property var currentScreen: null

    // The action center's page, and its settings menu, opened under its button.
    property string actionCenterPage: "main"
    property bool settingsMenuOpen: false
    property Item settingsButton: null
    property string settingsCategory: ""

    // The launcher's mode: "apps" or "clipboard".
    property string launcherMode: "apps"

    onCurrentChanged: settingsMenuOpen = false
    onActionCenterPageChanged: settingsMenuOpen = false
    onSettingsMenuOpenChanged: settingsCategory = ""

    /**
     * Returns the screen with Hyprland's focused monitor.
     * @returns {ShellScreen or null}
     */
    function focusedScreen() {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    /**
     * Tells whether a panel is open.
     * @param {string} name  panel name
     * @returns {bool}
     */
    function isOpen(name) {
        return current === name;
    }

    /**
     * Opens a panel, closing any other.
     * @param {string} name  panel name
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function open(name, screen) {
        const target = screen ?? focusedScreen();
        if (!target)
            return;
        currentScreen = target;
        current = name;
    }

    /**
     * Closes a panel, or whichever is open.
     * @param {string} name  panel name, or nothing for any
     */
    function close(name) {
        if (!name || current === name)
            current = "";
    }

    /**
     * Closes a panel if it is open on this screen, otherwise opens it there.
     * @param {string} name  panel name
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggle(name, screen) {
        const target = screen ?? focusedScreen();
        if (current === name && currentScreen === target)
            close();
        else
            open(name, target);
    }

    /**
     * Opens the action center on a page.
     * @param {ShellScreen} screen  target, or null for the focused screen
     * @param {string} page  page name, main by default
     */
    function openActionCenter(screen, page) {
        actionCenterPage = page || "main";
        open("actioncenter", screen);
    }

    /**
     * Closes the action center if it shows this page on this screen, otherwise shows the page there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     * @param {string} page  page name, main by default
     */
    function toggleActionCenter(screen, page) {
        const target = screen ?? focusedScreen();
        if (current === "actioncenter" && currentScreen === target && (page || "main") === actionCenterPage)
            close();
        else
            openActionCenter(target, page);
    }

    /**
     * Opens the action center with a settings category shown.
     * @param {string} category  category id, as in the settings menu
     */
    function openSettings(category) {
        openActionCenter(null, "main");
        settingsMenuOpen = true;
        settingsCategory = category;
    }

    /**
     * Closes the launcher if it shows this mode, otherwise opens it in this mode.
     * @param {string} mode  "apps" or "clipboard"
     */
    function toggleLauncher(mode) {
        const next = mode || "apps";
        if (current === "launcher" && launcherMode === next) {
            close();
            return;
        }
        launcherMode = next;
        open("launcher", null);
    }

    // The screen holding the open panel may have just been unplugged.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.current !== "" && !Quickshell.screens.includes(root.currentScreen)) {
                root.close();
                root.currentScreen = null;
            }
        }
    }

    IpcHandler {
        target: "panel"

        // Opens or closes a panel by name on the focused screen.
        function toggle(name: string): void {
            root.toggle(name, null);
        }
        function open(name: string): void {
            root.open(name, null);
        }
        function close(): void {
            root.close();
        }
        // The open panel's name, or nothing.
        function current(): string {
            return root.current;
        }
        // The action center on a page: main, wifi, bluetooth, vpn or power; again closes it.
        function page(name: string): void {
            root.toggleActionCenter(null, name);
        }
        function actionCenterPage(): string {
            return root.current === "actioncenter" ? root.actionCenterPage : "";
        }
        // The action center with a settings category shown.
        function settings(category: string): void {
            root.openSettings(category);
        }
        // The launcher in a mode: apps or clipboard; again closes it.
        function launcher(mode: string): void {
            root.toggleLauncher(mode);
        }
    }

    // A press only starts the countdown, so brushing the power button does nothing.
    Timer {
        id: powerHold
        interval: 2000
        onTriggered: Session.runById("poweroff")
    }

    IpcHandler {
        target: "powerbutton"

        function press(): void {
            powerHold.restart();
        }
        function release(): void {
            powerHold.stop();
        }
    }
}
