import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../services"

// The island expanded: album art, track, transport and volume.
Item {
    id: root
    property MprisPlayer player: null

    // A player that says it is stopped has nothing to show, whatever
    // it left behind in its metadata. A browser clears the title when
    // the video ends but keeps pointing at a picture — its own logo,
    // in a temporary file — so the island sat there saying nothing was
    // playing beside the browser's badge. Asked of the player's own
    // state rather than guessed from an empty title: a radio that is
    // playing without ever sending metadata is still playing, and
    // keeps its picture.
    AlbumArt {
        id: art
        anchors.left: parent.left
        anchors.top: parent.top
        width: 96
        height: 96
        radius: 12
        source: (root.player && root.player.playbackState !== MprisPlaybackState.Stopped)
            ? root.player.trackArtUrl : ""
    }

    ColumnLayout {
        anchors.left: art.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 10
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: root.player ? (root.player.trackTitle || I18n.t.nothingPlaying)
                              : I18n.t.nothingPlaying
            color: Theme.textPrimary
            font.pixelSize: 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            // A live stream says so here, beside whoever is streaming,
            // rather than alone at the foot of the panel: it is part
            // of what this is, not a reading about it.
            text: {
                if (!root.player) return "";
                const who = root.player.trackArtist || "";
                if (!root.live) return who;
                return who !== "" ? who + " · " + I18n.t.liveNow : I18n.t.liveNow;
            }
            color: Theme.textSecondary
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 4 }

        // ── Transport ──────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 22

            MediaButton {
                kind: "prev"
                size: 22
                available: root.player && root.player.canGoPrevious
                onClicked: root.player.previous()
            }
            MediaButton {
                kind: root.player && root.player.isPlaying ? "pause" : "play"
                size: 26
                available: root.player && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }
            MediaButton {
                kind: "next"
                size: 22
                available: root.player && root.player.canGoNext
                onClicked: root.player.next()
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ── Where you are in it ────────────────────────────────────
    //
    // This strip used to hold the volume of the whole machine, which
    // is one turn of the wheel away in the control centre; what it
    // could not tell you was how far into the track you were, and that
    // is the one thing that belongs to the thing playing.

    // A live stream has no end, and says so by declaring a length of
    // 2^63-1 microseconds — some 292,000 years. Anything past a day is
    // not a duration, it is a way of saying "forever".
    readonly property bool live:
        !root.player || !(root.player.length > 0) || root.player.length > 86400
    readonly property bool canSeek: root.player ? root.player.canSeek : false

    // Quickshell works the position out from the last one it was told
    // and the time since, so asking for it again costs nothing on the
    // bus: this only nudges the bindings that read it.
    Timer {
        running: root.visible && root.player
                 && root.player.playbackState === MprisPlaybackState.Playing
        repeat: true
        interval: 1000
        onTriggered: root.player.positionChanged()
    }

    function clock(seconds) {
        if (!(seconds > 0)) return "0:00";
        const whole = Math.floor(seconds);
        const h = Math.floor(whole / 3600);
        const m = Math.floor((whole % 3600) / 60);
        const s = whole % 60;
        const mm = h > 0 && m < 10 ? "0" + m : String(m);
        const ss = s < 10 ? "0" + s : String(s);
        return (h > 0 ? h + ":" : "") + mm + ":" + ss;
    }

    RowLayout {
        anchors.left: art.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 10

        Text {
            visible: !root.live
            text: root.player ? root.clock(root.player.position) : "0:00"
            color: Theme.textSecondary
            font.pixelSize: 11
            // Kept from twitching as the digits change: a minute going
            // from 9 to 10 moved everything beside it.
            Layout.preferredWidth: Math.max(30, implicitWidth)
            horizontalAlignment: Text.AlignLeft
        }

        SeekBar {
            Layout.fillWidth: true
            visible: !root.live
            position: root.player ? root.player.position : 0
            length: root.player ? root.player.length : 0
            interactive: root.canSeek
            onSought: (s) => { if (root.player) root.player.position = s; }
        }

        // A live stream leaves this strip empty on purpose: there is
        // no position to report and no elapsed time worth reporting —
        // that number is how long this playback has been going, which
        // starts again every time the page does. What it is, is said
        // beside the name above.
        Item { Layout.fillWidth: true; visible: root.live }

        Text {
            text: root.live ? "" : (root.player ? root.clock(root.player.length) : "")
            visible: !root.live
            color: Theme.textSecondary
            font.pixelSize: 11
            Layout.preferredWidth: Math.max(30, implicitWidth)
            horizontalAlignment: Text.AlignRight
        }
    }
}
