import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
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

    property string screenName: ""
    visible: (Config.data.islandEnabled ?? true)
             && Config.onScreen(Config.data.islandScreens, win.screenName)

    // ── Modes ──────────────────────────────────────────────────
    readonly property var modes: [
        { id: "media",    height: 146 },
        { id: "control",  height: 162 },
        { id: "status",   height: 142 },
        { id: "calendar", height: 186 },
        { id: "notifications", height: 228 }
    ]
    property int mode: 0

    // A mode can ask for a different height (the control centre does,
    // when its output list is unfolded); otherwise its fixed one.
    readonly property int expandedHeight: {
        const loader = modeLoaders.itemAt(win.mode);
        const item = loader ? loader.item : null;
        if (item && item.preferredHeight)
            return item.preferredHeight + 42;
        return win.modes[win.mode].height;
    }

    // The window sits at the largest size anything needs; what
    // animates is the rectangle inside. Resizing a layer-shell surface
    // every frame stutters, so we don't — but 320 was not the largest
    // anything needs, it was the largest mode as written down, and a
    // mode that asks for more than its written height got it and was
    // then cut off by the window around it. Seven audio outputs or six
    // monitors is all it takes, and the rows past the edge are neither
    // visible nor clickable.
    //
    // So the floor stays where it was — the geometry of every ordinary
    // day is unchanged — and it gives way when a mode asks for more.
    // That happens when a list is unfolded, not once a frame.
    implicitWidth: Theme.islandExpandedWidth + 40
    implicitHeight: Math.max(320, win.expandedHeight + 92)
                    + Theme.islandExpandedMargin + 24

    // Only the visible rectangle takes the mouse. Without this, the
    // transparent window would swallow the clicks around it.
    mask: win.revealed ? shellRegion : edgeRegion

    Region {
        id: shellRegion
        item: reach
    }

    // Where the island reaches, at the size it is going to be — not
    // the size it is. Two things depend on it and both were wrong
    // while it moved:
    //
    //  * expanding drops it a few pixels from the edge, and with the
    //    pointer at the very top that took it out from under the
    //    cursor: it collapsed, returned to the edge, was under the
    //    cursor again, and flickered between the two;
    //  * the height grows over four hundred milliseconds, so reaching
    //    for a button near the bottom left the hover behind and shut
    //    the island before the button was there to press.
    //
    // Following the target instead of the animation settles both. The
    // mask uses it too: in Wayland the compositor only sends pointer
    // events where the mask says, so a zone that is not in it is a
    // zone the handler never hears about.
    Item {
        id: reach
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: (win.expanded || win.peeking) ? Theme.islandExpandedWidth
                                             : Theme.islandCollapsedWidth
        height: {
            if (win.expanded)
                return Math.max(win.topMargin, Theme.islandExpandedMargin)
                       + win.expandedHeight;
            if (win.peeking) return win.topMargin + win.peekHeight;
            return win.topMargin + Theme.islandCollapsedHeight;
        }

        HoverHandler {
            onHoveredChanged: win.overReach = hovered
        }
    }

    Region {
        id: edgeRegion
        item: edgeStrip
    }

    Item {
        id: edgeStrip
        // Measured against the window and not against contentItem,
        // which is not always the same size — the dock's strip carries
        // the same note for the same reason. A strip narrower than the
        // screen is an island that does not come back at the edges.
        width: win.width
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
        interval: Config.number(Config.data.islandHideDelay, 700, 100, 60000)
        onTriggered: win.hovering = false
    }

    readonly property bool autoHide: Config.data.islandAutoHide ?? false
    readonly property bool floating: Config.data.islandFloating ?? false
    readonly property int  topMargin: floating
        ? Config.number(Config.data.islandMargin, 8, 0, 400) : 0

    // It won't hide while expanded, obviously.
    readonly property bool revealed: !autoHide || hovering || expanded || peeking

    property bool hovering: false

    // Two detectors, because one cannot do it. The one inside the
    // island is an ancestor of its controls, so it still hears the
    // pointer while it is over the play button or the volume bar — a
    // MouseArea keeps the event to itself, and a detector that is
    // merely a sibling never learns the pointer is there. The one
    // outside covers the strip the island leaves when it drops away
    // from the edge on expanding, which is what made it flicker with
    // the pointer at the very top of the screen.
    property bool overIsland: false
    property bool overReach: false

    readonly property bool expanded: !win.peeking && (win.overIsland || win.overReach)
    readonly property bool pointerNear: win.overIsland || win.overReach

    onPointerNearChanged: {
        if (win.peeking) {
            if (win.pointerNear) peekTimer.stop();
            else peekTimer.restart();
        }
        if (win.pointerNear) { hideTimer.stop(); win.hovering = true; }
        else if (win.autoHide) hideTimer.restart();
    }

    // ── A notification passing through ─────────────────────────
    //
    // It only takes the island when the island is idle: interrupting
    // someone who is in the middle of changing the volume would be
    // worse than making them wait. Missed ones are in the history.
    readonly property var peek: (win.expanded || !Config.onScreen(
        Config.data.islandScreens, win.screenName)) ? null : Notifications.peek
    readonly property bool peeking: win.peek !== null
    readonly property int peekHeight: 84

    onPeekChanged: {
        if (win.peek) peekTimer.restart();
        else peekTimer.stop();
    }

    Timer {
        id: peekTimer
        interval: win.peek ? Notifications.peekSeconds(win.peek) * 1000 : 5000
        // Hovering holds it open: it is being read.
        running: false
        onTriggered: Notifications.dismissPeek()
    }

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

    // Polling follows whatever is on screen: the /proc readings while
    // Status is up, the brightness of each monitor while Control is.
    onModeChanged: win.syncPolling()
    onExpandedChanged: win.syncPolling()
    function syncPolling() {
        SysInfo.active = (win.mode === 2 && win.expanded);
        Brightness.active = (win.mode === 1 && win.expanded);
        NightLight.active = (win.mode === 1 && win.expanded);
        Power.active = (win.mode === 1 && win.expanded);
        // Having the list on screen is reading it. This can't live in
        // the mode itself: its neighbour is preloaded, so arriving at
        // the calendar would clear the unread mark without you ever
        // seeing the notifications.
        if (win.mode === 4 && win.expanded) Notifications.markAllRead();
    }

    Rectangle {
        id: shell

        anchors.horizontalCenter: parent.horizontalCenter
        y: {
            if (!win.revealed) return -height - 4;
            if (win.expanded) return Math.max(win.topMargin, Theme.islandExpandedMargin);
            return win.topMargin;
        }
        width:  (win.expanded || win.peeking) ? Theme.islandExpandedWidth
                                              : Theme.islandCollapsedWidth
        height: win.expanded ? win.expandedHeight
                             : (win.peeking ? win.peekHeight : Theme.islandCollapsedHeight)
        color: Theme.islandBg
        // Width zero rather than a transparent colour: Qt still lays a
        // one-pixel stroke for a transparent border, and it shows up as
        // a faint line across the top of the collapsed island.
        border.width: (win.expanded || win.peeking) ? 1 : 0
        border.color: Theme.islandBorder

        // Collapsed it sits against the top, so only the bottom
        // corners get rounded.
        topLeftRadius:     (win.expanded || win.peeking || win.floating) ? Theme.islandRadius : 0
        topRightRadius:    (win.expanded || win.peeking || win.floating) ? Theme.islandRadius : 0
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
        Behavior on border.width   { NumberAnimation { duration: Theme.fadeDuration } }

        HoverHandler {
            onHoveredChanged: win.overIsland = hovered
        }

        // The wheel moves between modes, clamped at both ends. It goes
        // in a WheelHandler rather than the MouseArea because a
        // MouseArea with acceptedButtons: NoButton never receives wheel
        // events, and because this way we don't steal clicks from the
        // controls inside.
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (e) => {
                // Reaching for the island while a notification is
                // sitting in it is unambiguous: the wheel is not
                // something anybody turns by accident. Holding the
                // notification open because the pointer is over it is
                // right when the pointer came to read it and wrong
                // when it came for the volume, and the wheel says
                // which.
                if (win.peeking) { Notifications.dismissPeek(); return; }
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
            opacity: (win.expanded || win.peeking) ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
        }

        // Something came in while you were away. It lives in the
        // bottom corner because the collapsed island already has the
        // bars on one side and the album art on the other.
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 7
            width: 5; height: 5; radius: 2.5
            color: Theme.accent
            opacity: (!win.expanded && !win.peeking && Notifications.unread > 0) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
        }

        NotificationPeek {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            entry: win.peek
            opacity: win.peeking ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

            onDismissed: Notifications.dismissPeek()
            onActivated: {
                // The first action is the default one by convention,
                // which is what clicking a notification runs.
                if (win.peek) {
                    Notifications.markRead(win.peek.key);
                    if (win.peek.actionCount > 0) Notifications.invoke(win.peek.id, 0);
                }
                Notifications.dismissPeek();
            }
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
            opacity: (win.expanded && !win.peeking) ? 1 : 0
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
                id: modeLoaders
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
                            case 3:  return calendarMode;
                            default: return notificationMode;
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
    Component { id: notificationMode; NotificationMode {} }
}
