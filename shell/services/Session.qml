pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Session actions for the action center's Power page. Logout, reboot and power off need confirmation when clicked
// or chosen with Enter; their letter keys run them at once.
Singleton {
    id: root

    // While updates wait, two more actions install them on the way to a restart or power off.
    readonly property var actions: [...baseActions, ...(Updates.count > 0 ? updateActions : [])]

    readonly property var updateActions: [
        {
            id: "updateReboot",
            label: I18n.t("session.updateReboot"),
            icon: Icons.update,
            key: "a",
            confirm: true,
            update: "reboot"
        },
        {
            id: "updatePoweroff",
            label: I18n.t("session.updatePoweroff"),
            icon: Icons.update,
            key: "w",
            confirm: true,
            update: "poweroff"
        }
    ]

    readonly property var baseActions: [
        {
            id: "lock",
            label: I18n.t("session.lock"),
            icon: Icons.lock,
            key: "l",
            confirm: false,
            command: ["loginctl", "lock-session"]
        },
        {
            id: "suspend",
            label: I18n.t("session.suspend"),
            icon: Icons.sleep,
            key: "u",
            confirm: false,
            command: ["systemctl", "suspend"]
        },
        {
            id: "logout",
            label: I18n.t("session.logout"),
            icon: Icons.logout,
            key: "e",
            confirm: true,
            command: ["hyprctl", "dispatch", "hl.dsp.exit()"]
        },
        {
            id: "reboot",
            label: I18n.t("session.reboot"),
            icon: Icons.restart,
            key: "r",
            confirm: true,
            command: ["systemctl", "reboot"]
        },
        {
            id: "poweroff",
            label: I18n.t("session.poweroff"),
            icon: Icons.power,
            key: "s",
            confirm: true,
            command: ["systemctl", "poweroff"]
        }
    ]

    property int selectedIndex: 0
    property var confirmAction: null
    // Cancel is preselected in a confirmation, so pressing Enter twice cannot power off.
    property bool confirmSelected: false

    property var pendingCommand: null

    /** Returns the keyboard selection to the first action. */
    function resetSelection() {
        selectedIndex = 0;
        cancelConfirm();
    }

    /**
     * Moves the keyboard selection.
     * @param {int} delta  direction
     */
    function move(delta) {
        if (confirmAction)
            confirmSelected = !confirmSelected;
        else
            selectedIndex = (selectedIndex + delta + actions.length) % actions.length;
    }

    /** Closes the confirmation. */
    function cancelConfirm() {
        confirmAction = null;
        confirmSelected = false;
    }

    /**
     * Runs an action or asks for confirmation.
     * @param {object} action  entry from actions
     */
    function choose(action) {
        if (action.confirm) {
            confirmAction = action;
            confirmSelected = false;
        } else {
            run(action);
        }
    }

    /** Handles Enter on the selected item. */
    function activate() {
        if (!confirmAction) {
            choose(actions[selectedIndex]);
        } else if (confirmSelected) {
            run(confirmAction);
        } else {
            cancelConfirm();
        }
    }

    /**
     * Handles an action's shortcut key.
     * @param {string} key  pressed key
     * @returns {bool} whether an action matched
     */
    function pressKey(key) {
        if (confirmAction)
            return false;
        const action = actions.find(a => a.key === key);
        // A letter key is a deliberate choice, so it runs at once; a click or Enter still asks for confirmation.
        if (action)
            run(action);
        return action !== undefined;
    }

    /**
     * Closes the panel and runs an action after a short delay, so the panel is gone before the lock screen captures the display.
     * @param {object} action  entry from actions
     */
    function run(action) {
        cancelConfirm();
        Panels.close("actioncenter");
        if (action.update) {
            Updates.installOffline(action.update);
            return;
        }
        pendingCommand = action.command;
        runDelay.restart();
    }

    /**
     * Runs an action by id.
     * @param {string} id  action id
     */
    function runById(id) {
        const action = actions.find(a => a.id === id);
        if (action)
            run(action);
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

        function move(delta: int): void {
            root.move(delta);
        }
        function activate(): void {
            root.activate();
        }
        function press(key: string): bool {
            return root.pressKey(key);
        }
        function cancel(): void {
            root.cancelConfirm();
        }
        function describe(): string {
            return JSON.stringify({
                open: Panels.isOpen("actioncenter") && Panels.actionCenterPage === "power",
                selected: root.actions[root.selectedIndex].id,
                confirm: root.confirmAction?.id ?? null,
                confirmSelected: root.confirmSelected
            });
        }
    }
}
