pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values

    // Ręczny wybór ma pierwszeństwo, potem odtwarzacz, który gra, potem pierwszy z listy.
    property var chosenPlayer: null
    readonly property var player: (chosenPlayer && players.includes(chosenPlayer) ? chosenPlayer : null)
        ?? players.find(p => p.isPlaying)
        ?? players[0]
        ?? null

    readonly property bool hasPlayer: player !== null
    readonly property bool canShowPosition: (player?.positionSupported ?? false)
        && (player?.lengthSupported ?? false)
        && (player?.length ?? 0) > 0
    readonly property real progress: canShowPosition ? player.position / player.length : 0

    function cyclePlayer() {
        if (players.length < 2) return;
        chosenPlayer = players[(players.indexOf(player) + 1) % players.length];
    }

    function seek(fraction) {
        if (player?.canSeek && canShowPosition) player.position = fraction * player.length;
    }

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(total / 60);
        return `${minutes}:${String(total % 60).padStart(2, "0")}`;
    }

    // MPRIS nie zgłasza upływu czasu, więc pozycję odświeżamy tylko gdy jest widoczna.
    Timer {
        interval: 1000
        repeat: true
        running: Panels.actionCenterOpen && (root.player?.isPlaying ?? false)
        onTriggered: root.player.positionChanged()
    }

    IpcHandler {
        target: "media"

        function describe(): string {
            const p = root.player;
            return JSON.stringify({
                players: root.players.map(x => x.identity),
                current: p?.identity ?? null,
                title: p?.trackTitle ?? null,
                artist: p?.trackArtist ?? null,
                playing: p?.isPlaying ?? false,
                art: p?.trackArtUrl ?? null,
                progress: root.progress
            });
        }
        function toggle(): void { root.player?.togglePlaying(); }
        function next(): void { root.player?.next(); }
        function previous(): void { root.player?.previous(); }
        function cycle(): void { root.cyclePlayer(); }
    }
}
