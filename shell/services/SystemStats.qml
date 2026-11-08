pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU i pamięć z /proc, bez uruchamiania procesów. Odczyt trwa tylko wtedy,
// gdy ktoś wywołał acquire(), czyli przy otwartym widoku ze statystykami.
Singleton {
    id: root

    property int consumers: 0
    readonly property bool active: consumers > 0

    // Wartości 0..1; cpu < 0 oznacza, że nie ma jeszcze dwóch próbek.
    property real cpu: -1
    property real memTotal: 0
    property real memUsed: 0
    property real swapTotal: 0
    property real swapUsed: 0
    readonly property real memory: memTotal > 0 ? memUsed / memTotal : 0
    readonly property real swap: swapTotal > 0 ? swapUsed / swapTotal : 0

    property var previous: null

    function acquire() {
        consumers += 1;
        if (consumers === 1) {
            sample();
            // Pierwszy wynik po krótkiej przerwie zamiast po pełnym interwale.
            firstSample.restart();
        }
    }

    function release() {
        consumers = Math.max(0, consumers - 1);
        if (consumers === 0) {
            // Różnica liczona przez czas zamknięcia panelu byłaby średnią, a nie bieżącym obciążeniem.
            previous = null;
            cpu = -1;
        }
    }

    function sample() {
        statFile.reload();
        memFile.reload();
    }

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

    function formatBytes(bytes) {
        const gib = bytes / 1073741824;
        return gib >= 10 ? `${Math.round(gib)} GB` : `${gib.toFixed(1).replace(".", ",")} GB`;
    }

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
