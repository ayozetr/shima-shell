import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../services"

// The toggles one always ends up hunting for in the settings.
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var adapter: Bluetooth.defaultAdapter

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Tile {
                Layout.fillWidth: true
                label: "Wi-Fi"
                glyph: "wifi"
                on: Networking.wifiEnabled
                enabled: Networking.wifiHardwareEnabled
                onTriggered: Networking.wifiEnabled = !Networking.wifiEnabled
            }
            Tile {
                Layout.fillWidth: true
                label: "Bluetooth"
                glyph: "bt"
                on: root.adapter ? root.adapter.enabled : false
                enabled: root.adapter !== null
                onTriggered: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            }
            Tile {
                Layout.fillWidth: true
                label: "Silencio"
                glyph: "mute"
                on: root.sink && root.sink.audio ? root.sink.audio.muted : false
                enabled: root.sink !== null
                onTriggered: if (root.sink && root.sink.audio)
                    root.sink.audio.muted = !root.sink.audio.muted
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Glyph {
                width: 14; height: 14
                kind: (root.sink && root.sink.audio && root.sink.audio.muted)
                    ? "speakerOff" : "speakerOn"
                fill: Theme.textSecondary
            }

            VolumeSlider {
                Layout.fillWidth: true
                value: root.sink && root.sink.audio ? root.sink.audio.volume : 0
                onMoved: (v) => { if (root.sink && root.sink.audio) root.sink.audio.volume = v; }
            }

            Text {
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
                text: Math.round((root.sink && root.sink.audio ? root.sink.audio.volume : 0) * 100) + "%"
                color: Theme.textSecondary
                font.pixelSize: 11
            }
        }
    }

    // ── Square button that lights up while active ────────────────
    component Tile: Rectangle {
        id: tile
        property string label: ""
        property string glyph: ""
        property bool on: false
        property bool enabled: true
        signal triggered()

        implicitHeight: 54
        radius: 12
        color: tile.on ? Theme.accent : "#18ffffff"
        border.width: 1
        border.color: tile.on ? "transparent" : "#1affffff"
        opacity: tile.enabled ? 1 : 0.35

        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Column {
            anchors.centerIn: parent
            spacing: 4

            ControlGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 17; height: 17
                kind: tile.glyph
                fill: tile.on ? Theme.accentText : Theme.textSecondary
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.label
                color: tile.on ? Theme.accentText : Theme.textSecondary
                font.pixelSize: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: tile.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (tile.enabled) tile.triggered()
        }
    }
}
