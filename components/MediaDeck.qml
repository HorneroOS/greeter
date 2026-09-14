import QtQuick
import QtMultimedia
import "MediaCatalog.js" as Catalog

// MediaDeck — Qt6 dual-player background video sequencer.
//
// Two MediaPlayer/VideoOutput pairs crossfade into each other: while the
// active player finishes its clip, the idle player preloads the next entry
// and fades in over effectiveCrossfade milliseconds. Broken clips are
// skipped with a bounded retry budget; when nothing is playable (empty or
// fully broken pack, or videoEnabled == false) the deck stops and emits
// showFallback() so the greeter shows its local static image instead.
Item {
    id: deck

    property var catalog: null
    property string daypart: "day"
    property bool videoEnabled: true
    property int crossfadeDuration: 3000
    property bool testMode: false
    property int maxErrors: 3

    property int effectiveCrossfade: Catalog.clampCrossfade(crossfadeDuration)
    property var sequencer: null
    property bool hasVideo: false

    property var _activePlayer: playerA
    property var _activeOutput: videoA
    property var _idlePlayer: playerB
    property var _idleOutput: videoB

    signal showFallback
    signal backgroundPressed

    function _makeSequencer() {
        var entries = Catalog.entriesForDaypart(catalog, daypart);
        var seed = testMode ? Catalog.TEST_SEED : -1;
        var opts = {
            maxErrors: maxErrors
        };
        if (testMode) {
            opts.seed = seed;
        }
        return Catalog.createSequencer(entries, opts);
    }

    function _playNextOn(player) {
        if (!sequencer) {
            return false;
        }
        var entry = sequencer.next();
        if (!entry) {
            return false;
        }
        player._currentId = entry.id;
        player.source = entry.url;
        player.play();
        return true;
    }

    function _stopAll() {
        playerA.stop();
        playerB.stop();
        playerA.source = "";
        playerB.source = "";
        videoA.opacity = 0;
        videoB.opacity = 0;
        hasVideo = false;
    }

    function _failOver() {
        _stopAll();
        deck.showFallback();
    }

    function _onPlayerError(player) {
        if (!sequencer || player._currentId === "") {
            return;
        }
        sequencer.reportBroken(player._currentId);
        player._currentId = "";
        if (player === deck._activePlayer) {
            if (!_playNextOn(player) && sequencer.pending() === 0) {
                _failOver();
            }
        } else if (sequencer.pending() === 0 && deck._activePlayer.playbackState !== MediaPlayer.PlayingState) {
            _failOver();
        }
    }

    function start() {
        stop();
        if (!videoEnabled) {
            deck.showFallback();
            return;
        }
        sequencer = _makeSequencer();
        if (!_playNextOn(_activePlayer)) {
            _failOver();
            return;
        }
        _activeOutput.opacity = 1;
        hasVideo = true;
        pollTimer.start();
    }

    function stop() {
        pollTimer.stop();
        settleTimer.stop();
        _stopAll();
        sequencer = null;
    }

    onCatalogChanged: {
        if (deck.visible) {
            start();
        }
    }
    onDaypartChanged: {
        if (deck.visible) {
            start();
        }
    }
    onVideoEnabledChanged: {
        if (deck.visible) {
            start();
        }
    }

    MediaPlayer {
        id: playerA
        property string _currentId: ""
        videoOutput: videoA
        loops: MediaPlayer.NoLoop
        onErrorOccurred: function (error, errorString) {
            deck._onPlayerError(playerA);
        }
        onMediaStatusChanged: function (status) {
            if (status === MediaPlayer.EndOfMedia) {
                if (!deck._playNextOn(playerA) && deck.sequencer && deck.sequencer.pending() === 0) {
                    deck._failOver();
                }
            }
        }
    }

    VideoOutput {
        id: videoA
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: deck.effectiveCrossfade
                easing.type: Easing.InOutQuad
            }
        }
    }

    MediaPlayer {
        id: playerB
        property string _currentId: ""
        videoOutput: videoB
        loops: MediaPlayer.NoLoop
        onErrorOccurred: function (error, errorString) {
            deck._onPlayerError(playerB);
        }
        onMediaStatusChanged: function (status) {
            if (status === MediaPlayer.EndOfMedia) {
                if (!deck._playNextOn(playerB) && deck.sequencer && deck.sequencer.pending() === 0) {
                    deck._failOver();
                }
            }
        }
    }

    VideoOutput {
        id: videoB
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: deck.effectiveCrossfade
                easing.type: Easing.InOutQuad
            }
        }
    }

    MouseArea {
        id: deckMouse
        anchors.fill: parent
        onPressed: deck.backgroundPressed()
    }

    Timer {
        id: pollTimer
        interval: 1000
        running: false
        repeat: true
        onTriggered: {
            var active = deck._activePlayer;
            var idle = deck._idlePlayer;
            if (active.playbackState !== MediaPlayer.PlayingState) {
                return;
            }
            if (active.duration <= 0) {
                return;
            }
            var remaining = active.duration - active.position;
            if (remaining <= 10000 && idle.playbackState !== MediaPlayer.PlayingState && idle.source.toString() === "") {
                if (!deck._playNextOn(idle) && deck.sequencer && deck.sequencer.pending() === 0) {
                    return;
                }
            }
            if (remaining <= deck.effectiveCrossfade) {
                deck._idlePlayer = active;
                deck._idleOutput = deck._activeOutput;
                deck._activePlayer = idle;
                deck._activeOutput = (idle === playerA) ? videoA : videoB;
                deck._idleOutput.opacity = 0;
                deck._activeOutput.opacity = 1;
                settleTimer.start();
            }
        }
    }

    Timer {
        id: settleTimer
        interval: deck.effectiveCrossfade + 1000
        running: false
        repeat: false
        onTriggered: {
            deck._idlePlayer.stop();
            deck._idlePlayer.source = "";
            deck._idlePlayer._currentId = "";
        }
    }
}
