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
    readonly property string path: Quickshell.env("HOME") + "/.config/shima/config.json"

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

            // ── Global shortcut ────────────────────────────────
            property bool   shortcutEnabled: true
            // A Qt key code with its modifiers, as the settings page
            // captures it. Qt::Key_Meta on its own is the Meta key,
            // which KWin answers through a different road entirely.
            property int    shortcutKey:     16777250
            property string shortcutLabel:   "Meta"
            // Folded behind a chevron, like Plasma's arrow, or always out.
            property bool   trayCollapsible:  true
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
            property string islandTint:       "#000000"
        }
    }

    function save() { file.writeAdapter(); }

    function screenList(text) {
        if (!text) return [];
        return text.split(",").map(x => x.trim()).filter(x => x.length > 0);
    }

    // Empty means "all of them", not "none".
    function onScreen(text, name) {
        const list = root.screenList(text);
        return list.length === 0 || list.indexOf(name) !== -1;
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
