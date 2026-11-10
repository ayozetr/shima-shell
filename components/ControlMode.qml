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
    property bool showWifi: false
    property bool showBluetooth: false

    readonly property bool listOpen: root.showOutputs || root.showScreens
                                   || root.showWifi || root.showBluetooth

    // Opening one list closes the others, so the room is never fought
    // over. Each tile that unfolds a list calls this with its own.
    function unfold(which) {
        root.showOutputs   = which === "outputs";
        root.showScreens   = which === "screens";
        root.showWifi      = which === "wifi";
        root.showBluetooth = which === "bluetooth";
    }

    // The island asks each mode how tall it wants to be. An unfolded
    // list grows with the number of entries, so the last one is not
    // left hanging outside the island.
    readonly property int preferredHeight: {
        if (root.showOutputs)
            return 54 + 12 + Math.max(1, Audio.outputs.length) * 33 + 8;
        if (root.showScreens)
            return 54 + 12 + 26 + Math.max(1, Brightness.displays.length) * 40 + 8;
        // These two measure their own list, password line and all,
        // rather than count rows: the height of a Wi-Fi entry is not
        // fixed once a line to type into can open under it.
        if (root.showWifi)
            return 54 + 12 + wifiPicker.implicitHeight + 8;
        if (root.showBluetooth)
            return 54 + 12 + btPicker.implicitHeight + 8;
        return 120 + (Brightness.available ? 26 : 0)
                   + (Power.available ? 36 : 0);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // A tap unfolds the list of networks — turning the radio on
            // first if it was off, since an empty list is no answer.
            // Switching it back off is a press-and-hold: a stray click
            // on the one switch that drops your connection would be a
            // poor way to go looking at networks.
            Tile {
                Layout.fillWidth: true
                label: I18n.t.wifi
                settingsModule: "kcm_networkmanagement"
                glyph: "wifi"
                on: Networking.wifiEnabled
                available: Networking.wifiHardwareEnabled
                hint: Networking.wifiEnabled ? I18n.t.holdToOff : ""
                onTriggered: {
                    if (!Networking.wifiEnabled) Networking.wifiEnabled = true;
                    root.unfold(root.showWifi ? "" : "wifi");
                }
                onHeld: {
                    Networking.wifiEnabled = false;
                    root.showWifi = false;
                }
            }
            Tile {
                Layout.fillWidth: true
                label: I18n.t.bluetooth
                settingsModule: "kcm_bluetooth"
                glyph: "bt"
                on: root.adapter ? root.adapter.enabled : false
                available: root.adapter !== null
                hint: (root.adapter && root.adapter.enabled) ? I18n.t.holdToOff : ""
                onTriggered: {
                    if (root.adapter && !root.adapter.enabled) root.adapter.enabled = true;
                    root.unfold(root.showBluetooth ? "" : "bluetooth");
                }
                onHeld: {
                    if (root.adapter) root.adapter.enabled = false;
                    root.showBluetooth = false;
                }
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
                onTriggered: root.unfold(root.showOutputs ? "" : "outputs")
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
            visible: !root.listOpen

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
            visible: !root.listOpen && Brightness.available

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
                    onClicked: root.unfold("screens")
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
            visible: !root.listOpen && Power.available

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

        // ── Networks, in place of the switches' rows ──────────────
        WifiPicker {
            id: wifiPicker
            Layout.fillWidth: true
            visible: root.showWifi
        }

        // ── Bluetooth devices, the same way ───────────────────────
        BluetoothPicker {
            id: btPicker
            Layout.fillWidth: true
            visible: root.showBluetooth
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
        // A word shown over the switch on hover, for a gesture that is
        // not obvious: the press-and-hold that turns Wi-Fi and
        // Bluetooth off, where a plain tap now opens their list.
        property string hint: ""
        signal triggered()
        signal held()

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
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
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
            // Holding is the way off, now that a tap opens the list.
            // Qt swallows the click that would otherwise follow a hold,
            // so the two gestures do not both fire.
            onPressAndHold: (e) => {
                if (e.button === Qt.LeftButton && tile.available) tile.held();
            }
        }

        // The hint for the hold, over the switch while the pointer
        // rests on it. Centred above, and lifted clear of the row.
        ToolTipLabel {
            show: tileArea.containsMouse && tile.hint !== ""
            text: tile.hint
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            z: 30
        }
    }
}

