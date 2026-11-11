pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire

// Whether an application uses the microphone or the camera, or captures the screen, and which one,
// for the bar indicators.
Singleton {
    id: root

    // Streams that record the sound of an output rather than a microphone do not count.
    readonly property var microphoneStreams: Audio.recordingStreams.filter(n => n.properties?.["stream.capture.sink"] !== "true" && !(n.properties?.["target.object"] ?? "").endsWith(".monitor"))
    readonly property var microphoneApps: appNames(microphoneStreams)
    readonly property bool microphoneInUse: microphoneStreams.length > 0

    property var cameraApps: []
    readonly property bool cameraInUse: cameraApps.length > 0

    // Screen sharing through the portal reaches applications as a PipeWire video stream.
    readonly property var screenApps: appNames(Pipewire.nodes.values.filter(n => n.isStream && n.properties?.["media.class"] === "Stream/Input/Video"))
    // The shell's own recording has its own indicator, and brief captures such as screenshots are ignored.
    readonly property bool screenCaptured: captures > 0 && captureSettled.done && !Capture.recording

    property int captures: 0

    /**
     * Returns the distinct application names of PipeWire nodes.
     * @param {list} nodes  stream nodes
     * @returns {list} names
     */
    function appNames(nodes) {
        const names = nodes.map(n => n.properties?.["application.name"] || n.properties?.["application.process.binary"] || n.name);
        return [...new Set(names.filter(Boolean))];
    }

    // Stream properties, such as the application name, arrive only for tracked nodes.
    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(n => n.isStream)
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "screencast")
                return;
            root.captures = Math.max(0, root.captures + (event.data.startsWith("1") ? 1 : -1));
            if (root.captures > 0) {
                captureSettled.done = false;
                captureSettled.restart();
            }
        }
    }

    Timer {
        id: captureSettled
        property bool done: false
        interval: 1000
        onTriggered: done = true
    }

    // Browsers open the camera directly rather than through PipeWire, so its device is checked instead.
    Timer {
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!cameraCheck.running)
                cameraCheck.running = true;
        }
    }

    Process {
        id: cameraCheck
        // Prints the name of every process that holds a camera device.
        command: ["sh", "-c", "for pid in $(fuser /dev/video* 2>/dev/null); do cat /proc/$pid/comm; done"]
        stdout: StdioCollector {
            onStreamFinished: root.cameraApps = [...new Set(text.split("\n").filter(Boolean))]
        }
    }

    IpcHandler {
        target: "privacy"

        function describe(): string {
            return JSON.stringify({
                microphone: root.microphoneApps,
                camera: root.cameraApps,
                screen: root.screenCaptured,
                screenApps: root.screenApps,
                captures: root.captures
            });
        }
    }
}
