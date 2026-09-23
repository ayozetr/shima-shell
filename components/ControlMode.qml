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

    // Only one list can be unfolded at a time: they take the same
    // room, and two of them would push the island past the screen.
    property bool showOutputs: false
    property bool showScreens: false

    // The island asks each mode how tall it wants to be. An unfolded
    // list grows with the number of entries, so the last one is not
    // left hanging outside the island.
    readonly property int preferredHeight: {
        if (root.showOutputs)
            return 54 + 12 + Math.max(1, Audio.outputs.length) * 33 + 8;
        if (root.showScreens)
            return 54 + 12 + 26 + Math.max(1, Brightness.displays.length) * 40 + 8;
        return 120 + (Brightness.available ? 26 : 0)
                   + (Power.available ? 36 : 0);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Tile {
                Layout.fillWidth: true
                label: I18n.t.wifi
                settingsModule: "kcm_networkmanagement"
                glyph: "wifi"
                on: Networking.wifiEnabled
                available: Networking.wifiHardwareEnabled
                onTriggered: Networking.wifiEnabled = !Networking.wifiEnabled
            }
            Tile {
                Layout.fillWidth: true
                label: I18n.t.bluetooth
                settingsModule: "kcm_bluetooth"
                glyph: "bt"
                on: root.adapter ? root.adapter.enabled : false
                available: root.adapter !== null
                onTriggered: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            }
            // Muting lives on the speaker icon next to the slider, so
            // this slot is free for choosing where the sound goes.
            Tile {
                Layout.fillWidth: true
                label: I18n.t.output
                settingsModule: "kcm_pulseaudio"
                glyph: "output"
                on: root.showOutputs
                available: Audio.ready
                onTriggered: {
                    root.showOutputs = !root.showOutputs;
                    root.showScreens = false;
                }
            }
            // Night light is a switch like the first two, not a
            // brightness control: it shifts the colour, not the level.
            // Lit means it is tinting right now; outlined means it is
            // on but waiting for the schedule to reach sunset.
            Tile {
                Layout.fillWidth: true
                label: I18n.t.nightLight
                settingsModule: "kcm_nightlight"
                glyph: "night"
                on: NightLight.tinting
                waiting: NightLight.enabled && !NightLight.tinting
                available: NightLight.available
                onTriggered: NightLight.toggle()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: !root.showOutputs && !root.showScreens

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

            LevelSlider {
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

        // ── Brightness, on the screens that answer ───────────────
        //
        // Every monitor moves together, the way the keyboard keys do.
        // Nothing is shown when none of them can be driven: a laptop
        // without backlight control or a monitor that ignores DDC
        // would otherwise get a slider that does nothing.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: !root.showOutputs && !root.showScreens && Brightness.available

            // With a second monitor the sun becomes a button, the way
            // the speaker is one: it unfolds a bar per screen.
            ControlGlyph {
                Layout.preferredWidth: 14
                Layout.preferredHeight: 14
                kind: "brightness"
                fill: Brightness.displays.length > 1 && sunArea.containsMouse
                    ? Theme.textPrimary : Theme.textSecondary
                Behavior on fill { ColorAnimation { duration: Theme.hoverDuration } }

                MouseArea {
                    id: sunArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    enabled: Brightness.displays.length > 1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showScreens = true;
                        root.showOutputs = false;
                    }
                }
            }

            LevelSlider {
                Layout.fillWidth: true
                value: Brightness.ratio
                // Screens stay readable at the bottom of the bar: a
                // monitor at zero is black, and finding the slider
                // again on a black screen is not a thing to ask.
                onMoved: (v) => Brightness.setRatio(Math.max(0.05, v))
            }

            Text {
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignRight
                text: Math.round(Brightness.ratio * 100) + "%"
                color: Theme.textSecondary
                font.pixelSize: 11
            }
        }

        // ── Power: the profile, and keeping it awake ─────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: !root.showOutputs && !root.showScreens && Power.available

            Repeater {
                model: Power.profiles

                Rectangle {
                    required property var modelData
                    readonly property bool current: Power.profile === modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    radius: 8
                    color: current ? Theme.accent
                         : (pm.containsMouse ? "#20ffffff" : "#14ffffff")
                    Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: ({
                            "power-saver": I18n.t.powerSaver,
                            "balanced": I18n.t.powerBalanced,
                            "performance": I18n.t.powerPerformance
                        })[modelData] || modelData
                        color: current ? Theme.accentText : Theme.textSecondary
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: pm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Power.setProfile(modelData)
                    }
                }
            }

            // Not a profile but an inhibition, so it sits apart.
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 26
                radius: 8
                color: Power.keepAwake ? Theme.accent
                     : (awake.containsMouse ? "#20ffffff" : "#14ffffff")
                Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

                ControlGlyph {
                    anchors.centerIn: parent
                    width: 13; height: 13
                    kind: "awake"
                    fill: Power.keepAwake ? Theme.accentText : Theme.textSecondary
                }

                MouseArea {
                    id: awake
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Power.keepAwake = !Power.keepAwake
                }

                // Right-aligned, not centred: this button is the last
                // thing in the row, and a label centred on it runs off
                // the edge of the island.
                ToolTipLabel {
                    show: awake.containsMouse
                    text: I18n.t.keepAwake
                    anchors.right: parent.right
                    anchors.bottom: parent.top
                    anchors.bottomMargin: 4
                    z: 30
                }
            }
        }

        // ── Output list, in place of the volume row ──────────────
        OutputPicker {
            Layout.fillWidth: true
            visible: root.showOutputs
        }

        // ── One bar per screen, in place of the same row ──────────
        BrightnessPicker {
            Layout.fillWidth: true
            visible: root.showScreens
            onClosed: root.showScreens = false
        }

        Item { Layout.fillHeight: true }
    }

    // ── Square button that lights up while active ────────────────
    component Tile: Rectangle {
        id: tile
        property string label: ""
        property string glyph: ""
        // The page in System Settings this switch is a shortcut for,
        // opened with the right button.
        property string settingsModule: ""
        property bool on: false
        // Switched on but not doing anything yet: drawn as an outline,
        // between off and lit.
        property bool waiting: false
        // Not called `enabled`, which every Item already has: one of
        // that name here hides the one underneath, and Qt says so at
        // every start. Using the real one would not do either, since a
        // switch that is greyed out still takes the right click that
        // opens its settings page — which is the point of the note
        // further down. What this means is whether there is anything
        // there to switch.
        property bool available: true
        signal triggered()

        readonly property color tint: tile.on ? Theme.accentText
            : (tile.waiting ? Theme.accent : Theme.textSecondary)

        implicitHeight: 54
        radius: 12
        color: tile.on ? Theme.accent : (tile.waiting ? Theme.accentSoft : "#18ffffff")
        border.width: 1
        border.color: tile.on ? "transparent"
            : (tile.waiting ? Theme.accent : "#1affffff")
        opacity: tile.available ? 1 : 0.35

        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
        Behavior on border.color { ColorAnimation { duration: Theme.hoverDuration } }

        Column {
            anchors.centerIn: parent
            spacing: 4

            ControlGlyph {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 17; height: 17
                kind: tile.glyph
                fill: tile.tint
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // Kept inside its own cell. Measured, the longest
                // label there is today — "Lumière nocturne" — comes to
                // 84 px against a cell of about 92, so nothing is
                // spilling out yet; it is the next translation that
                // would, and with nothing to stop it, it would be
                // drawn over the switch beside it rather than cut.
                // Four pixels of margin rather than eight, so the one
                // that already fits keeps fitting.
                width: tile.width - 4
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.label
                color: tile.tint
                font.pixelSize: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: tile.available ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: (e) => {
                if (e.button === Qt.RightButton) {
                    // Worth offering even on a switch that is greyed
                    // out: no Bluetooth adapter is exactly when you
                    // want to go and look at the settings.
                    if (tile.settingsModule !== "")
                        Quickshell.execDetached(["systemsettings", tile.settingsModule]);
                } else if (tile.available) {
                    tile.triggered();
                }
            }
        }
    }
}

