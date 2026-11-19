pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.base
import qs.config

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink?.ready ?? false
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool sourceMuted: source?.audio?.muted ?? false

    readonly property var sinks: audioNodes(n => n.type === PwNodeType.AudioSink)
    readonly property var sources: audioNodes(n => n.type === PwNodeType.AudioSource)
    // Playback streams also have isSink == true, so they are recognized by type.
    readonly property var playbackStreams: audioNodes(n => n.type === PwNodeType.AudioOutStream)
    readonly property var recordingStreams: audioNodes(n => n.type === PwNodeType.AudioInStream)

    // Active port of each device, by node name. PipeWire nodes do not carry it, so pactl provides it.
    property var activePorts: ({})
    // Translation keys for ports of built-in sound cards; other devices keep their own names.
    readonly property var portNames: ({
            "analog-output-speaker": "audio.port.speakers",
            "analog-output-headphones": "audio.port.headphones",
            "analog-output-lineout": "audio.port.lineOut",
            "analog-input-internal-mic": "audio.port.internalMic",
            "analog-input-mic": "audio.port.mic",
            "analog-input-headset-mic": "audio.port.headsetMic",
            "analog-input-linein": "audio.port.lineIn"
        })

    /**
     * Returns audio nodes accepted by a predicate, sorted by name.
     * @param {function} predicate  test applied to each node
     * @returns {list}
     */
    function audioNodes(predicate) {
        return Pipewire.nodes.values.filter(n => n.audio && predicate(n)).sort((a, b) => displayName(a).localeCompare(displayName(b)));
    }

    /**
     * Returns a readable name for a node.
     * @param {PwNode} node  node to name
     * @returns {string}
     */
    function displayName(node) {
        if (!node)
            return "";
        if (node.isStream)
            return node.properties?.["application.name"] || node.nickname || node.name;
        const port = activePorts[node.name] ?? "";
        if (portNames[port])
            return I18n.t(portNames[port]);
        if (port.startsWith("hdmi-output") || port.startsWith("iec958"))
            return I18n.t("audio.port.hdmi");
        return node.description || node.nickname || node.name;
    }

    /** Reads the active port of every sound device. */
    function refreshPorts() {
        if (!portReader.running)
            portReader.running = true;
    }

    /**
     * Sets a node's volume, clamped to 0..1.
     * @param {PwNode} node  target node
     * @param {real} value  new volume
     */
    function setNodeVolume(node, value) {
        if (node?.audio)
            node.audio.volume = Math.max(0, Math.min(1, value));
    }

    /**
     * Toggles mute on a node.
     * @param {PwNode} node  target node
     */
    function toggleNodeMute(node) {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    /**
     * Sets the default output volume.
     * @param {real} value  new volume, 0..1
     */
    function setVolume(value) {
        setNodeVolume(sink, value);
    }

    /**
     * Changes the default output volume by a delta.
     * @param {real} delta  amount to add
     */
    function changeVolume(delta) {
        setVolume(volume + delta);
    }

    /**
     * Makes a node the default output.
     * @param {PwNode} node  output node
     */
    function selectSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    /**
     * Makes a node the default input.
     * @param {PwNode} node  input node
     */
    function selectSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    // PipeWire exposes properties only for tracked nodes.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n)
    }

    IpcHandler {
        target: "audio"

        // For the volume and mute keys, which show the indicator: stepVolume 0.05 / stepVolume -0.05.
        function stepVolume(delta: real): void {
            root.changeVolume(delta);
            Indicator.show("volume");
        }
        function toggleMute(): void {
            root.toggleNodeMute(root.sink);
            Indicator.show("volume");
        }
        function toggleMicrophone(): void {
            root.toggleNodeMute(root.source);
            Indicator.show("microphone");
        }
        function selectSink(name: string): bool {
            const node = root.sinks.find(n => n.name === name);
            if (node)
                root.selectSink(node);
            return node !== undefined;
        }
        function selectSource(name: string): bool {
            const node = root.sources.find(n => n.name === name);
            if (node)
                root.selectSource(node);
            return node !== undefined;
        }
        function describe(): string {
            const nodeInfo = n => ({
                        name: n.name,
                        label: root.displayName(n),
                        volume: n.audio?.volume,
                        muted: n.audio?.muted
                    });
            return JSON.stringify({
                sink: root.sink?.name,
                source: root.source?.name,
                sinks: root.sinks.map(nodeInfo),
                sources: root.sources.map(nodeInfo),
                streams: root.playbackStreams.map(nodeInfo)
            });
        }
    }

    Process {
        id: portReader

        // The C locale keeps descriptions out of the way: pactl writes translated ones as invalid JSON.
        command: ["sh", "-c", "LC_ALL=C pactl -f json list sinks; echo; LC_ALL=C pactl -f json list sources"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const ports = {};
                for (const line of text.split("\n")) {
                    if (line.trim() === "")
                        continue;
                    try {
                        for (const device of JSON.parse(line))
                            if (device.active_port)
                                ports[device.name] = device.active_port;
                    } catch (e) {
                        console.warn("audio: unreadable pactl output");
                    }
                }
                root.activePorts = ports;
            }
        }
    }

    // Plugging headphones into the jack switches the port, so changes are followed as they happen.
    EventSubscription {
        stream: "audio"
        onEvent: line => {
            if (/ on (sink|source|card) /.test(line))
                portDelay.restart();
        }
    }

    Timer {
        id: portDelay
        interval: 300
        onTriggered: root.refreshPorts()
    }
}
