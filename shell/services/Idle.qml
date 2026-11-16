pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import qs.config

// Dims the screen, locks and suspends after inactivity. Inhibitors, such as a playing video, postpone every step.
Singleton {
    id: root

    // "Coffee": while true, nothing dims, locks or suspends. It is not saved, so a restart cannot leave the
    // laptop without its lock for good.
    property bool paused: false
    onPausedChanged: {
        if (paused)
            undim();
    }

    // Screen level from before dimming, -1 when not dimmed.
    property real dimmedFrom: -1
    readonly property real dimLevel: 0.1
    // A nested session from `make dev` would otherwise dim, lock and suspend the real laptop.
    readonly property bool dev: (Quickshell.env("HYPRDORA_SHELL") ?? "") !== ""

    /**
     * Runs a command, or only logs it in a nested session.
     * @param {array} command  program and arguments
     */
    function run(command) {
        if (dev)
            console.info("idle: would run", command.join(" "));
        else
            Quickshell.execDetached(command);
    }

    /** Lowers the screen brightness and remembers the previous level. */
    function dim() {
        if (dev) {
            console.info("idle: would dim the screen");
            return;
        }
        const screen = Brightness.display;
        if (!screen.available || screen.level <= dimLevel)
            return;
        dimmedFrom = screen.level;
        screen.setLevel(dimLevel, true);
    }

    /** Restores the brightness from before dimming. */
    function undim() {
        if (dimmedFrom < 0)
            return;
        Brightness.display.setLevel(dimmedFrom, true);
        dimmedFrom = -1;
    }

    // Quickshell 0.2.1 keeps a monitor's first timeout until it is turned off and on again.
    component Step: IdleMonitor {
        property bool wanted: true
        property bool restarting: false

        enabled: wanted && timeout > 0 && !restarting
        respectInhibitors: true
        onTimeoutChanged: {
            restarting = true;
            Qt.callLater(() => restarting = false);
        }
    }

    Step {
        id: dimMonitor
        wanted: !root.paused
        timeout: Settings.idleDim
        onIsIdleChanged: isIdle ? root.dim() : root.undim()
    }

    Step {
        id: lockMonitor
        wanted: !root.paused
        timeout: Settings.idleLock
        onIsIdleChanged: {
            if (isIdle)
                root.run(["loginctl", "lock-session"]);
        }
    }

    Step {
        id: suspendMonitor
        wanted: UPower.onBattery && !root.paused
        timeout: Settings.idleSuspend
        onIsIdleChanged: {
            if (isIdle)
                root.run(["systemctl", "suspend"]);
        }
    }

    IpcHandler {
        target: "idle"

        function setPaused(value: bool): void {
            root.paused = value;
        }

        function describe(): string {
            return JSON.stringify({
                dim: {
                    enabled: dimMonitor.enabled,
                    timeout: dimMonitor.timeout,
                    idle: dimMonitor.isIdle
                },
                lock: {
                    enabled: lockMonitor.enabled,
                    timeout: lockMonitor.timeout,
                    idle: lockMonitor.isIdle
                },
                suspend: {
                    enabled: suspendMonitor.enabled,
                    timeout: suspendMonitor.timeout,
                    idle: suspendMonitor.isIdle
                },
                dimmedFrom: root.dimmedFrom,
                paused: root.paused,
                dev: root.dev
            });
        }
    }
}
