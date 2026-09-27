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
            // Opaque. Translucency leans on the blur to keep what is
            // behind from being read through the dock, and the blur only
            // exists from Plasma 6.7 onwards, so out of the box the dock
            // stands on its own. Anyone who wants glass turns this down.
            property real   dockOpacity:      1.0    // 0–1
            // Off. Quickshell speaks `ext_background_effect` and
            // nothing else, and that protocol arrived in Plasma 6.7 —
            // 6.6 and everything before it drop the request in silence.
            // A default that does nothing on half the distributions out
            // there is not a default: whoever has the blur and wants it
            // turns it on.
            property bool   dockBlur:         false
            property bool   dockFloating:     false  // flush against the edge by default
            property string dockPosition:     "bottom"   // bottom | top
            property int    dockIconSize:     48
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
            // Forecast model. It used to default to the UK Met
            // Office, the reasoning being that it feeds BBC Weather
            // and therefore Plasma's widget — but with the provider
            // set to BBC, which is also the default, the model's
            // temperature is never read: the number comes from BBC and
            // all the model decides is the icon and whether it is day.
            // So that default bought nothing and cost accuracy where
            // the global model is weak. Open-Meteo's own pick per
            // location does better; the Met Office is still there for
            // anyone who wants the panel's own source.
            property string weatherModel:      "best_match"

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

            // What a right click on the dock's background opens.
            // "settings" is ours, "none" is nothing at all, and
            // anything else is the id of an application — the name of
            // its .desktop file without the extension. The settings
            // window offers the ones it finds installed from a list it
            // knows; this takes any of them, which is the way out when
            // yours is not on that list.
            property string dockRightClick:   "settings"

            // ── Color ──────────────────────────────────────────
            property string accent:           "#ffffff"
            property string dockTint:         "#181818"
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
            property string islandTint:       "#181818"
            property string launcherTint:     "#181818"
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

    // Empty means "all of them", not "none" — `none` says that, and is
    // obeyed with no net under it. Asking for no screen at all is a
    // decision, and the settings window is in the application menu:
    // type Shima, open it, switch it back on.
    //
    // A list naming only screens that are not there is a different
    // thing, and falls back to every screen. Pin the island and the
    // dock to DP-1, unplug it or let the connector come back under
    // another name after a cable, a dock or a KWin update, and nobody
    // asked for anything: the machine changed underneath. Everything
    // landing on the monitor that is left is ten seconds of annoyance;
    // a shell that starts and paints nothing looks broken, and the
    // person it happens to is the one who just undocked a laptop.
    // "none" is the one value that is not the name of a screen. It has
    // to exist: empty already means every screen, and empty is also
    // what is left when the last one is unchecked, so there was no way
    // to say "nowhere" — unchecking the island on one screen of two
    // emptied the list and turned it on for both.
    function nowhere(text) {
        return typeof text === "string" && text.trim().toLowerCase() === "none";
    }

    function onScreen(text, name) {
        if (root.nowhere(text)) return false;
        const list = root.screenList(text);
        if (list.length === 0) return true;
        let present = false;
        for (const s of Quickshell.screens) {
            if (list.indexOf(s.name) !== -1) { present = true; break; }
        }
        return present ? list.indexOf(name) !== -1 : true;
    }

    // Check or uncheck a screen.
    //
    // An empty list is read as every screen, so unchecking one starts
    // from the list of them all and takes that one out. Unchecking the
    // last one leaves nothing, and nothing has to be written down as
    // "none": left empty it would read as every screen again, which is
    // the shape of the bug this replaces — the island came back on the
    // screen it had just been taken off, and on the other one too.
    function toggleScreen(key, name, on, allNames) {
        let cur = root.nowhere(cfg[key]) ? [] : root.screenList(cfg[key]);
        if (!root.nowhere(cfg[key]) && cur.length === 0) cur = allNames.slice();
        const i = cur.indexOf(name);
        if (on && i === -1) cur.push(name);
        if (!on && i !== -1) cur.splice(i, 1);
        cfg[key] = cur.length === 0 ? "none" : cur.join(",");
        root.save();
    }
}
