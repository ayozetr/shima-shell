pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness, borrowed from powerdevil.
//
// Talking DDC/CI to a monitor means raw I2C, root and a per-vendor
// dance with quirks. Powerdevil already does all of that and publishes
// the result on the session bus, so this asks it instead. It is also a
// separate process from plasmashell, which means brightness keeps
// working once the panels are gone.
Singleton {
    id: root

    readonly property string service: "org.kde.ScreenBrightness"

    // Which screens exist: { path, label, max }. This list is replaced
    // only when the screens themselves change, never while dragging.
    // A model that changes identity makes the Repeater tear its
    // delegates down and build them again — under the cursor that is
    // dragging one of them, which is exactly as smooth as it sounds.
    property var displays: []

    // How bright each one is: path → 0–1. This is what moves.
    property var levels: ({})

    readonly property bool available: root.displays.length > 0

    // What the single bar shows: the average across screens.
    property real ratio: 1

    // Polling only runs while something is looking.
    property bool active: false

    function levelFor(path) {
        const v = root.levels[path];
        return v === undefined ? 1 : v;
    }

    // ── Reading ──────────────────────────────────────────────────
    //
    // The properties come back as JSON so they can be parsed instead
    // of scraped: busctl's own output is aligned for humans.
    Process {
        id: probe
        command: ["sh", "-c",
            "S=org.kde.ScreenBrightness; "
            + "for d in $(busctl --user --json=short get-property "
            + "  $S /org/kde/ScreenBrightness $S DisplaysDBusNames "
            + "  | grep -oE '\"display[0-9]+\"' | tr -d '\"'); do "
            + "  printf '%s\\t' \"$d\"; "
            + "  busctl --user --json=short call $S /org/kde/ScreenBrightness/$d "
            + "    org.freedesktop.DBus.Properties GetAll s $S.Display; "
            + "done"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }

    function refresh() {
        if (!probe.running) probe.running = true;
    }

    // Brightness changed from outside — KDE's own slider, a script —
    // while nothing here was polling. powerdevil says so on the bus;
    // hearing it and re-reading is what lets the island flash its
    // display for a change it did not make. Only while the volume
    // display is on, so the bus is not watched for nothing.
    Process {
        id: liveWatch
        running: Config.data.islandOsd ?? false
        command: ["busctl", "--user", "monitor", "--match",
            "type='signal',interface='org.kde.ScreenBrightness',"
            + "member='BrightnessChanged'"]
        stdout: SplitParser { onRead: (line) => liveBeat.restart() }
    }

    // One re-read per burst of signal lines, not per line.
    Timer { id: liveBeat; interval: 120; onTriggered: root.refresh() }

    function parse(text) {
        const found = [];
        const read = {};
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 0) continue;
            try {
                const props = JSON.parse(line.slice(tab + 1)).data[0];
                const max = props.MaxBrightness.data;
                if (max <= 0) continue;
                const path = "/org/kde/ScreenBrightness/" + line.slice(0, tab);
                found.push({ path: path, label: props.Label.data, max: max });
                read[path] = props.Brightness.data / max;
            } catch (e) {
                // A screen that goes away mid-read leaves a broken
                // line behind; the next pass picks up the rest.
            }
        }

        // Replace the list only when it is really a different set of
        // screens, so the delegates survive.
        if (root.signature(found) !== root.signature(root.displays))
            root.displays = found;

        root.maybeRescan();

        // A reading taken right after a drag still reports the old
        // value, because the monitor has not caught up yet. Trust what
        // was asked for until it has.
        if (Date.now() - root.lastWrite > 1200) {
            root.levels = read;
            root.syncRatio();
        }
    }

    // ── Nudging powerdevil when it came up short ─────────────────
    //
    // Powerdevil now and then registers only some of the DDC monitors
    // after login (a race: it reads the bus before a monitor has woken
    // on it, and then never looks again), and since the brightness is
    // borrowed from it, the per-screen control collapses to the one it
    // saw. There is no "detect again" on its bus to call — the only way
    // back is to restart it, by which time the bus is awake and it
    // finds them all. Off unless asked for: a screen with no brightness
    // control of its own would read here as a missing one and restart
    // powerdevil for nothing.
    readonly property bool rescan: Config.data.brightnessRescan ?? false
    property int rescanTries: 0

    Process { id: rescanProc }
    // Re-read a few seconds after a restart, once powerdevil is back and
    // has had time to find the screens; parse() then checks again, and
    // stops once the count is right or the tries run out.
    Timer { id: afterRescan; interval: 3500; onTriggered: root.refresh() }

    function maybeRescan() {
        if (!root.rescan || root.rescanTries >= 2) return;
        // Qt's own count of the outputs, which does not depend on
        // powerdevil: if it sees more screens than powerdevil did,
        // powerdevil missed some.
        if (Quickshell.screens.length <= root.displays.length) return;
        root.rescanTries++;
        rescanProc.command = ["systemctl", "--user", "restart",
                              "plasma-powerdevil.service"];
        rescanProc.running = true;
        afterRescan.restart();
    }

    function signature(list) {
        const parts = [];
        for (const d of list) parts.push(d.path + "|" + d.label + "|" + d.max);
        return parts.join(",");
    }

    function syncRatio() {
        if (root.displays.length === 0) return;
        let sum = 0;
        for (const d of root.displays) sum += root.levelFor(d.path);
        root.ratio = sum / root.displays.length;
    }

    // Monitor names arrive with the vendor spelled twice and a legal
    // suffix in between: "ASUSTek COMPUTER INC ASUS VG32VQR". Drop the
    // corporate words, then the repeats, and what is left is the name
    // on the bezel.
    readonly property var noiseWords: ["inc", "inc.", "corp", "corp.",
        "corporation", "co", "co.", "ltd", "ltd.", "llc", "gmbh",
        "computer", "computers", "technologies", "technology",
        "electronics", "international", "company"]

    function labelFor(display) {
        if (!display || !display.label) return "";
        const words = display.label.split(/\s+/).filter(
            w => w !== "" && root.noiseWords.indexOf(w.toLowerCase()) < 0);

        const kept = [];
        for (const w of words) {
            const low = w.toLowerCase();
            let dupe = false;
            for (let i = 0; i < kept.length; i++) {
                const other = kept[i].toLowerCase();
                // "ASUS" and "ASUSTek" are the same vendor; keep the
                // shorter one, which is the one people say.
                if (other.startsWith(low)) { kept[i] = w; dupe = true; break; }
                if (low.startsWith(other)) { dupe = true; break; }
            }
            if (!dupe) kept.push(w);
        }
        return kept.length > 0 ? kept.join(" ") : display.label;
    }

    // ── Writing ──────────────────────────────────────────────────
    //
    // A drag emits a value per frame. Powerdevil queues each one and
    // the monitor answers in its own time, so they are coalesced: the
    // first goes through at once and the rest at most every 70 ms.
    property real lastWrite: 0
    property var queued: ({})   // path → ratio still to be sent

    Process { id: writer }

    Timer {
        id: throttle
        interval: 70
        onTriggered: if (Object.keys(root.queued).length > 0) root.flush()
    }

    // Move every screen together, the way the keyboard keys do.
    function setRatio(r) {
        r = Math.max(0, Math.min(1, r));
        const next = {};
        for (const d of root.displays) next[d.path] = r;
        root.levels = next;
        root.ratio = r;
        for (const d of root.displays) root.queued[d.path] = r;
        root.kick();
    }

    // Move one screen on its own.
    function setRatioFor(path, r) {
        r = Math.max(0, Math.min(1, r));
        const next = {};
        for (const d of root.displays)
            next[d.path] = d.path === path ? r : root.levelFor(d.path);
        root.levels = next;
        root.syncRatio();
        root.queued[path] = r;
        root.kick();
    }

    function kick() {
        if (!throttle.running) root.flush();
    }

    function flush() {
        // Never over one still on its way. Talking to a monitor takes
        // far longer than the 70 ms between moves, and the value being
        // sent here was thrown away whether or not it arrived, with
        // nothing left to try again: let go of the slider at 80 % and
        // the screen stayed at 60.
        if (writer.running) { throttle.restart(); return; }

        const pending = root.queued;
        root.queued = ({});
        root.lastWrite = Date.now();
        throttle.restart();

        const calls = [];
        for (const d of root.displays) {
            if (!(d.path in pending)) continue;
            calls.push("busctl --user call " + root.service + " " + d.path
                + " " + root.service + ".Display SetBrightness iu "
                + Math.round(pending[d.path] * d.max) + " 0");
        }
        if (calls.length === 0) return;
        writer.command = ["sh", "-c", calls.join("; ")];
        writer.running = true;
    }

    // Knowing whether there is anything to show can't wait for the
    // control centre to be opened: the row decides its own existence.
    Component.onCompleted: root.refresh()
}
