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

    // Settings menu inside the action center, opened under its button.
    property bool settingsMenuOpen: false
    property Item settingsButton: null
    property string settingsCategory: ""

    // Audio section unfolded on the main page: "output", "input" or "".
    property string audioExpanded: ""

    onActionCenterOpenChanged: {
        settingsMenuOpen = false;
        if (!actionCenterOpen)
            audioExpanded = "";
    }
    onActionCenterPageChanged: settingsMenuOpen = false
    onSettingsMenuOpenChanged: settingsCategory = ""

    property bool calendarOpen: false
    property var calendarScreen: null

    property bool notificationsOpen: false
    property var notificationsScreen: null

    property bool mediaOpen: false
    property var mediaScreen: null

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
        // Every panel takes the keyboard, so at most one is open.
        if (actionCenterOpen)
            closeOthers("actionCenter");
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
        if (actionCenterOpen && samePlace)
            closeActionCenter();
        else
            openActionCenter(target, page);
    }

    /**
     * Opens the calendar.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openCalendar(screen) {
        calendarScreen = screen ?? focusedScreen();
        calendarOpen = calendarScreen !== null;
        if (calendarOpen)
            closeOthers("calendar");
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
        if (calendarOpen && target === calendarScreen)
            closeCalendar();
        else
            openCalendar(target);
    }

    /**
     * Closes every panel except one. Each panel takes the keyboard, so at most one is open.
     * @param {string} keep  panel to leave open
     */
    function closeOthers(keep) {
        if (keep !== "actionCenter")
            actionCenterOpen = false;
        if (keep !== "calendar")
            calendarOpen = false;
        if (keep !== "notifications")
            notificationsOpen = false;
        if (keep !== "media")
            mediaOpen = false;
    }

    /**
     * Opens the media player panel.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openMedia(screen) {
        mediaScreen = screen ?? focusedScreen();
        mediaOpen = mediaScreen !== null;
        if (mediaOpen)
            closeOthers("media");
    }

    /** Closes the media player panel. */
    function closeMedia() {
        mediaOpen = false;
    }

    /**
     * Closes the media panel if open on this screen, otherwise opens it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggleMedia(screen) {
        const target = screen ?? focusedScreen();
        if (mediaOpen && target === mediaScreen)
            closeMedia();
        else
            openMedia(target);
    }

    /**
     * Opens the action center with the sound output or microphone section unfolded, or closes it when
     * that is already shown on this screen.
     * @param {ShellScreen} screen  target, or null for the focused screen
     * @param {string} section  "output" or "input"
     */
    function toggleAudio(screen, section) {
        const target = screen ?? focusedScreen();
        if (actionCenterOpen && target === actionCenterScreen && actionCenterPage === "main" && audioExpanded === section) {
            closeActionCenter();
            return;
        }
        openActionCenter(target, "main");
        audioExpanded = section;
    }

    /**
     * Opens the notification panel.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openNotifications(screen) {
        notificationsScreen = screen ?? focusedScreen();
        notificationsOpen = notificationsScreen !== null;
        if (notificationsOpen)
            closeOthers("notifications");
    }

    /** Closes the notification panel. */
    function closeNotifications() {
        notificationsOpen = false;
    }

    /**
     * Closes the notification panel if open on this screen, otherwise opens it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggleNotifications(screen) {
        const target = screen ?? focusedScreen();
        if (notificationsOpen && target === notificationsScreen)
            closeNotifications();
        else
            openNotifications(target);
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
            if (root.notificationsOpen && !Quickshell.screens.includes(root.notificationsScreen)) {
                root.closeNotifications();
                root.notificationsScreen = null;
            }
            if (root.mediaOpen && !Quickshell.screens.includes(root.mediaScreen)) {
                root.closeMedia();
                root.mediaScreen = null;
            }
        }
    }

    IpcHandler {
        target: "actioncenter"

        function toggle(): void {
            root.toggleActionCenter(null, "main");
        }
        function open(page: string): void {
            root.openActionCenter(null, page);
        }
        function close(): void {
            root.closeActionCenter();
        }
        function isOpen(): bool {
            return root.actionCenterOpen;
        }
        function page(): string {
            return root.actionCenterOpen ? root.actionCenterPage : "";
        }
    }

    IpcHandler {
        target: "mediapanel"

        function toggle(): void {
            root.toggleMedia(null);
        }
        function open(): void {
            root.openMedia(null);
        }
        function close(): void {
            root.closeMedia();
        }
        function isOpen(): bool {
            return root.mediaOpen;
        }
    }

    IpcHandler {
        target: "notificationcenter"

        function toggle(): void {
            root.toggleNotifications(null);
        }
        function open(): void {
            root.openNotifications(null);
        }
        function close(): void {
            root.closeNotifications();
        }
        function isOpen(): bool {
            return root.notificationsOpen;
        }
    }

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            root.toggleCalendar(null);
        }
        function open(): void {
            root.openCalendar(null);
        }
        function close(): void {
            root.closeCalendar();
        }
        function isOpen(): bool {
            return root.calendarOpen;
        }
    }

    IpcHandler {
        target: "settings"

        function open(category: string): void {
            root.openActionCenter(null, "main");
            root.settingsMenuOpen = true;
            root.settingsCategory = category;
        }
        function close(): void {
            root.settingsMenuOpen = false;
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

    // Here rather than in Session: this singleton exists from startup, so the shortcut works at once.
    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            root.toggleActionCenter(null, "power");
        }
    }
}
