pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Panel state shared by bars, keybindings and the panels.
Singleton {
    id: root

    property bool actionCenterOpen: false
    property var actionCenterScreen: null
    property string actionCenterPage: "main"

    property bool calendarOpen: false
    property var calendarScreen: null

    /**
     * Returns the screen with Hyprland's focused monitor.
     * @returns {ShellScreen or null}
     */
    function focusedScreen() {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    /**
     * Opens the action center.
     * @param {ShellScreen} screen  target, or null for the focused screen
     * @param {string} page  page name, main by default
     */
    function openActionCenter(screen, page) {
        actionCenterScreen = screen ?? focusedScreen();
        actionCenterPage = page || "main";
        actionCenterOpen = actionCenterScreen !== null;
        // Both panels take the keyboard, so at most one is open.
        if (actionCenterOpen) calendarOpen = false;
    }

    /** Closes the action center. */
    function closeActionCenter() {
        actionCenterOpen = false;
    }

    /**
     * Closes the action center if it shows this page on this screen, otherwise moves it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     * @param {string} page  page name, main by default
     */
    function toggleActionCenter(screen, page) {
        const target = screen ?? focusedScreen();
        const samePlace = target === actionCenterScreen && (page || "main") === actionCenterPage;
        if (actionCenterOpen && samePlace) closeActionCenter();
        else openActionCenter(target, page);
    }

    /**
     * Opens the calendar.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openCalendar(screen) {
        calendarScreen = screen ?? focusedScreen();
        calendarOpen = calendarScreen !== null;
        if (calendarOpen) actionCenterOpen = false;
    }

    /** Closes the calendar. */
    function closeCalendar() {
        calendarOpen = false;
    }

    /**
     * Closes the calendar if open on this screen, otherwise opens it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggleCalendar(screen) {
        const target = screen ?? focusedScreen();
        if (calendarOpen && target === calendarScreen) closeCalendar();
        else openCalendar(target);
    }

    // The screen holding an open panel may have just been unplugged.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.actionCenterOpen && !Quickshell.screens.includes(root.actionCenterScreen)) {
                root.closeActionCenter();
                root.actionCenterScreen = null;
            }
            if (root.calendarOpen && !Quickshell.screens.includes(root.calendarScreen)) {
                root.closeCalendar();
                root.calendarScreen = null;
            }
        }
    }

    IpcHandler {
        target: "actioncenter"

        function toggle(): void { root.toggleActionCenter(null, "main"); }
        function open(page: string): void { root.openActionCenter(null, page); }
        function close(): void { root.closeActionCenter(); }
        function isOpen(): bool { return root.actionCenterOpen; }
        function page(): string { return root.actionCenterOpen ? root.actionCenterPage : ""; }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void { root.toggleCalendar(null); }
        function open(): void { root.openCalendar(null); }
        function close(): void { root.closeCalendar(); }
        function isOpen(): bool { return root.calendarOpen; }
    }

    // Here rather than in Session: this singleton exists from startup, so the shortcut works at once.
    IpcHandler {
        target: "powermenu"

        function toggle(): void { root.toggleActionCenter(null, "power"); }
    }
}
