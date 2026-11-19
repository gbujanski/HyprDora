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

    onActionCenterOpenChanged: settingsMenuOpen = false
    onActionCenterPageChanged: settingsMenuOpen = false
    onSettingsMenuOpenChanged: settingsCategory = ""

    property bool calendarOpen: false
    property var calendarScreen: null

    property bool notificationsOpen: false
    property var notificationsScreen: null

    property bool mediaOpen: false
    property var mediaScreen: null
    property bool batteryOpen: false
    property var batteryScreen: null
    property bool soundOpen: false
    property var soundScreen: null
    property bool displaysOpen: false
    property var displaysScreen: null
    property bool updatesOpen: false
    property var updatesScreen: null
    property bool overviewOpen: false
    property var overviewScreen: null
    property bool launcherOpen: false
    property var launcherScreen: null
    // "apps" or "clipboard".
    property string launcherMode: "apps"

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
        if (keep !== "battery")
            batteryOpen = false;
        if (keep !== "sound")
            soundOpen = false;
        if (keep !== "displays")
            displaysOpen = false;
        if (keep !== "updates")
            updatesOpen = false;
        if (keep !== "overview")
            overviewOpen = false;
        if (keep !== "launcher")
            launcherOpen = false;
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
     * Opens the launcher.
     * @param {ShellScreen} screen  target, or null for the focused screen
     * @param {string} mode  "apps" or "clipboard"
     */
    function openLauncher(screen, mode) {
        launcherMode = mode ?? "apps";
        launcherScreen = screen ?? focusedScreen();
        launcherOpen = launcherScreen !== null;
        if (launcherOpen)
            closeOthers("launcher");
    }

    /** Closes the launcher. */
    function closeLauncher() {
        launcherOpen = false;
    }

    /**
     * Closes the launcher if it shows this mode, otherwise opens it in this mode.
     * @param {string} mode  "apps" or "clipboard"
     */
    function toggleLauncher(mode) {
        if (launcherOpen && launcherMode === (mode ?? "apps"))
            closeLauncher();
        else
            openLauncher(null, mode);
    }

    /**
     * Opens the list of updates.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openUpdates(screen) {
        updatesScreen = screen ?? focusedScreen();
        updatesOpen = updatesScreen !== null;
        if (updatesOpen)
            closeOthers("updates");
    }

    /** Closes the list of updates. */
    function closeUpdates() {
        updatesOpen = false;
    }

    /**
     * Closes the list of updates if open on this screen, otherwise opens it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggleUpdates(screen) {
        const target = screen ?? focusedScreen();
        if (updatesOpen && target === updatesScreen)
            closeUpdates();
        else
            openUpdates(target);
    }

    /**
     * Opens the overview of windows and workspaces.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openOverview(screen) {
        overviewScreen = screen ?? focusedScreen();
        overviewOpen = overviewScreen !== null;
        if (overviewOpen)
            closeOthers("overview");
    }

    /** Closes the overview. */
    function closeOverview() {
        overviewOpen = false;
    }

    /**
     * Closes the overview if open on this screen, otherwise opens it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggleOverview(screen) {
        const target = screen ?? focusedScreen();
        if (overviewOpen && target === overviewScreen)
            closeOverview();
        else
            openOverview(target);
    }

    /**
     * Opens the battery panel.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openBattery(screen) {
        batteryScreen = screen ?? focusedScreen();
        batteryOpen = batteryScreen !== null;
        if (batteryOpen)
            closeOthers("battery");
    }

    /** Closes the battery panel. */
    function closeBattery() {
        batteryOpen = false;
    }

    /**
     * Closes the battery panel if open on this screen, otherwise opens it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggleBattery(screen) {
        const target = screen ?? focusedScreen();
        if (batteryOpen && target === batteryScreen)
            closeBattery();
        else
            openBattery(target);
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
     * Opens the sound panel under the bar's sound icon.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openSound(screen) {
        soundScreen = screen ?? focusedScreen();
        soundOpen = soundScreen !== null;
        if (soundOpen)
            closeOthers("sound");
    }

    /** Closes the sound panel. */
    function closeSound() {
        soundOpen = false;
    }

    /**
     * Closes the sound panel if open on this screen, otherwise opens it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggleSound(screen) {
        const target = screen ?? focusedScreen();
        if (soundOpen && target === soundScreen)
            closeSound();
        else
            openSound(target);
    }

    /**
     * Opens the display settings under the bar's display icon.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function openDisplays(screen) {
        displaysScreen = screen ?? focusedScreen();
        displaysOpen = displaysScreen !== null;
        if (displaysOpen)
            closeOthers("displays");
    }

    /** Closes the display settings panel. */
    function closeDisplays() {
        displaysOpen = false;
    }

    /**
     * Closes the display settings panel if open on this screen, otherwise opens it there.
     * @param {ShellScreen} screen  target, or null for the focused screen
     */
    function toggleDisplays(screen) {
        const target = screen ?? focusedScreen();
        if (displaysOpen && target === displaysScreen)
            closeDisplays();
        else
            openDisplays(target);
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
            if (root.launcherOpen && !Quickshell.screens.includes(root.launcherScreen)) {
                root.closeLauncher();
                root.launcherScreen = null;
            }
            if (root.updatesOpen && !Quickshell.screens.includes(root.updatesScreen)) {
                root.closeUpdates();
                root.updatesScreen = null;
            }
            if (root.overviewOpen && !Quickshell.screens.includes(root.overviewScreen)) {
                root.closeOverview();
                root.overviewScreen = null;
            }
            if (root.batteryOpen && !Quickshell.screens.includes(root.batteryScreen)) {
                root.closeBattery();
                root.batteryScreen = null;
            }
            if (root.soundOpen && !Quickshell.screens.includes(root.soundScreen)) {
                root.closeSound();
                root.soundScreen = null;
            }
            if (root.displaysOpen && !Quickshell.screens.includes(root.displaysScreen)) {
                root.closeDisplays();
                root.displaysScreen = null;
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
        target: "launcher"

        function toggle(): void {
            root.toggleLauncher("apps");
        }
        function clipboard(): void {
            root.toggleLauncher("clipboard");
        }
        function close(): void {
            root.closeLauncher();
        }
        function isOpen(): bool {
            return root.launcherOpen;
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggleOverview(null);
        }
        function open(): void {
            root.openOverview(null);
        }
        function close(): void {
            root.closeOverview();
        }
        function isOpen(): bool {
            return root.overviewOpen;
        }
    }

    IpcHandler {
        target: "updatespanel"

        function toggle(): void {
            root.toggleUpdates(null);
        }
        function open(): void {
            root.openUpdates(null);
        }
        function close(): void {
            root.closeUpdates();
        }
    }

    IpcHandler {
        target: "displayspanel"

        function toggle(): void {
            root.toggleDisplays(null);
        }
        function open(): void {
            root.openDisplays(null);
        }
        function close(): void {
            root.closeDisplays();
        }
        function isOpen(): bool {
            return root.displaysOpen;
        }
    }

    IpcHandler {
        target: "soundpanel"

        function toggle(): void {
            root.toggleSound(null);
        }
        function open(): void {
            root.openSound(null);
        }
        function close(): void {
            root.closeSound();
        }
        function isOpen(): bool {
            return root.soundOpen;
        }
    }

    IpcHandler {
        target: "batterypanel"

        function toggle(): void {
            root.toggleBattery(null);
        }
        function open(): void {
            root.openBattery(null);
        }
        function close(): void {
            root.closeBattery();
        }
        function isOpen(): bool {
            return root.batteryOpen;
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
