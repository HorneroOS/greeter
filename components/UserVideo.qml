// UserVideo — OPT-IN administrator-supplied video background.
//
// Loaded by Main.qml through a Loader only when theme.conf
// backgroundImage names a video file, so QtMultimedia stays an optional
// dependency: without qt6-multimedia this file fails to load and the
// generative HorizonField stays on screen. Nothing is bundled; the file is
// the administrator's own content, muted and looped, paused with reduced
// motion (the first frame stays as a still).
import QtQuick
import QtMultimedia

Item {
    id: root

    property url source
    property bool reducedMotion: false
    readonly property bool ready: player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia || player.playbackState === MediaPlayer.PlayingState
    readonly property bool failed: player.error !== MediaPlayer.NoError || player.mediaStatus === MediaPlayer.InvalidMedia

    Accessible.ignored: true

    MediaPlayer {
        id: player

        source: root.source
        loops: MediaPlayer.Infinite
        videoOutput: output
        audioOutput: null
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia) {
                if (root.reducedMotion)
                    pause();
                else
                    play();
            }
        }
    }

    VideoOutput {
        id: output

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
