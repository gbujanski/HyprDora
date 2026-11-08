pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU and memory from /proc, without starting processes. Reading happens only
// after acquire(), that is, while a statistics view is open.
Singleton {
    id: root

    property int consumers: 0
    readonly property bool active: consumers > 0

    // Values 0..1; cpu < 0 means two samples are not available yet.
    property real cpu: -1
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real memory: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real swap: swapTotal > 0 ? swapUsed / swapTotal : 0

    property var previous: null

    /** Registers a consumer and starts reading. */
    function acquire() {
        consumers += 1;
        if (consumers === 1) {
            sample();
            // The first result comes after a short pause rather than a full interval.
            firstSample.restart();
        }
    }

    /** Removes a consumer and stops reading after the last one. */
    function release() {
        consumers = Math.max(0, consumers - 1);
        if (consumers === 0) {
            // A difference spanning the closed period would be an average, not the current load.
            previous = null;
            cpu = -1;
        }
    }

    /** Reads CPU and memory once. */
    function sample() {
        statFile.reload();
        memFile.reload();
    }

    /**
     * Updates CPU load from /proc/stat.
     * @param {string} text  file contents
     */
    function parseStat(text) {
        const line = text.split("\n", 1)[0];
        const v = line.trim().split(/\s+/).slice(1, 9).map(Number);
        if (v.length < 8 || v.some(isNaN)) return;
        const idle = v[3] + v[4];
        const total = v.reduce((a, b) => a + b, 0);
        if (previous !== null && total > previous.total) {
            cpu = Math.max(0, Math.min(1, 1 - (idle - previous.idle) / (total - previous.total)));
        }
        previous = { idle, total };
    }

    /**
     * Updates memory and swap from /proc/meminfo.
     * @param {string} text  file contents
     */
    function parseMeminfo(text) {
        const values = {};
        for (const line of text.split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m) values[m[1]] = Number(m[2]) * 1024;
        }
        memTotal = values.MemTotal ?? 0;
        memUsed = memTotal - (values.MemAvailable ?? values.MemFree ?? 0);
        swapTotal = values.SwapTotal ?? 0;
        swapUsed = swapTotal - (values.SwapFree ?? 0);
    }

    /**
     * Formats bytes in gigabytes.
     * @param {real} bytes  size
     * @returns {string}
     */
    function formatBytes(bytes) {
        const gib = bytes / 1073741824;
        return gib >= 10 ? `${Math.round(gib)} GB` : `${gib.toLocaleString(I18n.locale, "f", 1)} GB`;
    }

    /** Opens the process monitor. */
    function openMonitor() {
        Quickshell.execDetached(Settings.btopCommand);
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: root.parseStat(text())
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: root.parseMeminfo(text())
    }

    Timer {
        id: firstSample
        interval: 400
        onTriggered: root.sample()
    }

    Timer {
        interval: Settings.statsInterval
        running: root.active
        repeat: true
        onTriggered: root.sample()
    }

    IpcHandler {
        target: "systemstats"

        function describe(): string {
            return JSON.stringify({ active: root.active, consumers: root.consumers, cpu: root.cpu, memory: root.memory, memUsed: root.memUsed, memTotal: root.memTotal, swap: root.swap });
        }
    }
}
