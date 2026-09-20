import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "services"
import "components"

PanelWindow {
    id: win

    // Flush against the top edge and centred: anchoring only to the
    // top lets layer-shell centre us on the free axis.
    anchors.top: true
    exclusionMode: ExclusionMode.Ignore
    // Top rather than Overlay: a fullscreen game should cover it, just
    // as it covers the dock. Overlay would sit above it.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "shima-island"
    color: "transparent"

    visible: (Config.data.islandEnabled ?? true)
             && Config.onScreen(Config.data.islandScreens,
                                win.screen ? win.screen.name : "")

    // ── Modes ──────────────────────────────────────────────────
    readonly property var modes: [
        { id: "media",    height: 146 },
        { id: "control",  height: 162 },
        { id: "status",   height: 142 },
        { id: "calendar", height: 186 }
    ]
    property int mode: 0
    readonly property int expandedHeight: modes[mode].height

    // The window is fixed and at its largest size; what animates is
    // the rectangle inside. Resizing a layer-shell surface every frame
    // stutters, so we don't.
    implicitWidth: Theme.islandExpandedWidth + 40
    implicitHeight: 186 + Theme.islandExpandedMargin + 24

    // Only the visible rectangle takes the mouse. Without this, the
    // transparent window would swallow the clicks around it.
    mask: win.revealed ? shellRegion : edgeRegion

    Region {
        id: shellRegion
        item: shell
        radius: Theme.islandRadius
    }

    Region {
        id: edgeRegion
        item: edgeStrip
    }

    Item {
        id: edgeStrip
        width: parent.width
        height: 3
        y: 0
        HoverHandler {
            onHoveredChanged: if (hovered) win.hovering = true
        }
    }

    // Background blur, if asked for. Off by default because the island
    // is opaque black and it would make no difference.
    BackgroundEffect.blurRegion: (Config.data.islandBlur ?? false) ? shellRegion : null

    Timer {
        id: hideTimer
        interval: Config.data.islandHideDelay ?? 700
        onTriggered: win.hovering = false
    }

    readonly property bool autoHide: Config.data.islandAutoHide ?? false
    readonly property bool floating: Config.data.islandFloating ?? false
    readonly property int  topMargin: floating ? (Config.data.islandMargin ?? 8) : 0

    // It won't hide while expanded, obviously.
    readonly property bool revealed: !autoHide || hovering || expanded

    property bool hovering: false
    property bool expanded: false

    readonly property MprisPlayer player: {
        const players = Mpris.players.values;
        if (!players.length) return null;
        for (const p of players) if (p.isPlaying) return p;
        return players[0];
    }
    readonly property bool hasMedia: player !== null

    onHasMediaChanged: Cava.setActive(hasMedia && player.isPlaying)
    Connections {
        target: win.player
        function onIsPlayingChanged() { Cava.setActive(win.player.isPlaying); }
    }

    // The /proc readings only run while the Status mode is on screen.
    onModeChanged: SysInfo.active = (mode === 2 && win.expanded)
    onExpandedChanged: SysInfo.active = (mode === 2 && win.expanded)

    Rectangle {
        id: shell

        anchors.horizontalCenter: parent.horizontalCenter
        y: {
            if (!win.revealed) return -height - 4;
            if (win.expanded) return Math.max(win.topMargin, Theme.islandExpandedMargin);
            return win.topMargin;
        }
        width:  win.expanded ? Theme.islandExpandedWidth  : Theme.islandCollapsedWidth
        height: win.expanded ? win.expandedHeight : Theme.islandCollapsedHeight
        color: Theme.islandBg
        border.width: 1
        border.color: win.expanded ? Theme.islandBorder : "transparent"

        // Collapsed it sits against the top, so only the bottom
        // corners get rounded.
        topLeftRadius:     (win.expanded || win.floating) ? Theme.islandRadius : 0
        topRightRadius:    (win.expanded || win.floating) ? Theme.islandRadius : 0
        bottomLeftRadius:  Theme.islandRadius
        bottomRightRadius: Theme.islandRadius
        readonly property int radius: Theme.islandRadius

        // Each dimension with its own curve: that is what makes the
        // expansion feel mechanical instead of a plain scale.
        Behavior on width  { NumberAnimation { duration: Theme.springDuration; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }
        Behavior on height { NumberAnimation { duration: Theme.springDuration; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
        Behavior on y      { NumberAnimation { duration: Theme.springDuration; easing.type: Easing.OutCubic } }
        Behavior on topLeftRadius  { NumberAnimation { duration: Theme.springDuration; easing.type: Easing.OutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: Theme.springDuration; easing.type: Easing.OutCubic } }
        Behavior on border.color   { ColorAnimation { duration: Theme.fadeDuration } }

        HoverHandler {
            onHoveredChanged: {
                win.expanded = hovered;
                if (hovered) { hideTimer.stop(); win.hovering = true; }
                else if (win.autoHide) hideTimer.restart();
            }
        }

        // The wheel moves between modes, clamped at both ends. It goes
        // in a WheelHandler rather than the MouseArea because a
        // MouseArea with acceptedButtons: NoButton never receives wheel
        // events, and because this way we don't steal clicks from the
        // controls inside.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (e) => {
                console.log("[shima] rueda:", e.angleDelta.y, "expandida:", win.expanded);
                if (!win.expanded) return;
                const dy = e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x;
                if (dy === 0) return;
                const dir = dy > 0 ? -1 : 1;
                win.mode = Math.max(0, Math.min(win.modes.length - 1, win.mode + dir));
            }
        }

        // ── Collapsed: bars · clock · album art ────────────────
        CollapsedContent {
            anchors.fill: parent
            player: win.player
            opacity: win.expanded ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
        }

        // Its own strip for the mode indicator, so no content ever
        // runs into it.
        ModeDots {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.top: parent.top
            anchors.topMargin: 11
            count: win.modes.length
            current: win.mode
            opacity: win.expanded ? 1 : 0
            visible: opacity > 0
            z: 5
            onPicked: (i) => win.mode = i
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
        }

        // ── Expanded: whichever mode is active ────────────────
        Item {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 28
            opacity: win.expanded ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

            // Each mode slides in from the direction of the scroll.
            Repeater {
                model: win.modes.length

                Loader {
                    anchors.fill: parent
                    active: Math.abs(index - win.mode) <= 1
                    opacity: index === win.mode ? 1 : 0
                    visible: opacity > 0
                    x: (index - win.mode) * 24

                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    sourceComponent: {
                        switch (index) {
                            case 0:  return mediaMode;
                            case 1:  return controlMode;
                            case 2:  return statusMode;
                            default: return calendarMode;
                        }
                    }
                }
            }
        }
    }

    Component { id: mediaMode;    MediaMode { player: win.player } }
    Component { id: controlMode;  ControlMode {} }
    Component { id: statusMode;   StatusMode {} }
    Component { id: calendarMode; CalendarMode {} }
}
