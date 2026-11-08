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
    // Strumień odtwarzania też ma isSink == true, dlatego rozpoznajemy go po typie.
    readonly property var playbackStreams: audioNodes(n => n.type === PwNodeType.AudioOutStream)

    function audioNodes(predicate) {
        return Pipewire.nodes.values
            .filter(n => n.audio && predicate(n))
            .sort((a, b) => displayName(a).localeCompare(displayName(b)));
    }

    function displayName(node) {
        if (!node) return "";
        if (node.isStream) return node.properties?.["application.name"] || node.nickname || node.name;
        return node.description || node.nickname || node.name;
    }

    function setNodeVolume(node, value) {
        if (node?.audio) node.audio.volume = Math.max(0, Math.min(1, value));
    }

    function toggleNodeMute(node) {
        if (node?.audio) node.audio.muted = !node.audio.muted;
    }

    function setVolume(value) {
        setNodeVolume(sink, value);
    }

    function changeVolume(delta) {
        setVolume(volume + delta);
    }

    function selectSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    function selectSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    // PipeWire udostępnia właściwości tylko śledzonych węzłów.
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
