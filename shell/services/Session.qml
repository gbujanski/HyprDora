pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Lista akcji sesji na stronie „Zasilanie” w centrum akcji. Wylogowanie, restart i wyłączenie wymagają potwierdzenia.
Singleton {
    id: root

    readonly property var actions: [
        { id: "lock", label: "Zablokuj", icon: Icons.lock, key: "l", confirm: false,
          command: ["loginctl", "lock-session"] },
        { id: "suspend", label: "Uśpij", icon: Icons.sleep, key: "u", confirm: false,
          command: ["systemctl", "suspend"] },
        { id: "logout", label: "Wyloguj", icon: Icons.logout, key: "e", confirm: true,
          command: ["hyprctl", "dispatch", "exit"] },
        { id: "reboot", label: "Uruchom ponownie", icon: Icons.restart, key: "r", confirm: true,
          command: ["systemctl", "reboot"] },
        { id: "poweroff", label: "Wyłącz", icon: Icons.power, key: "s", confirm: true,
          command: ["systemctl", "poweroff"] }
    ]

    property int selectedIndex: 0
    property var confirmAction: null
    // Podczas potwierdzania domyślnie wybrane jest „Anuluj”: dwa Entery nie wyłączą laptopa.
    property bool confirmSelected: false

    property var pendingCommand: null

    function resetSelection() {
        selectedIndex = 0;
        cancelConfirm();
    }

    function move(delta) {
        if (confirmAction) confirmSelected = !confirmSelected;
        else selectedIndex = (selectedIndex + delta + actions.length) % actions.length;
    }

    function cancelConfirm() {
        confirmAction = null;
        confirmSelected = false;
    }

    function choose(action) {
        if (action.confirm) {
            confirmAction = action;
            confirmSelected = false;
        } else {
            run(action);
        }
    }

    function activate() {
        if (!confirmAction) {
            choose(actions[selectedIndex]);
        } else if (confirmSelected) {
            run(confirmAction);
        } else {
            cancelConfirm();
        }
    }

    function pressKey(key) {
        if (confirmAction) return false;
        const action = actions.find(a => a.key === key);
        if (action) choose(action);
        return action !== undefined;
    }

    // Krótka zwłoka: panel znika, zanim blokada zrobi zrzut ekranu.
    function run(action) {
        cancelConfirm();
        Panels.closeActionCenter();
        pendingCommand = action.command;
        runDelay.restart();
    }

    function runById(id) {
        const action = actions.find(a => a.id === id);
        if (action) run(action);
    }

    Timer {
        id: runDelay
        interval: 250
        onTriggered: {
            Quickshell.execDetached(root.pendingCommand);
            root.pendingCommand = null;
        }
    }

    IpcHandler {
        target: "session"

        function move(delta: int): void { root.move(delta); }
        function activate(): void { root.activate(); }
        function press(key: string): bool { return root.pressKey(key); }
        function cancel(): void { root.cancelConfirm(); }
        function describe(): string {
            return JSON.stringify({
                open: Panels.actionCenterOpen && Panels.actionCenterPage === "power",
                selected: root.actions[root.selectedIndex].id,
                confirm: root.confirmAction?.id ?? null,
                confirmSelected: root.confirmSelected
            });
        }
    }
}
