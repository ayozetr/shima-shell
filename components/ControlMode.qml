import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import "../services"

// The toggles one always ends up hunting for in the settings.
Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    property bool showOutputs: false

    // The island asks each mode how tall it wants to be. With the
    // output list unfolded this grows with the number of devices, so
    // the last one is not left hanging outside the island.
    readonly property int preferredHeight: root.showOutputs
        ? 54 + 12 + Math.max(1, Audio.outputs.length) * 33 + 8
        : 120

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
            // Muting lives on the speaker icon next to the slider, so
            // this slot is free for choosing where the sound goes.
            Tile {
                Layout.fillWidth: true
                label: "Salida"
                glyph: "output"
                on: root.showOutputs
                enabled: Audio.ready
                onTriggered: root.showOutputs = !root.showOutputs
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: !root.showOutputs

            // Click to mute; the icon itself says which state you're in.
            Glyph {
                width: 14; height: 14
                kind: Audio.muted ? "speakerOff" : "speakerOn"
                fill: Audio.muted ? Theme.accent : Theme.textSecondary

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Audio.toggleMute()
                }
            }

            VolumeSlider {
                Layout.fillWidth: true
                // Muting leaves the bar where it was, only dimmed.
                // Dragging still mutes at zero and unmutes above it.
                value: Audio.volume
                dimmed: Audio.muted
                onMoved: (v) => {
                    Audio.setVolume(v);
                    if (v <= 0.001 && !Audio.muted) Audio.toggleMute();
                    else if (v > 0.001 && Audio.muted) Audio.toggleMute();
                }
            }

            Text {
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
                text: Math.round(Audio.volume * 100) + "%"
                color: Audio.muted ? Theme.textTertiary : Theme.textSecondary
                font.pixelSize: 11
                Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
            }
        }

        // ── Output list, in place of the volume row ──────────────
        OutputPicker {
            Layout.fillWidth: true
            visible: root.showOutputs
        }

        Item { Layout.fillHeight: true }
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
