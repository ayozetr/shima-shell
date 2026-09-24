import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../services"

// What shows while the island is at rest: bars, weather, clock and
// album art.
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

    // Weather and clock travel together in the middle, so the group
    // stays centred whatever the weather is showing.
    Row {
        anchors.centerIn: parent
        spacing: 8

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            width: 16; height: 16
            visible: (Config.data.weatherEnabled ?? true)
                     && (Config.data.weatherShowIcon ?? true)
                     && Weather.ready
            source: Weather.iconName
                ? Quickshell.iconPath(Weather.iconName, "weather-clear") : ""
            asynchronous: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: (Config.data.weatherEnabled ?? true)
                     && (Config.data.weatherShowTemp ?? true)
                     && Weather.ready
            text: Weather.temperatureText
            color: Theme.textSecondary
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: (Config.data.weatherEnabled ?? true) && Weather.ready
                     && ((Config.data.weatherShowIcon ?? true)
                         || (Config.data.weatherShowTemp ?? true))
            text: "·"
            color: Theme.textTertiary
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date,
                (Config.data.clock24 ?? true) ? "H:mm" : "h:mm AP")
            color: Theme.textPrimary
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }

    // The same rule as the expanded panel: what a stopped player left
    // in its metadata is not a cover.
    AlbumArt {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: 6
        source: (root.player && root.player.playbackState !== MprisPlaybackState.Stopped)
            ? root.player.trackArtUrl : ""
    }
}
