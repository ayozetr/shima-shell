pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which windows are open, and everything that talks to them.
//
// A poll, and not by choice: KWin does not offer the Wayland protocol
// that lets a shell be told about windows as they come and go.
// Checked rather than assumed — a client asking for the toplevel
// manager here is handed nothing at all — so what can be done is to
// make each sweep cost as little as possible.
Singleton {
    id: root

    property var runningIds: ({})
    // How many sweeps in a row have failed to see each application.
    property var misses: ({})

    property bool hasKdotool: false
    // Don't scan until we know whether kdotool is around: the first
    // sweep would fall back to the process list and light up icons that
    // vanish as soon as the real window list arrives.
    property bool probeDone: false

    function isRunning(id) { return root.runningIds[id] === true; }

    // Open apps that are not pinned. They go into the dock behind the
    // pinned ones, like any task manager does.
    property var runningExtra: []

    // Index from process name to .desktop id. Built once, it turns
    // every scan into a direct lookup instead of comparing each process
    // against all of the system's entries.
    property var procIndex: ({})

    function buildIndex() {
        const idx = {};
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            const own = e.id.split(".").pop().toLowerCase();
            for (const c of root.candidatesFor(e)) {
                if (c.length < 3) continue;
                // Two keys per candidate: the whole thing, for window
                // classes, and cut to 15, which is where the kernel
                // truncates a process comm.
                for (const key of [c, c.slice(0, 15)]) {
                    if (idx[key] === undefined || c === own) idx[key] = e.id;
                }
            }
        }
        root.procIndex = idx;
    }

    // The desktop and ourselves are not dock apps.
    readonly property var neverShow: [
        "org.kde.plasmashell", "plasmashell", "quickshell", "shima",
        "org.kde.plasma.desktop"
    ]

    // A game's .desktop carries Exec=steam steam://rungameid/..., so it
    // would claim the "steam" process for itself and leave Steam
    // unidentified. Same story with every other launcher.
    readonly property var launchers: [
        "steam", "lutris", "heroic", "bottles", "wine", "wine64",
        "flatpak", "snap", "gamescope", "proton", "protontricks",
        "xdg-open", "env", "sh", "bash", "python", "python3", "java"
    ]

    function candidatesFor(entry) {
        const out = [];
        // The window class is usually StartupWMClass or the whole id,
        // so both go in as-is besides their last segment.
        if (entry.startupClass) out.push(entry.startupClass.toLowerCase());
        if (entry.id) out.push(entry.id.toLowerCase());
        if (entry.execString) {
            const bin = entry.execString.split(" ")[0].split("/").pop();
            // Only counts if the binary is its own and not a middleman.
            if (bin && root.launchers.indexOf(bin.toLowerCase()) === -1)
                out.push(bin.toLowerCase());
        }
        if (entry.startupClass) out.push(entry.startupClass.split(".").pop().toLowerCase());
        if (entry.id) out.push(entry.id.split(".").pop().toLowerCase());

        // Steam games have no window class of their own: they run as
        // steam_app_<id>, and the id is in the URL their .desktop
        // launches. Ignoring the "steam" binary above is what keeps
        // them from all claiming the Steam process, but it also threw
        // away the one thing that identifies them, so it is read back
        // from the URL — which points at one game and one only.
        const game = entry.execString
            ? entry.execString.match(/steam:\/\/(?:rungameid|run)\/(\d+)/)
            : null;
        if (game) out.push("steam_app_" + game[1]);

        // A game that runs under Proton names its window after the
        // Steam id, which the line above covers. One built for Linux
        // names it after its binary instead — Terraria's window class
        // is "Terraria.bin.x86_64" — and that is not in the .desktop
        // at all, since the Exec goes through Steam. Its display name
        // is the only thing left to match on.
        //
        // Only for those. Matching every application on what it calls
        // itself is a wide net for one fish: a name is not a window
        // class, and any program whose name happened to be the start
        // of somebody else's class would have lit up in the dock
        // without being open.
        if (game && entry.name && entry.name.indexOf(" ") === -1)
            out.push(entry.name.toLowerCase());

        return out;
    }

    // The window class as the index knows it, or undefined.
    function idForClass(name) {
        const direct = root.procIndex[name];
        if (direct !== undefined) return direct;

        // "terraria.bin.x86_64" is the binary, and its first segment
        // is the name. Reversed-domain ids are left alone: the first
        // segment of "org.kde.dolphin" says nothing.
        if (/^(org|com|net|io|dev|app|me|xyz|fr|eu)\./.test(name)) return undefined;
        const head = name.split(".")[0];
        if (head && head !== name && head.length >= 3) return root.procIndex[head];
        return undefined;
    }


    // ── Raising what was just started ──────────────────────────
    property string raiseId: ""
    property real raiseUntil: 0

    // Asked for by whoever just started something: watch for its
    // window and bring it to the front when it turns up. Ten seconds
    // is long enough for a heavy application to draw and short enough
    // that a window opened by hand afterwards is not stolen.
    function raiseWhenItAppears(id) {
        if (!root.hasKdotool || !id) return;
        root.raiseId = id;
        root.raiseUntil = Date.now() + 10000;
        raiseTimer.restart();
    }

    Timer {
        id: raiseTimer
        interval: 400
        repeat: true
        onTriggered: {
            if (root.raiseId === "" || Date.now() > root.raiseUntil) {
                root.raiseId = "";
                stop();
                return;
            }
            if (raiseProbe.running) return;
            const lookups = root.windowLookup(root.raiseId);
            if (!lookups) { root.raiseId = ""; stop(); return; }
            raiseProbe.command = ["sh", "-c",
                'wins=""; ' + lookups + '; '
                + '[ -z "$wins" ] && exit 0; '
                + 'kdotool windowactivate $(printf "%s\n" "$wins" | head -1) '
                + '  >/dev/null 2>&1 && echo raised'];
            raiseProbe.running = true;
        }
    }

    Process {
        id: raiseProbe
        stdout: StdioCollector {
            onStreamFinished: {
                // The first window to show up is the one that was
                // asked for; after that, stop watching, or a window
                // opened later would be yanked to the front too.
                if (text.trim() === "raised") {
                    root.raiseId = "";
                    raiseTimer.stop();
                }
            }
        }
    }

    function raiseOrStart(id) {
        const entry = Apps.entryFor(id);
        if (!entry) return;

        // Without kdotool there is no way to raise someone else's
        // window on Wayland, so all that's left is launching the app.
        if (!root.hasKdotool) { Apps.start(entry); return; }

        const lookups = root.windowLookup(id);
        if (!lookups) { Apps.start(entry); return; }

        // One window: raise it, or minimise it if it already has focus,
        // like any task manager. Several: step to the next one, so
        // clicking repeatedly walks through them.
        const script =
            'wins=""; ' + lookups + '; '
            + '[ -z "$wins" ] && exit 9; '
            + 'n=$(printf "%s\n" "$wins" | grep -c .); '
            + 'active=$(kdotool getactivewindow 2>/dev/null); '
            + 'if [ "$n" = "1" ]; then '
            + '  if [ "$wins" = "$active" ]; then exec kdotool windowminimize "$wins"; '
            + '  else exec kdotool windowactivate "$wins"; fi; '
            + 'fi; '
            + 'next=""; found=0; '
            + 'for w in $wins; do '
            + '  if [ "$found" = "1" ]; then next="$w"; break; fi; '
            + '  [ "$w" = "$active" ] && found=1; '
            + 'done; '
            + '[ -z "$next" ] && next=$(printf "%s\n" "$wins" | head -1); '
            + 'exec kdotool windowactivate "$next"';

        activate.pendingId = id;
        activate.exec(["sh", "-c", script]);
    }

    // Collects every window of an app into $wins, trying each name the
    // app is known by until one of them matches.
    function windowLookup(id) {
        // Named outright rather than worked out from the entry: the
        // candidates of anything called org.quickshell include plain
        // "quickshell", and that is the island, the dock and the
        // launcher. Raising one of those, or minimising it, is not
        // something anybody asked for.
        if (id === Apps.settingsId)
            return 'wins=$(kdotool search --class '
                 + JSON.stringify("^" + Apps.settingsClass + "$")
                 + ' 2>/dev/null)';

        // A game is known by its window and by nothing else, so its
        // window is what it is looked for by.
        if (id && id.indexOf("game:") === 0)
            return 'wins=$(kdotool search --class '
                 + JSON.stringify("^" + id.slice("game:".length) + "$")
                 + ' 2>/dev/null)';

        const entry = Apps.entryFor(id);
        if (!entry) return "";
        const names = root.candidatesFor(entry);
        if (!names.length) return "";
        // The trailing segment is optional because a native game's
        // window carries the binary's full name: "Terraria" has to
        // match "Terraria.bin.x86_64". kdotool ignores case, so the
        // candidates being lowercase costs nothing.
        return names
            .map(n => '[ -z "$wins" ] && wins=$(kdotool search --class '
                    + JSON.stringify("^" + n + "(\\..*)?$") + ' 2>/dev/null)')
            .join("; ");
    }


    // ── Listing the windows of an app ──────────────────────────
    //
    // Used by the middle click, which offers them by title so you can
    // pick one instead of stepping through them.
    property string forAppId: ""
    property var list: []

    function load(id) {
        root.forAppId = id;
        root.list = [];
        if (!root.hasKdotool) return;

        const lookups = root.windowLookup(id);
        if (!lookups) return;

        windowLister.exec(["sh", "-c",
            'wins=""; ' + lookups + '; '
            + 'for w in $wins; do '
            + '  printf "%s\t%s\n" "$w" "$(kdotool getwindowname "$w" 2>/dev/null)"; '
            + 'done']);
    }

    Process {
        id: windowLister
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 1) continue;
                    out.push({ id: line.slice(0, tab),
                               title: line.slice(tab + 1).trim() });
                }
                root.list = out;
            }
        }
    }

    function activate(winId) {
        if (!winId) return;
        windowProc.exec(["kdotool", "windowactivate", winId]);
    }


    // ── Window actions ─────────────────────────────────────────
    //
    // Minimise and close need a window, so they go through kdotool like
    // everything else. Without it they simply do nothing, and the menu
    // hides them.
    function windowCommand(id, command) {
        if (!root.hasKdotool) return;
        const entry = Apps.entryFor(id);
        if (!entry) return;

        const names = root.candidatesFor(entry);
        if (!names.length) return;

        const lookups = names
            .map(n => 'w=$(kdotool search --class ' + JSON.stringify("^" + n + "$")
                    + ' 2>/dev/null | head -1); [ -n "$w" ] && break')
            .join("; ");

        windowProc.exec(["sh", "-c",
            'for _ in 1; do ' + lookups + '; done; '
            + '[ -n "$w" ] && exec kdotool ' + command + ' "$w"']);
    }

    function close(id) { root.windowCommand(id, "windowclose"); }

    // Launch another instance regardless of what is already open.
    function launchNew(id) {
        const entry = Apps.entryFor(id);
        if (entry) Apps.start(entry);
    }

    Process { id: windowProc }

    // If there was no window to raise, launch the app instead.
    Process {
        id: activate
        property string pendingId: ""
        onExited: (code) => {
            if (code === 0) return;
            const entry = Apps.entryFor(activate.pendingId);
            if (entry) Apps.start(entry);
        }
    }


    // ── Process detection ──────────────────────────────────────
    //
    // A poll, and not by choice: KWin does not offer the Wayland
    // protocol that lets a shell be told about windows as they come
    // and go. Checked rather than assumed — a client asking for the
    // toplevel manager here is handed nothing at all — so what can be
    // done is to make each sweep cost as little as possible.
    //
    // Most of what a sweep cost was not the question but the shell
    // around it: a shell, a checksum and two files under the runtime
    // directory, all to avoid asking KWin twice for the same window
    // list. Timed, that plumbing came to more than the call it was
    // saving. Remembering the last answer is done here now, and the
    // usual sweep is one process.

    // Sweeps in a row that found exactly the same windows.
    property int settled: 0
    property string windowIds: ""
    property var windowClasses: []

    Timer {
        id: sweep
        // Quick while the session is moving, slower once it has been
        // still for a while: a desktop nobody is touching was starting
        // two and a half processes a second, for ever.
        interval: !root.hasKdotool ? 2000
                                   : (root.settled >= 15 ? 1200 : 400)
        running: root.probeDone
        repeat: true
        triggeredOnStart: true
        onTriggered: root.startSweep()
    }

    // Asking for a sweep from outside the timer: the window list is
    // wanted now, but not badly enough to start a second one over the
    // one already out.

    // Never over one already out: every other poll in the project
    // checks this, and this is the one that runs while a fullscreen
    // game makes KWin slow to answer.
    function startSweep() {
        if (!scan.running && !classer.running) scan.running = true;
    }

    // Asking for one from outside the timer. Somebody asked, so
    // whatever this was settling into, it has not.
    function sweepNow() {
        root.settled = 0;
        root.startSweep();
    }

    Process {
        id: scan
        // With kdotool we ask KWin for the windows that actually exist.
        // Without it all we can do is look at the process list, which
        // lights up false positives: Dolphin, for one, leaves a
        // "dolphin --daemon" running with no window at all.
        command: root.hasKdotool
            ? ["kdotool", "search", "--class", ".*"]
            : ["sh", "-c", "ps -eo comm= | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.hasKdotool) { root.sweepDone(text); return; }

                const ids = text.trim();
                // Nothing at all means the query failed, not that every
                // window in the session closed between one poll and the
                // next. kdotool goes through KWin's scripting API, and
                // it can come back empty while KWin is busy — opening
                // the launcher fires several queries at once. Acting on
                // it empties the dock of everything that is merely open
                // and fills it again a moment later, which is seen as
                // icons missing and then jumping into place.
                if (ids === "") return;

                if (ids === root.windowIds) {
                    root.settled++;
                    root.sweepDone(root.windowClasses.join("\n"));
                    return;
                }

                root.windowIds = ids;
                root.settled = 0;
                // Each window's class is a call of its own, so this
                // runs only when the list of windows has changed.
                classer.command = ["sh", "-c",
                    "printf '%s\\n' \"$1\" | while read -r w; do "
                    + "  [ -n \"$w\" ] && kdotool getwindowclassname \"$w\" "
                    + "    2>/dev/null; "
                    + "done | sort -u",
                    "shima", ids];
                classer.running = true;
            }
        }
    }

    Process {
        id: classer
        stdout: StdioCollector {
            onStreamFinished: {
                root.windowClasses = text.split("\n")
                    .map(s => s.trim()).filter(s => s);
                root.sweepDone(text);
            }
        }
    }

    // Two maps of the same applications, to tell an answer that says
    // something new from one that says what the last one said.
    function sameState(a, b) {
        const keys = Object.keys(a);
        if (keys.length !== Object.keys(b).length) return false;
        for (const k of keys) if (a[k] !== b[k]) return false;
        return true;
    }

    // Games seen running with no manifest read for them. Steam's
    // library is read once at startup, so a game installed since then
    // was not recognised until the shell was restarted. Asked once per
    // game, not once per sweep.
    property var steamAsked: ({})

    function sweepDone(text) {
        const names = text.split("\n").map(s => s.trim().toLowerCase()).filter(s => s);

        // Same reasoning as above: an empty answer is a question that
        // failed, not an empty desktop.
        if (names.length === 0) return;

        const procs = new Set(names);

        // What's alive, through the index instead of walking every
        // entry for each process.
        const alive = {};
        for (const p of procs) {
            if (p === Apps.settingsClass) {
                alive[Apps.settingsId] = true;
                continue;
            }
            const id = root.idForClass(p);
            if (id !== undefined) { alive[id] = true; continue; }

            // A game from Heroic or Lutris runs as its own executable
            // and has no desktop entry of its own, so the launcher's
            // catalogue is what names it.
            if (Games.byClass[p] !== undefined) {
                alive["game:" + p] = true;
                continue;
            }
            // An installed game with no .desktop is known by its window
            // class and nothing else.
            if (p.indexOf("steam_app_") !== 0) continue;
            const app = p.slice("steam_app_".length);
            if (Apps.steamGames[app] !== undefined) { alive[p] = true; continue; }
            // Installed after the shell started, so it is not in a list
            // that was read once and never again.
            if (!root.steamAsked[app]) {
                root.steamAsked[app] = true;
                Apps.rescanSteam();
            }
        }

        // Pinned apps need their own check: their binary may not be in
        // the index if another entry claimed it first.
        const out = {};
        for (const id of Pinned.list) {
            const entry = Apps.entryFor(id);
            out[id] = alive[id] === true
                || (entry ? root.matchesProcess(entry, procs) : false);
        }

        const extra = [];
        if (Config.data.showRunning ?? true) {
            // Don't repeat what the pinned ones already cover: two
            // .desktop files of the same app share a binary.
            const covered = {};
            for (const id of Pinned.list) {
                const e = Apps.entryFor(id);
                if (e) for (const c of root.candidatesFor(e)) covered[c] = true;
            }

            for (const id in alive) {
                if (Pinned.list.indexOf(id) !== -1) continue;
                if (root.neverShow.indexOf(id) !== -1) continue;
                const e = Apps.entryFor(id);
                if (!e || (!e.icon && !e.iconUrl)) continue;
                const cands = root.candidatesFor(e);
                if (cands.some(c => covered[c])) continue;
                for (const c of cands) covered[c] = true;
                extra.push(id);
                out[id] = true;
            }
            extra.sort();

            // Anything still counted as running keeps its place, even
            // if this sweep did not see it.
            for (const id of root.runningExtra) {
                if (extra.indexOf(id) === -1 && out[id] === true)
                    extra.push(id);
            }
            extra.sort();
        }

        // An application is added the moment it is seen and only
        // dropped after two sweeps in a row have missed it. Asking KWin
        // for the window list goes through its scripting API, which
        // turns slow and uneven while a fullscreen game is up: a single
        // sweep that misses takes the icon out and the next one puts it
        // back, and everything beside it slides over twice.
        //
        // Counted in a map of its own each sweep rather than in the one
        // kept from the last: that one gained a key for every
        // application ever seen and lost none, so it only ever grew.
        const missed = {};
        for (const id of Object.keys(out)) {
            if (out[id]) continue;
            if (root.runningIds[id] !== true) continue;
            const n = (root.misses[id] || 0) + 1;
            missed[id] = n;
            if (n < 2) out[id] = true;
        }
        root.misses = missed;

        // The list beside this one was already guarded against being
        // reassigned to the same thing; this one was not, so every icon
        // in the dock worked out again whether it was running, two and
        // a half times a second, with the answer unchanged.
        if (!root.sameState(out, root.runningIds)) root.runningIds = out;
        // Reassigning an identical list would fire animations every
        // couple of seconds with nothing having changed.
        if (extra.join("\u0000") !== root.runningExtra.join("\u0000"))
            root.runningExtra = extra;
    }

    // Linux cuts comm at 15 characters, so we compare by prefix rather
    // than equality.
    function matchesProcess(entry, procs) {
        const candidates = [];
        if (entry.execString) {
            const bin = entry.execString.split(" ")[0].split("/").pop();
            if (bin) candidates.push(bin.toLowerCase());
        }
        if (entry.id) candidates.push(entry.id.split(".").pop().toLowerCase());
        if (entry.startupClass) candidates.push(entry.startupClass.split(".").pop().toLowerCase());
        if (entry.name) candidates.push(entry.name.toLowerCase().replace(/ /g, ""));

        for (const p of procs) {
            const lp = p.toLowerCase();
            for (const c of candidates) {
                if (!c) continue;
                if (lp === c) return true;
                if (c.length >= 6 && (lp.startsWith(c.slice(0, 15)) || c.startsWith(lp))) return true;
            }
        }
        return false;
    }


    Process {
        running: true
        command: ["sh", "-c", "command -v kdotool >/dev/null && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasKdotool = text.trim() === "yes";
                root.probeDone = true;
            }
        }
    }
}
