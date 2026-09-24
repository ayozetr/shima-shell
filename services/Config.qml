pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Settings on disk. The file is watched, so touching a control (or
// editing the JSON by hand) repaints the shell straight away: nothing
// to restart, no messages between processes.
Singleton {
    id: root

    readonly property alias data: cfg
    readonly property string path: Paths.configDir + "/config.json"

    // Fired once the file has actually been read. A singleton exists
    // before its file does, so anything that wants to start from what
    // was saved has to wait to be told rather than look at
    // construction and find the defaults.
    signal ready()
    property bool loaded: false

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        // No onAdapterUpdated: writeAdapter() here. With watchChanges
        // on it builds a loop (loading triggers a write, writing
        // triggers a reload) that left properties stuck at their
        // defaults. Each control calls save() when it should.
        // First run: dump the defaults so the JSON exists and can be
        // edited by hand.
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) writeAdapter();
            // Nothing to read is still an answer: the defaults are
            // what there is, and whoever was waiting can get on.
            if (!root.loaded) { root.loaded = true; root.ready(); }
        }

        // A file that is there but is not JSON any more — truncated by
        // a power cut mid-write, or edited into something broken —
        // does not fail to load: it loads, and the adapter quietly
        // keeps its defaults. The shell then came up as if new, and
        // the first control you touched wrote over the lot — place,
        // shortcut, screens and colours gone, without a word.
        //
        // So the text is parsed here as well, only to find out whether
        // it was readable at all.
        onLoaded: {
            if (!root.loaded) { root.loaded = true; root.ready(); }
            try {
                JSON.parse(file.text());
            } catch (e) {
                console.warn("[shima] " + root.path + " is not valid JSON; "
                           + "keeping a copy at " + root.path + ".bak "
                           + "and carrying on with the defaults");
                rescue.running = true;
            }
        }

        adapter: JsonAdapter {
            id: cfg

            // ── Dock ───────────────────────────────────────────
            property real   dockOpacity:      0.80   // 0–1
            property bool   dockBlur:         true
            property bool   dockFloating:     false  // flush against the edge by default
            property string dockPosition:     "bottom"   // bottom | top
            property int    dockIconSize:     56
            property string iconShape:        "squircle" // squircle | circle | square
            property int    iconRadiusPct:    33     // squircle only
            property int    dockCornerRadius: 28
            property int    dockMargin:       10     // only when floating
            property bool   dockMagnify:      true
            property bool   showRunning:      true   // open apps that are not pinned
            property bool   showLauncher:     true   // application launcher button
            property bool   showAppNames:     true   // the name floating over an icon
            property bool   showTray:         true   // the system tray icons

            // How much higher than the dock the launcher sits.
            property int    launcherLift:    0

            // ── Global shortcut ────────────────────────────────
            property bool   doNotDisturb:    false
            property bool   shortcutEnabled: true
            // A Qt key code with its modifiers, as the settings page
            // captures it. Qt::Key_Meta on its own is the Meta key,
            // which KWin answers through a different road entirely.
            property int    shortcutKey:     16777250
            property string shortcutLabel:   "Meta"
            // Folded behind a chevron, like Plasma's arrow, or always out.
            property bool   trayCollapsible:  true

            // ── Notifications ──────────────────────────────────
            // These were read with a `?? default` everywhere and
            // declared nowhere, so the whole settings page worked
            // until the shell restarted and then quietly forgot. The
            // defaults here are the ones those reads were using.
            property bool   notificationsEnabled:    true
            property int    notificationPeekSeconds: 5
            property bool   notificationCards:       true
            property int    notificationCardSeconds: 12
            property int    notificationHistory:     50
            property bool   dockAutoHide:     false
            property int    dockHideDelay:    700    // ms before hiding

            // ── Island ─────────────────────────────────────────
            // The defaults are the original look: black, opaque, no
            // blur and flush against the top edge.
            property bool   islandEnabled:    true
            property int    islandRadius:     22
            property int    islandCollapsedWidth:  410
            property int    islandCollapsedHeight: 38
            property int    islandExpandedWidth:   425
            property real   islandOpacity:    1.0
            property bool   islandBlur:       false
            property bool   islandFloating:   false
            property int    islandMargin:     8
            property bool   islandAutoHide:   false
            property int    islandHideDelay:  700

            // 24-hour clock by default, which is what a Spanish locale
            // expects; the previous hardcoded format was 12-hour.
            property bool   clock24:          true

            // ── Focus (pomodoro) ───────────────────────────────
            property int    focusMinutes:      25
            property int    breakMinutes:      5
            property int    longBreakMinutes:  15
            property int    focusRounds:       4      // before a long break
            property bool   focusChain:        true   // start the break on its own
            property bool   focusNotify:       true   // notify when a phase ends
            property bool   focusInhibit:      true   // silence notifications while focusing

            // ── Weather ────────────────────────────────────────
            // The location is inherited from the Plasma weather widget
            // on first run and resolved through Open-Meteo's geocoder.
            property bool   weatherEnabled:    true
            property bool   weatherShowIcon:   true
            property bool   weatherShowTemp:   true
            property bool   weatherFahrenheit: false
            property real   weatherLat:        0
            property real   weatherLon:        0
            property string weatherPlace:      ""
            // Forecast model. The default is the UK Met Office, which
            // is what feeds BBC Weather and therefore Plasma's widget:
            // picking anything else shows a different temperature than
            // the one you are used to seeing on the panel.
            property string weatherModel:      "ukmo_seamless"

            // bbc reads the very feed Plasma's weather widget uses, so
            // the temperature matches the panel instead of merely
            // coming close. openmeteo is the fallback and what anyone
            // without a BBC id gets.
            property string weatherProvider:   "bbc"
            property string weatherBbcId:      ""

            // auto, es, en
            property string language:          "auto"

            // ── Screens ────────────────────────────────────────
            // Connector names separated by commas ("DP-1,HDMI-A-1").
            // Empty means "on all of them", which is what someone with
            // a single monitor who never touched this expects.
            //
            // Stored as text rather than a list because JsonAdapter
            // does not preserve arrays: the file holds ["DP-1"] and
            // reading it back returns empty.
            property string islandScreens: ""
            property string dockScreens:   ""

            // ── Color ──────────────────────────────────────────
            property string accent:           "#a78bfa"
            property string dockTint:         "#000000"
            // Kept across restarts only if asked. A machine that will
            // not sleep because of something switched on days ago is a
            // hard thing to work out from the outside.
            property bool keepAwakeRemember:  false
            property bool keepAwakeOn:        false

            property bool clipboardHistory:   true
            property bool clipboardImages:    true
            property bool clipboardShortcutEnabled: true
            property int  clipboardKey:       268435542   // Meta+V
            property string clipboardLabel:   "Meta+V"
            property string islandTint:       "#000000"
            property string launcherTint:     "#000000"
        }
    }

    // Just the copy: the defaults are already in the adapter, and
    // whatever gets saved later will land on top of them anyway.
    Process {
        id: rescue
        command: ["sh", "-c", "cp -f -- \"$1\" \"$1.bak\"", "shima", root.path]
    }

    // A number out of the file, held inside what it can usefully be.
    //
    // `?? default` only catches a key that is not there. A file edited
    // by hand can say 0, or -5, or "banana", and every one of those
    // went straight into a geometry or a timer: an island nought
    // pixels wide is an island nobody can point at, and the mode dots
    // and the way back to the settings go with it. A pomodoro of nought
    // minutes ends the instant it starts and chains into the next,
    // which is a notification a second, for ever.
    //
    // The bounds are not opinions about what looks good — the settings
    // window decides that with its sliders. They are the edges past
    // which the shell stops working.
    function number(value, fallback, min, max) {
        if (value === undefined || value === null || value === "") return fallback;
        const n = Number(value);
        if (!isFinite(n)) return fallback;
        return Math.max(min, Math.min(max, n));
    }

    function save() { file.writeAdapter(); }

    function screenList(text) {
        if (!text) return [];
        return text.split(",").map(x => x.trim()).filter(x => x.length > 0);
    }

    // Empty means "all of them", not "none".
    //
    // And so does a list naming only screens that are not there. Pin
    // the island and the dock to DP-1, unplug it or let the connector
    // come back under another name, and every window Shima has —
    // island, dock, cards and launcher — disappears at once. Both ways
    // into the settings live inside those windows, so the only way back
    // would be editing the JSON by hand. Falling back to every screen
    // is wrong in a small way; vanishing is wrong in a way you cannot
    // undo.
    function onScreen(text, name) {
        const list = root.screenList(text);
        if (list.length === 0) return true;
        let present = false;
        for (const s of Quickshell.screens) {
            if (list.indexOf(s.name) !== -1) { present = true; break; }
        }
        return present ? list.indexOf(name) !== -1 : true;
    }

    // Check or uncheck a screen. If unchecking would leave the list
    // empty we store every other screen instead: otherwise "empty"
    // would read as "all of them" and it would reappear on the very
    // screen you just removed it from.
    function toggleScreen(key, name, on, allNames) {
        let cur = root.screenList(cfg[key]);
        if (cur.length === 0) cur = allNames.slice();
        const i = cur.indexOf(name);
        if (on && i === -1) cur.push(name);
        if (!on && i !== -1) cur.splice(i, 1);
        cfg[key] = cur.join(",");
        root.save();
    }
}
