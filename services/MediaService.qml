pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(p => p.dbusName.indexOf("playerctld") < 0)
    readonly property var player: players.find(p => p.isPlaying) ?? (players.indexOf(_last) >= 0 ? _last : (players[0] ?? null))
    readonly property bool available: player !== null
    readonly property var listedPlayers: players.filter(p => p.canPlay)

    property var _last: null
    onPlayerChanged: if (player) Qt.callLater(() => _last = player)

    readonly property bool playing: player ? player.isPlaying : false
    readonly property string title: player ? (player.trackTitle ?? "") : ""
    readonly property string artist: player ? (player.trackArtist ?? "") : ""
    readonly property string album: player ? (player.trackAlbum ?? "") : ""
    readonly property string artUrl: player ? (player.trackArtUrl ?? "") : ""
    readonly property string identity: player ? (player.identity ?? "") : ""
    readonly property string desktopEntry: player ? (player.desktopEntry ?? "") : ""
    readonly property real position: player ? player.position : 0
    readonly property real length: player ? player.length : 0

    readonly property bool canPlayPause: player ? player.canTogglePlaying : false
    readonly property bool canNext: player ? player.canGoNext : false
    readonly property bool canPrevious: player ? player.canGoPrevious : false
    readonly property bool canSeek: player ? player.canSeek : false

    signal trackChanged

    function playPause() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }
    function play() {
        if (player && player.canPlay)
            player.play();
    }
    function pause() {
        if (player && player.canPause)
            player.pause();
    }
    function next() {
        if (player && player.canGoNext)
            player.next();
    }
    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }
    function seek(seconds) {
        if (player && player.canSeek)
            player.position = seconds;
    }
    function updatePosition() {
        if (player)
            player.positionChanged();
    }
    function raise() {
        if (player && player.canRaise)
            player.raise();
    }

    Connections {
        target: root.player
        function onTrackChanged() {
            root.trackChanged();
        }
    }
}
