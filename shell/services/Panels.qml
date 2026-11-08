pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Stan paneli wspólny dla pasków, skrótów klawiszowych i samych paneli.
Singleton {
    id: root

    property bool actionCenterOpen: false
    property var actionCenterScreen: null
    property string actionCenterPage: "main"

    property bool calendarOpen: false
    property var calendarScreen: null

    function focusedScreen() {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0] ?? null;
    }

    function openActionCenter(screen, page) {
        actionCenterScreen = screen ?? focusedScreen();
        actionCenterPage = page || "main";
        actionCenterOpen = actionCenterScreen !== null;
        // Oba panele przejmują klawiaturę, więc otwarty jest najwyżej jeden.
        if (actionCenterOpen) calendarOpen = false;
    }

    function closeActionCenter() {
        actionCenterOpen = false;
    }

    // Ponowne wywołanie dla tej samej strony i ekranu zamyka panel,
    // a dla innej strony lub ekranu przenosi go tam.
    function toggleActionCenter(screen, page) {
        const target = screen ?? focusedScreen();
        const samePlace = target === actionCenterScreen && (page || "main") === actionCenterPage;
        if (actionCenterOpen && samePlace) closeActionCenter();
        else openActionCenter(target, page);
    }

    function openCalendar(screen) {
        calendarScreen = screen ?? focusedScreen();
        calendarOpen = calendarScreen !== null;
        if (calendarOpen) actionCenterOpen = false;
    }

    function closeCalendar() {
        calendarOpen = false;
    }

    function toggleCalendar(screen) {
        const target = screen ?? focusedScreen();
        if (calendarOpen && target === calendarScreen) closeCalendar();
        else openCalendar(target);
    }

    // Ekran z otwartym panelem mógł właśnie zostać odłączony.
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

    // Tutaj, a nie w Session: ten singleton istnieje od startu, więc skrót działa od razu.
    IpcHandler {
        target: "powermenu"

        function toggle(): void { root.toggleActionCenter(null, "power"); }
    }
}
