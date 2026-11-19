import QtQuick

// A download repeated on a schedule; its owner does the work on run() and keeps the data. The task decides
// when it may run: with needsNetwork, not while offline, and on a metered network only with allowMetered. A
// run missed meanwhile happens as soon as it is allowed again, and once the network returns, which is also
// how a run due while the computer slept catches up after waking.
// The time to wait is counted from the clock, so a run counts as done when emitted, unless the owner reports
// it failed(), which tries again after retryInterval.
QtObject {
    id: root

    // Time between runs, in milliseconds.
    property int interval
    // Time between a failed run and the next try.
    property int retryInterval: interval
    // Wait before the first run after the shell starts.
    property int delay: 0
    property bool enabled: true
    property bool needsNetwork: true
    property bool allowMetered: false
    // When it last ran, in milliseconds since the epoch; an owner with data kept from before sets it, so a
    // restarted shell does not download again what is still fresh.
    property real lastRun: 0
    property bool retrying: false

    readonly property bool allowed: enabled && (!needsNetwork || (Network.connected && (allowMetered || !Network.metered)))
    readonly property real startedAt: Date.now()
    // Set once made: properties given while it is being made change before its owner listens to run().
    property bool ready: false

    signal run

    /** Reports a run failed, scheduled or not; it is tried again after retryInterval. */
    function failed() {
        lastRun = Date.now();
        retrying = true;
        schedule();
    }

    /** Reports a run done outside the schedule, such as one asked for by hand, so the next waits a full interval. */
    function succeeded() {
        lastRun = Date.now();
        retrying = false;
        schedule();
    }

    /** Runs now if allowed and due, and waits for the next run. */
    function check() {
        if (!ready)
            return;
        if (allowed && Date.now() >= nextRun()) {
            lastRun = Date.now();
            retrying = false;
            run();
        }
        schedule();
    }

    /**
     * Returns when the next run is due.
     * @returns {real} milliseconds since the epoch
     */
    function nextRun() {
        if (lastRun === 0)
            return startedAt + delay;
        return lastRun + (retrying ? retryInterval : interval);
    }

    /** Sets the timer for the next run, while running is allowed. */
    function schedule() {
        if (!ready)
            return;
        if (!allowed) {
            timer.stop();
            return;
        }
        timer.interval = Math.max(1000, nextRun() - Date.now());
        timer.restart();
    }

    onAllowedChanged: check()
    onIntervalChanged: schedule()
    onLastRunChanged: schedule()
    Component.onCompleted: {
        ready = true;
        check();
    }

    // A computer waking reconnects to the network, which is when a run due during sleep catches up.
    property Connections network: Connections {
        target: Network
        function onConnectedChanged() {
            if (Network.connected)
                root.check();
        }
    }

    property Timer timer: Timer {
        onTriggered: root.check()
    }
}
