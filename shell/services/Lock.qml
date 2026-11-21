pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// Lock state and password check. Hyprland keeps the session locked through the session lock protocol until the
// lock screen unlocks it, and the only place that does is a successful PAM check below; nothing else, IPC
// included, can unlock. While locked, a marker file tells the shell service that a stop must end the session:
// a crashed lock screen then logs out to the login screen instead of leaving Hyprland's fallback screen.
Singleton {
    id: root

    // Whether the lock screen is requested; the lock surfaces follow it.
    property bool active: false
    // True while PAM checks a password.
    readonly property bool checking: pam.active
    // Bumped after a wrong password, so the lock screen can flash.
    property int failures: 0
    // What PAM said with its refusal, such as the account locked after too many wrong passwords.
    property string message: ""
    // PAM's lines of the check under way; the last before it asks for the password is the prompt itself.
    property var pamLines: []

    property string pendingPassword: ""

    readonly property string marker: `${Quickshell.env("XDG_RUNTIME_DIR")}/hyprdora/locked-${Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")}`

    /** Locks the session. */
    function lock() {
        // The update screen holds the session lock while updates download, with nothing to unlock behind it.
        if (active || Updates.updating)
            return;
        markerFile.setText("locked\n");
        active = true;
    }

    /**
     * Checks a password with PAM; the session unlocks only if PAM accepts it.
     * @param {string} password  typed password
     */
    function tryUnlock(password) {
        if (!active || pam.active || password === "")
            return;
        pendingPassword = password;
        message = "";
        pamLines = [];
        pam.start();
    }

    PamContext {
        id: pam

        config: "hyprdora-lock"

        // Quickshell gives PAM's errors as plain messages, so every line is kept but the password prompt.
        onMessageChanged: {
            if (message.trim() !== "")
                root.pamLines = [...root.pamLines, message.trim()];
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            root.pamLines = root.pamLines.slice(0, -1);
            respond(root.pendingPassword);
            root.pendingPassword = "";
        }

        onCompleted: result => {
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                root.message = "";
                root.active = false;
                Quickshell.execDetached(["rm", "-f", root.marker]);
            } else {
                root.message = root.pamLines.join("\n");
                root.failures++;
            }
            root.pamLines = [];
        }

        onError: () => {
            root.pendingPassword = "";
            root.message = root.pamLines.join("\n");
            root.pamLines = [];
            root.failures++;
        }
    }

    FileView {
        id: markerFile
        path: root.marker
        printErrors: false
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }
        function isLocked(): bool {
            return root.active;
        }
    }
}
