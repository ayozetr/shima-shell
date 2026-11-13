import QtQuick
import Quickshell
import Quickshell.Io
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

    // Bumped whenever a mode's loader produces or drops its item. The
    // height below is worked out with `itemAt`, which is a function
    // and not a property, so nothing tells that binding when the item
    // it asked about finally exists — and the loaders are lazy, so on
    // the mode the island opens in the item is not there yet when the
    // binding first runs. It then kept the written height for good and
    // the mode was cut off, which looked like the height was wrong
    // rather than the moment it was read. Changing mode hid it: that
    // does re-run the binding, with the item present by then, which is
    // why it only ever showed up straight after a restart.
    property int modeRevision: 0

    // A mode can ask for a different height (the control centre does,
    // when its output list is unfolded); otherwise its fixed one.
    readonly property int expandedHeight: {
        win.modeRevision;
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
        // Above the strip below, and that is the whole point of the
        // line. `edgeStrip` is three pixels tall, spans the width of
        // the screen, sits at y 0 and is declared after this, so among
        // siblings it was on top — and a covered item is not asked
        // about hover at all. In those three pixels, which is exactly
        // where the pointer is when it reaches the top of the screen,
        // this zone never heard anything: `overReach` stayed false and
        // the flicker it exists to prevent came back. Measured, with
        // the pointer parked at the edge: `overIsland` alone going
        // true and false every thirty-odd milliseconds.
        z: 1
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: (win.expanded || win.banner) ? Theme.islandExpandedWidth
                                            : Theme.islandCollapsedWidth
        height: {
            if (win.expanded)
                return Math.max(win.topMargin, Theme.islandExpandedMargin)
                       + win.expandedHeight;
            if (win.banner) return win.topMargin + win.peekHeight;
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
        //
        // Taller while a handle is sitting there, so the handle and the
        // few pixels around it all bring the island back.
        width: win.width
        height: (win.handle && !win.revealed) ? 16 : 3
        y: 0
        HoverHandler {
            onHoveredChanged: if (hovered) win.hovering = true
        }
    }

    // The handle: a small bar at the very top while the island is
    // hidden, so there is a thing to reach for instead of a blind edge.
    // Shown only when asked for and only while away.
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 4
        width: 46
        height: 5
        radius: 2.5
        // The cover's own colour while something plays — a sign of life
        // on the strip that matches what you are listening to — and a
        // quiet grey otherwise.
        readonly property bool playing: win.hasMedia && win.player && win.player.isPlaying
        color: playing ? win.coverColour : Theme.textSecondary
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
        opacity: (win.handle && !win.revealed) ? 0.9 : 0
        visible: opacity > 0
        z: 20
        Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
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
    // When set, auto-hide only steps aside for a window that is in the
    // way — one maximised or fullscreen on top — and stays out over the
    // bare desktop. Off, auto-hide tucks away all the time, as it did.
    readonly property bool hideForWindows: Config.data.islandAutoHideMaximized ?? false
    // Leave a small handle at the top edge while hidden, something to
    // see and to pull from, rather than nothing at all.
    readonly property bool handle: Config.data.islandHideHandle ?? false
    readonly property bool floating: Config.data.islandFloating ?? false
    readonly property int  topMargin: floating
        ? Config.number(Config.data.islandMargin, 8, 0, 400) : 0

    // A window covering the top of this screen, where the island sits —
    // the active one maximised or fullscreen over it. Worked out from
    // its geometry (via ActiveWindow), which is also what keeps it to
    // the screen the window is actually on, not both at once.
    readonly property bool windowCovering: ActiveWindow.coversScreen(win.screenName)

    // Whether, right now, it wants to be tucked away: auto-hide on, and
    // either hiding always or hiding because a window is in the way.
    readonly property bool wantHidden: win.autoHide
        && (!win.hideForWindows || win.windowCovering)

    // It won't hide while expanded, obviously.
    readonly property bool revealed: !wantHidden || hovering || expanded || banner

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

    // Reads the two flags directly, not through `banner`: going through
    // it put expanded → banner → shelving → shelf → expanded, a loop Qt
    // flagged. Named apart, the way the peek has always been, they form
    // the same short cycle the peek does and that Qt lets stand.
    readonly property bool expanded: !win.peeking && !win.shelving && !win.btShowing
                                     && !win.osding
                                     && (win.overIsland || win.overReach)
    readonly property bool pointerNear: win.overIsland || win.overReach

    onPointerNearChanged: {
        if (win.peeking) {
            if (win.pointerNear) peekTimer.stop();
            else peekTimer.restart();
        }
        if (win.pointerNear) { hideTimer.stop(); win.hovering = true; }
        else if (win.wantHidden) hideTimer.restart();
    }

    // ── A notification passing through ─────────────────────────
    //
    // It only takes the island when the island is idle: interrupting
    // someone who is in the middle of changing the volume would be
    // worse than making them wait. Missed ones are in the history.
    // The clipboard shelf shares this strip with the notification
    // peek. A copy is something you have just this moment done, so it
    // takes the slot over a notification passing through.
    readonly property var shelf: (win.expanded || !Config.onScreen(
        Config.data.islandScreens, win.screenName)) ? null : Clipboard.shelf
    readonly property bool shelving: win.shelf !== null

    // The battery an opened earbud case just announced, sharing the
    // same strip. Infrequent and deliberate, so it sits over the other
    // two when they coincide.
    readonly property var btBat: (win.expanded || !Config.onScreen(
        Config.data.islandScreens, win.screenName)) ? null : BtBattery.peek
    readonly property bool btShowing: win.btBat !== null

    // The volume display, flashing as you change it. The most immediate
    // of the lot — you just pressed a key — so it sits over the rest.
    readonly property var osd: (win.expanded || !Config.onScreen(
        Config.data.islandScreens, win.screenName)) ? null : Osd.peek
    readonly property bool osding: win.osd !== null

    // The shelf is kept out of this binding on purpose: peek reading
    // shelving, with shelving reading shelf and shelf reading expanded,
    // was part of the loop. The shelf takes the slot instead by sitting
    // over the notification, which is hidden while it does.
    readonly property var peek: (win.expanded || !Config.onScreen(
        Config.data.islandScreens, win.screenName)) ? null : Notifications.peek
    readonly property bool peeking: win.peek !== null

    // Any of the three filling the strip: what the geometry below
    // reacts to, where the notification, the shelf and the battery want
    // the same thing of it. Only geometry reads this — never
    // `expanded`, or the loop comes back.
    readonly property bool banner: win.peeking || win.shelving || win.btShowing || win.osding
    // The battery wants more room than a line of text: it carries three
    // readings, and a photo of each when one has been put there.
    readonly property int peekHeight: win.btShowing ? 108 : 84

    // Held open while the pointer is on it, the way the notification is.
    Binding {
        target: Clipboard
        property: "shelfHeld"
        value: win.shelving && win.pointerNear
    }
    Binding {
        target: BtBattery
        property: "peekHeld"
        value: win.btShowing && win.pointerNear
    }
    Binding {
        target: Osd
        property: "held"
        value: win.osding && win.pointerNear
    }
    // Held shut while the island is open, so changing the volume from
    // its own slider does not flash the display over that slider.
    Binding {
        target: Osd
        property: "inhibited"
        value: win.expanded
    }

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

    // Which player the island speaks for.
    //
    // Whatever is playing, and after that whatever is merely paused —
    // which is the one you mean to go back to. Taking the first on the
    // bus instead was enough while only one program registered itself,
    // but a browser stays registered long after the video ended, with
    // nothing in it and stopped. Pausing Spotify then handed the
    // island to the browser: an empty panel, and no way to press play
    // on the thing you had just paused.
    readonly property MprisPlayer player: {
        const players = Mpris.players.values;
        if (!players.length) return null;
        for (const p of players) if (p.isPlaying) return p;
        for (const p of players)
            if (p.playbackState === MprisPlaybackState.Paused) return p;
        // Nothing playing and nothing paused: whoever still has
        // something in it, and failing that the first one there is.
        for (const p of players)
            if (String(p.trackTitle || "").trim() !== "") return p;
        return players[0];
    }
    readonly property bool hasMedia: player !== null

    // The colours of the album art, for the handle to wear while
    // something plays — so the strip picks up the cover rather than a
    // colour from nowhere.
    //
    // The reader cannot fetch a remote address, and Spotify and the like
    // hand the cover over as one; so it is pulled down to a file first,
    // under a name that alternates, so the reader is handed a url it has
    // not seen and reads the new cover rather than the cached old one. A
    // local cover is read where it already is.
    property url artLocal: ""
    property int artGen: 0

    Process {
        id: artFetch
        property string dest: ""
        onExited: (code) => { if (code === 0) win.artLocal = "file://" + artFetch.dest; }
    }

    function updateArt() {
        const u = (win.player && win.player.trackArtUrl)
            ? String(win.player.trackArtUrl) : "";
        if (u === "") { win.artLocal = ""; return; }
        if (u.indexOf("file://") === 0) { win.artLocal = u; return; }
        if (u.indexOf("/") === 0) { win.artLocal = "file://" + u; return; }
        if (Paths.cacheDir === "") { win.artLocal = ""; return; }
        win.artGen = (win.artGen + 1) % 2;
        artFetch.dest = Paths.cacheDir + "/nowplaying-art-" + win.artGen;
        artFetch.command = ["sh", "-c", 'curl -sL --max-time 8 -o "$1" "$2"',
                            "shima", artFetch.dest, u];
        artFetch.running = true;
    }

    onPlayerChanged: win.updateArt()
    Component.onCompleted: win.updateArt()
    Connections {
        target: win.player
        function onTrackArtUrlChanged() { win.updateArt(); }
    }

    ColorQuantizer {
        id: artColours
        source: win.artLocal
        // Four buckets, not eight: the handful of tones the cover is
        // really made of, so the liveliest of them is a colour the cover
        // actually wears, not a stray pixel's accent.
        depth: 2
        rescaleSize: 64     // plenty for a palette, cheap to work out
    }

    // The liveliest one: saturated, and neither near-black nor washed
    // out, so it shows on the dark strip. The cover's own grey if it has
    // no real colour, the accent if there is no cover at all.
    readonly property color coverColour: {
        const cs = artColours.colors;
        if (!cs || cs.length === 0) return Theme.accent;
        let best = cs[0], bestScore = -1;
        for (const c of cs) {
            const v = c.hsvValue;
            const score = c.hsvSaturation
                * ((v > 0.3 && v < 0.95) ? v : v * 0.25);
            if (score > bestScore) { bestScore = score; best = c; }
        }
        return best;
    }

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
        width:  (win.expanded || win.banner) ? Theme.islandExpandedWidth
                                             : Theme.islandCollapsedWidth
        height: win.expanded ? win.expandedHeight
                             : (win.banner ? win.peekHeight : Theme.islandCollapsedHeight)
        color: Theme.islandBg
        // Width zero rather than a transparent colour: Qt still lays a
        // one-pixel stroke for a transparent border, and it shows up as
        // a faint line across the top of the collapsed island.
        border.width: (win.expanded || win.banner) ? 1 : 0
        border.color: Theme.islandBorder

        // Collapsed it sits against the top, so only the bottom
        // corners get rounded.
        topLeftRadius:     (win.expanded || win.banner || win.floating) ? Theme.islandRadius : 0
        topRightRadius:    (win.expanded || win.banner || win.floating) ? Theme.islandRadius : 0
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
                if (win.shelving) { Clipboard.dismissShelf(); return; }
                if (win.btShowing) { BtBattery.dismiss(); return; }
                if (win.osding) { Osd.dismiss(); return; }
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
            opacity: (win.expanded || win.banner) ? 0 : 1
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
            opacity: (!win.expanded && !win.banner && Notifications.unread > 0) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
        }

        // The microphone is live — an amber dot, the way a phone shows
        // it. A privacy light that blinked off the moment you reached
        // for the island would be no warning at all, so it lives here
        // rather than in CollapsedContent and outlasts the expansion:
        // tucked by the album art at rest, and up in the free top-left
        // corner once expanded, clear of the mode dots on the right and
        // of the content, which starts lower down. It steps aside only
        // for a passing peek, which owns the whole strip for its moment.
        Rectangle {
            width: 7; height: 7; radius: 3.5
            color: "#ff9f0a"
            z: 40
            x: win.expanded ? 14 : (shell.width - width - 46)
            y: win.expanded ? 11 : (Theme.islandCollapsedHeight - height) / 2
            opacity: (Privacy.enabled && Privacy.micActive && !win.banner) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }
            Behavior on x { NumberAnimation { duration: Theme.springDuration; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: Theme.springDuration; easing.type: Easing.OutCubic } }
        }

        NotificationPeek {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            entry: win.peek
            // Hidden under the shelf or the battery when they want the
            // strip: both are newer, deliberate things. The
            // notification's own timer still runs it out underneath.
            opacity: (win.peeking && !win.shelving && !win.btShowing && !win.osding) ? 1 : 0
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

        // The shelf, in the same strip: what was just copied, to drag
        // out or to tap for the history.
        ClipboardPeek {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            entry: win.shelf
            opacity: (win.shelving && !win.btShowing && !win.osding) ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

            onOpenHistory: {
                Clipboard.dismissShelf();
                LauncherState.showClipboard();
            }
            onDismissed: Clipboard.dismissShelf()
        }

        // The earbud battery, over the other two: an opened case is an
        // uncommon, on-purpose moment.
        BtBatteryPeek {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            entry: win.btBat
            opacity: (win.btShowing && !win.osding) ? 1 : 0
            visible: opacity > 0
            z: 1
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

            onDismissed: BtBattery.dismiss()
        }

        // The volume display, over all the rest.
        OsdPeek {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            entry: win.osd
            opacity: win.osding ? 1 : 0
            visible: opacity > 0
            z: 2
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

            onDismissed: Osd.dismiss()
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
            // The box grows over 420ms and this fades in over 160, so
            // for a quarter of a second the contents are already solid
            // while the island is still half its height — and what
            // does not fit is drawn outside it, hanging in the air.
            // The album art is the one you see, being the largest
            // thing in the first mode. Clipped, the island opens like
            // a drawer instead.
            //
            // Only while it moves, though. The tooltips of the control
            // mode are drawn past this box on purpose, and clipping
            // for good cut "No molestar" down to "No mol".
            clip: shell.height < win.expandedHeight - 1
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

                    onItemChanged: win.modeRevision++

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
