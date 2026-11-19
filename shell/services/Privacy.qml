pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.base

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
    // Hyprland says only whether a capture is of a monitor or of a window, not who makes it, so the window
    // previews of the shell's overview are counted out: a window capture shows only when there are more of
    // them than the overview's own.
    readonly property bool screenCaptured: (monitorCaptures > 0 || windowCaptures > ownHeld) && captureSettled.done && !Capture.recording

    property int monitorCaptures: 0
    property int windowCaptures: 0
    // Window captures the overview runs now, set by it; a drop is taken a moment later, as Hyprland reports
    // the captures ending just after the overview's previews go.
    property int ownWindowCaptures: 0
    property int ownHeld: 0

    onOwnWindowCapturesChanged: {
        if (ownWindowCaptures >= ownHeld) {
            ownHeld = ownWindowCaptures;
            ownDrop.stop();
        } else {
            ownDrop.restart();
        }
    }

    Timer {
        id: ownDrop
        interval: 1000
        onTriggered: root.ownHeld = root.ownWindowCaptures
    }

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
            // Such as "1,window" when a capture starts and "0,monitor" when one ends.
            if (event.name !== "screencast")
                return;
            const [state, owner] = event.data.split(",");
            const step = state === "1" ? 1 : -1;
            if (owner === "window")
                root.windowCaptures = Math.max(0, root.windowCaptures + step);
            else
                root.monitorCaptures = Math.max(0, root.monitorCaptures + step);
            if (step > 0) {
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

    // Browsers open the camera directly rather than through PipeWire, so who holds its device is checked at
    // start and whenever a camera is opened, closed or plugged in.
    EventSubscription {
        stream: "camera"
        onEvent: cameraDelay.restart()
    }

    // An application often opens and closes the device several times while starting the camera.
    Timer {
        id: cameraDelay
        interval: 300
        running: true
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
                monitorCaptures: root.monitorCaptures,
                windowCaptures: root.windowCaptures,
                overviewCaptures: root.ownHeld
            });
        }
    }
}
