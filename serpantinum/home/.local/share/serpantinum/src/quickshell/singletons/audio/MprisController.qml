pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"

Singleton {
    id: root

    function playerIdentity(player) {
        if (!player) return "";
        const pid = player.metadata?.["kde:pid"];
        if (pid) return "browser-pid:" + String(pid);
        const name = player.dbusName || "";
        const instance = name.match(/\.instance(\d+)$/);
        return instance ? "browser-pid:" + instance[1] : name;
    }

    function canAdjustSpeed(player) {
        return !!player && player.canControl && player.maxRate > player.minRate;
    }

    function speedPlayerFor(preferred) {
        if (!preferred || root.canAdjustSpeed(preferred)) return preferred;
        const identity = root.playerIdentity(preferred);
        const title = preferred.trackTitle || "";
        const url = String(preferred.metadata?.["xesam:url"] || "");
        if (!identity || (!title && !url)) return preferred;
        return Mpris.players.values.find(candidate => {
            if (!root.canAdjustSpeed(candidate) || root.playerIdentity(candidate) !== identity) return false;
            const candidateUrl = String(candidate.metadata?.["xesam:url"] || "");
            return (url !== "" && candidateUrl === url)
                || (title !== "" && candidate.trackTitle === title);
        }) || preferred;
    }

    readonly property var _playerWatch: {
        let players = Mpris.players.values;
        let states = [];
        for (let i = 0; i < players.length; i++) {
            states.push(players[i].isPlaying);
            states.push(players[i].canControl);
            states.push(players[i].dbusName);
        }
        return states;
    }

    property string lastPlayingBus: ""

    readonly property MprisPlayer activePlayer: {
        let _ = _playerWatch;
        try {
            let players = Mpris.players.values.filter(p => p).sort((a, b) => (a.dbusName || "").localeCompare(b.dbusName || ""));
            let playing = players.find(p => p.isPlaying);
            if (playing) return playing;
            let last = root.lastPlayingBus !== "" ? players.find(p => p.dbusName === root.lastPlayingBus) : null;
            if (last) return last;
            let loaded = players.find(p => p.playbackState !== MprisPlaybackState.Stopped && p.trackTitle !== "");
            if (loaded) return loaded;
            let controllable = players.find(p => p.canControl);
            if (controllable) return controllable;
            return players.length > 0 ? players[0] : null;
        } catch (e) {
            return null;
        }
    }

    readonly property string activePlayerId: activePlayer ? (activePlayer.dbusName || activePlayer.identity || "") : ""
    readonly property bool hasActivePlayer: activePlayer !== null
    readonly property bool isPlaying: {
        try {
            return activePlayer ? activePlayer.isPlaying === true : false;
        } catch (e) {
            return false;
        }
    }
    readonly property string trackTitle: {
        try {
            return activePlayer ? String(activePlayer.trackTitle || "") : "";
        } catch (e) {
            return "";
        }
    }
    readonly property string trackArtist: {
        try {
            return activePlayer ? String(activePlayer.trackArtist || "") : "";
        } catch (e) {
            return "";
        }
    }
    readonly property string currentArtUrl: {
        if (!activePlayer) return "";
        if (activePlayer.trackArtUrl && activePlayer.trackArtUrl !== "") return activePlayer.trackArtUrl;
        if (activePlayer.metadata) {
            let m = activePlayer.metadata;
            if (m["mpris:artUrl"]) return m["mpris:artUrl"];
            if (m["artUrl"]) return m["artUrl"];
            if (m["xesam:url"] && typeof m["xesam:url"] === "string" && (m["xesam:url"].startsWith("http") || m["xesam:url"].startsWith("file://"))) {
                if (m["xesam:url"].match(/\.(jpg|jpeg|png|webp)$/i)) return m["xesam:url"];
            }
        }
        return "";
    }
    property real livePosition: activePlayer ? activePlayer.position : 0

    property string artUrl: ""
    property string blur: ""
    property string grad: ""
    property string textColor: "#cdd6f4"
    property string deviceIcon: "󰓃"
    property string deviceName: "Speaker"
    property bool fetchPending: false

    onActivePlayerChanged: {
        if (root.activePlayer && root.activePlayer.isPlaying) {
            root.lastPlayingBus = root.activePlayer.dbusName || "";
        }
        if (root.activePlayer) {
            root.livePosition = root.activePlayer.position;
        }
        root.queueFetch();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hasActivePlayer && root.isPlaying
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged();
                root.livePosition = root.activePlayer.position;
            }
        }
    }

    Timer {
        id: fetchDebounceTimer
        interval: 60
        repeat: false
        onTriggered: root.fetchArt()
    }

    function queueFetch() {
        fetchDebounceTimer.restart();
    }

    Connections {
        target: root.activePlayer
        function onPositionChanged() {
            if (root.activePlayer) root.livePosition = root.activePlayer.position;
        }
        function onPostTrackChanged() {
            if (root.activePlayer) root.livePosition = root.activePlayer.position;
            root.queueFetch();
        }
        function onTrackArtUrlChanged() {
            root.queueFetch();
        }
        function onTrackTitleChanged() {
            root.queueFetch();
        }
        function onMetadataChanged() {
            root.queueFetch();
        }
        function onPlaybackStateChanged() {
            root.queueFetch();
        }
    }

    Process {
        id: artFetchProc
        command: [
            "bash",
            Caching.qsDir + "/media/art_fetch.sh",
            root.activePlayerId,
            root.currentArtUrl,
            root.trackTitle,
            root.trackArtist
        ]
        onExited: {
            if (root.fetchPending) {
                root.fetchPending = false;
                artFetchProc.running = true;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.deviceIcon = d.deviceIcon || "󰓃";
                        root.deviceName = d.deviceName || "Speaker";

                        if (d.playerId !== root.activePlayerId || d.title !== root.trackTitle || d.artist !== root.trackArtist) {
                            return;
                        }

                        if (d.isPlaceholder === false && d.artUrl) {
                            root.artUrl = d.artUrl;
                            root.blur = d.blur || "";
                            root.grad = d.grad || "";
                            root.textColor = d.textColor || "#cdd6f4";
                        } else {
                            root.artUrl = "";
                            root.blur = "";
                            root.grad = d.grad || "";
                            root.textColor = d.textColor || "#cdd6f4";
                        }
                    } catch(e) {}
                }
            }
        }
    }

    function fetchArt() {
        if (!root.hasActivePlayer) {
            root.artUrl = "";
            root.blur = "";
            root.grad = "";
            root.textColor = "#cdd6f4";
            return;
        }
        if (artFetchProc.running) {
            root.fetchPending = true;
            return;
        }
        root.fetchPending = false;
        artFetchProc.running = true;
    }

    function forceArtRefresh() {
        root.fetchArt();
    }
}
