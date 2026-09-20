import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../services"

// What shows while the island is at rest: bars, clock and album art.
Item {
    id: root
    property MprisPlayer player: null

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Visualizer {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        maxHeight: 16
        opacity: root.player && root.player.isPlaying ? 1 : 0.35
        Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
    }

    Text {
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "h:mm AP")
        color: Theme.textPrimary
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    AlbumArt {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: 6
        source: root.player ? root.player.trackArtUrl : ""
    }
}
