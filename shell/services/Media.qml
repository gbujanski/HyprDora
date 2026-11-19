pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values

    // A manual choice wins, then a playing player, then the first one listed.
    property var chosenPlayer: null
    readonly property var player: (chosenPlayer && players.includes(chosenPlayer) ? chosenPlayer : null) ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property bool hasPlayer: player !== null
    readonly property bool canShowPosition: (player?.positionSupported ?? false) && (player?.lengthSupported ?? false) && (player?.length ?? 0) > 0
    readonly property real progress: canShowPosition ? player.position / player.length : 0

    /** Switches to the next media player. */
    function cyclePlayer() {
        if (players.length < 2)
            return;
        chosenPlayer = players[(players.indexOf(player) + 1) % players.length];
    }

    /**
     * Seeks within the current track.
     * @param {real} fraction  position, 0..1
     */
    function seek(fraction) {
        if (player?.canSeek && canShowPosition)
            player.position = fraction * player.length;
    }

    /**
     * Formats seconds as m:ss.
     * @param {real} seconds  duration
     * @returns {string}
     */
    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds));
        const minutes = Math.floor(total / 60);
        return `${minutes}:${String(total % 60).padStart(2, "0")}`;
    }

    // MPRIS does not report elapsed time, so the position is polled only while visible.
    Timer {
        interval: 1000
        repeat: true
        running: Panels.isOpen("media") && (root.player?.isPlaying ?? false)
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
        function toggle(): void {
            root.player?.togglePlaying();
        }
        function next(): void {
            root.player?.next();
        }
        function previous(): void {
            root.player?.previous();
        }
        function cycle(): void {
            root.cyclePlayer();
        }
    }
}
