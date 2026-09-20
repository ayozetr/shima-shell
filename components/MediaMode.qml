import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../services"

// The island expanded: album art, track, transport and volume.
Item {
    id: root
    property MprisPlayer player: null
    readonly property var sink: Pipewire.defaultAudioSink

    AlbumArt {
        id: art
        anchors.left: parent.left
        anchors.top: parent.top
        width: 96
        height: 96
        radius: 12
        source: root.player ? root.player.trackArtUrl : ""
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
            text: root.player ? (root.player.trackTitle || "Sin reproducción") : "Sin reproducción"
            color: Theme.textPrimary
            font.pixelSize: 15
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.player ? root.player.trackArtist : ""
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
                enabled: root.player && root.player.canGoPrevious
                onClicked: root.player.previous()
            }
            MediaButton {
                kind: root.player && root.player.isPlaying ? "pause" : "play"
                size: 26
                enabled: root.player && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }
            MediaButton {
                kind: "next"
                size: 22
                enabled: root.player && root.player.canGoNext
                onClicked: root.player.next()
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ── Volume ─────────────────────────────────────────────────
    RowLayout {
        anchors.left: art.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 10

        Glyph {
            kind: "speakerOff"
            width: 14; height: 14
            fill: Theme.textSecondary
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
        }

        VolumeSlider {
            Layout.fillWidth: true
            value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
            onMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
        }

        Glyph {
            kind: "speakerOn"
            width: 14; height: 14
            fill: Theme.textSecondary
        }
    }
}
