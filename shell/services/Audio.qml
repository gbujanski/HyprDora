pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

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

    /**
     * Returns audio nodes accepted by a predicate, sorted by name.
     * @param {function} predicate  test applied to each node
     * @returns {list}
     */
    function audioNodes(predicate) {
        return Pipewire.nodes.values
            .filter(n => n.audio && predicate(n))
            .sort((a, b) => displayName(a).localeCompare(displayName(b)));
    }

    /**
     * Returns a readable name for a node.
     * @param {PwNode} node  node to name
     * @returns {string}
     */
    function displayName(node) {
        if (!node) return "";
        if (node.isStream) return node.properties?.["application.name"] || node.nickname || node.name;
        return node.description || node.nickname || node.name;
    }

    /**
     * Sets a node's volume, clamped to 0..1.
     * @param {PwNode} node  target node
     * @param {real} value  new volume
     */
    function setNodeVolume(node, value) {
        if (node?.audio) node.audio.volume = Math.max(0, Math.min(1, value));
    }

    /**
     * Toggles mute on a node.
     * @param {PwNode} node  target node
     */
    function toggleNodeMute(node) {
        if (node?.audio) node.audio.muted = !node.audio.muted;
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

        function selectSink(name: string): bool {
            const node = root.sinks.find(n => n.name === name);
            if (node) root.selectSink(node);
            return node !== undefined;
        }
        function selectSource(name: string): bool {
            const node = root.sources.find(n => n.name === name);
            if (node) root.selectSource(node);
            return node !== undefined;
        }
        function describe(): string {
            const nodeInfo = n => ({ name: n.name, label: root.displayName(n), volume: n.audio?.volume, muted: n.audio?.muted });
            return JSON.stringify({
                sink: root.sink?.name,
                source: root.source?.name,
                sinks: root.sinks.map(nodeInfo),
                sources: root.sources.map(nodeInfo),
                streams: root.playbackStreams.map(nodeInfo)
            });
        }
    }
}
