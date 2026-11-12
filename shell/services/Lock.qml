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

    property string pendingPassword: ""

    readonly property string marker: `${Quickshell.env("XDG_RUNTIME_DIR")}/hyprdora/locked-${Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")}`

    /** Locks the session. */
    function lock() {
        if (active)
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
        pam.start();
    }

    PamContext {
        id: pam

        config: "hyprdora-lock"

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.pendingPassword);
            root.pendingPassword = "";
        }

        onCompleted: result => {
            root.pendingPassword = "";
            if (result === PamResult.Success) {
                root.active = false;
                Quickshell.execDetached(["rm", "-f", root.marker]);
            } else {
                root.failures++;
            }
        }

        onError: () => {
            root.pendingPassword = "";
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
