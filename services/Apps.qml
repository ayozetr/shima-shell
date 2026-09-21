pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which apps are pinned to the dock and which ones are alive.
//
// On Windows this would be EnumWindows. On Wayland, KWin publishes
// neither zwlr_foreign_toplevel_manager_v1 nor
// org_kde_plasma_window_management, so no external app can enumerate
// windows. With kdotool we ask KWin directly; without it we fall back
// to the process list.
Singleton {
    id: root

    // .desktop IDs, in order. On first run they are inherited from the
    // Plasma task manager; after that pinned.json wins. This list is
    // only the last resort.
    property var pinned: [
        "zen",
        "org.kde.dolphin",
        "org.telegram.desktop",
        "discord",
        "spotify",
        "obsidian",
        "org.kde.konsole"
    ]
    property var runningIds: ({})
    readonly property string pinnedPath: Quickshell.statePath("pinned.json")

    property bool hasKdotool: false
    // Don't scan until we know whether kdotool is around: the first
    // sweep would fall back to the process list and light up icons that
    // vanish as soon as the real window list arrives.
    property bool probeDone: false

    // DesktopEntries scans lazily: the first access kicks it off and
    // the list arrives later, through applicationsChanged. This gives
    // bindings something to depend on.
    property int revision: 0

    Component.onCompleted: DesktopEntries.applications.values.length

    // On a hot reload, applicationsChanged already fired before we
    // existed, so that signal never reaches us and the bindings would
    // stay stuck on half-built entries. These retries wake them up
    // until everything resolves.
    Timer {
        id: settle
        interval: 400
        repeat: true
        running: true
        property int tries: 0
        onTriggered: {
            root.revision++;
            if (!Object.keys(root.procIndex).length) root.buildIndex();
            tries++;
            if (tries > 12 || root.allResolved()) running = false;
        }
    }

    function allResolved() {
        if (!DesktopEntries.applications.values.length) return false;
        for (const id of root.pinned) {
            const e = DesktopEntries.byId(id);
            if (!e || !e.icon) return false;
        }
        return true;
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.revision++;
            root.buildIndex();
            if (root.probeDone) scan.running = true;
        }
    }

    function isRunning(id) { return root.runningIds[id] === true; }

    // ── Categories ─────────────────────────────────────────────
    //
    // A .desktop declares several categories at once ("Qt;KDE;System;"),
    // so we keep the first of the main ones that shows up, in this
    // order.
    readonly property var categories: [
        { id: "all",     label: "Todas",      match: [] },
        { id: "net",     label: "Internet",   match: ["Network", "WebBrowser", "Email"] },
        { id: "media",   label: "Multimedia", match: ["AudioVideo", "Audio", "Video", "Player"] },
        { id: "games",   label: "Juegos",     match: ["Game"] },
        { id: "gfx",     label: "Gráficos",   match: ["Graphics", "Photography"] },
        { id: "office",  label: "Oficina",    match: ["Office", "TextEditor", "Spreadsheet"] },
        { id: "dev",     label: "Desarrollo", match: ["Development", "IDE"] },
        { id: "system",  label: "Sistema",    match: ["System", "Settings", "Security"] },
        { id: "utils",   label: "Utilidades", match: ["Utility", "Accessories", "Archiving"] },
        { id: "other",   label: "Otras",      match: [] }
    ]

    function categoryOf(entry) {
        const cats = entry.categories || [];
        for (const c of root.categories) {
            if (c.id === "all" || c.id === "other") continue;
            for (const m of c.match)
                if (cats.indexOf(m) !== -1) return c.id;
        }
        return "other";
    }

    // Visible apps, sorted by name and filtered by category and by
    // whatever was typed.
    function listApps(category, query) {
        const q = (query || "").trim().toLowerCase();
        const out = [];

        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            if (category && category !== "all" && root.categoryOf(e) !== category) continue;

            if (q) {
                // Search the comment and keywords too: "browser" finds
                // Brave even though the name doesn't contain it.
                const hay = [e.name, e.genericName, e.comment]
                    .concat(e.keywords || [])
                    .filter(x => x)
                    .join(" ")
                    .toLowerCase();
                if (hay.indexOf(q) === -1) continue;
            }
            out.push(e);
        }

        out.sort((a, b) => a.name.localeCompare(b.name, "es"));
        return out;
    }

    // How many apps each category holds, so empty ones stay hidden.
    function categoryCounts() {
        const counts = {};
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            const c = root.categoryOf(e);
            counts[c] = (counts[c] || 0) + 1;
            counts.all = (counts.all || 0) + 1;
        }
        return counts;
    }

    // Open apps that are not pinned. They go into the dock behind the
    // pinned ones, like any task manager does.
    property var runningExtra: []
    readonly property var dockItems: root.pinned.concat(root.runningExtra)

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
        return out;
    }

    function entryFor(id) {
        return DesktopEntries.byId(id) ?? null;
    }

    function launch(id) {
        const entry = root.entryFor(id);
        if (!entry) return;

        // Without kdotool there is no way to raise someone else's
        // window on Wayland, so all that's left is launching the app.
        if (!root.hasKdotool) { entry.execute(); return; }

        const lookups = root.windowLookup(id);
        if (!lookups) { entry.execute(); return; }

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
        const entry = root.entryFor(id);
        if (!entry) return "";
        const names = root.candidatesFor(entry);
        if (!names.length) return "";
        return names
            .map(n => '[ -z "$wins" ] && wins=$(kdotool search --class '
                    + JSON.stringify("^" + n + "$") + ' 2>/dev/null)')
            .join("; ");
    }

    // ── Listing the windows of an app ──────────────────────────
    //
    // Used by the middle click, which offers them by title so you can
    // pick one instead of stepping through them.
    property string windowsAppId: ""
    property var windows: []

    function loadWindows(id) {
        root.windowsAppId = id;
        root.windows = [];
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
                root.windows = out;
            }
        }
    }

    function activateWindow(winId) {
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
        const entry = root.entryFor(id);
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

    function closeWindow(id) { root.windowCommand(id, "windowclose"); }

    // Launch another instance regardless of what is already open.
    function launchNew(id) {
        const entry = root.entryFor(id);
        if (entry) entry.execute();
    }

    Process { id: windowProc }

    // If there was no window to raise, launch the app instead.
    Process {
        id: activate
        property string pendingId: ""
        onExited: (code) => {
            if (code === 0) return;
            const entry = root.entryFor(activate.pendingId);
            if (entry) entry.execute();
        }
    }

    // ── Import the pinned apps from the Plasma task manager ─────
    //
    // The task manager keeps them on a single line of appletsrc, in
    // three shapes: applications:id.desktop, a file:// path, or a
    // preferred://, which has to be resolved by MIME type.
    Process {
        id: importer
        command: ["sh", "-c", `
            f="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
            [ -f "$f" ] || exit 0
            grep -m1 '^launchers=' "$f" | cut -d= -f2- | tr ',' '\n' | while read -r e; do
              case "$e" in
                preferred://browser)     xdg-mime query default x-scheme-handler/https ;;
                preferred://filemanager) xdg-mime query default inode/directory ;;
                preferred://mail)        xdg-mime query default x-scheme-handler/mailto ;;
                preferred://terminal)    echo org.kde.konsole.desktop ;;
                applications:*)          echo "\${e#applications:}" ;;
                file://*)                basename "\${e#file://}" ;;
              esac
            done | sed 's/\.desktop$//' | awk 'NF && !seen[$0]++'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = text.split("\n").map(s => s.trim()).filter(s => s);
                if (!ids.length) {
                    console.log("[shima] la barra de tareas no tiene anclados que importar");
                    return;
                }
                root.pinned = ids;
                root.savePinned();
                root.revision++;
                scan.running = true;
            }
        }
    }

    function importFromPlasma() { importer.running = true; }

    // ── Process detection ──────────────────────────────────────
    Timer {
        // With kdotool the usual poll is a single 4 ms call, so we can
        // go fast and have the dock react straight away.
        interval: root.hasKdotool ? 400 : 2000
        running: root.probeDone
        repeat: true
        triggeredOnStart: true
        onTriggered: scan.running = true
    }

    Process {
        id: scan
        // With kdotool we ask KWin for the windows that actually exist.
        // Without it all we can do is look at the process list, which
        // lights up false positives: Dolphin, for one, leaves a
        // "dolphin --daemon" running with no window at all.
        command: root.hasKdotool
            ? ["sh", "-c", `
                cache=/tmp/shima-windows
                ids=$(kdotool search --class '.*' 2>/dev/null)
                sig=$(printf '%s' "$ids" | cksum)
                # Asking for each window's class costs one call per
                # window. While the list is unchanged we reuse the
                # previous answer, so the usual case is a single call.
                if [ -f "$cache.sig" ] && [ "$sig" = "$(cat "$cache.sig")" ] \
                   && [ -f "$cache.classes" ]; then
                    cat "$cache.classes"
                else
                    printf '%s' "$sig" > "$cache.sig"
                    printf '%s\n' "$ids" | while read -r w; do
                        [ -n "$w" ] && kdotool getwindowclassname "$w" 2>/dev/null
                    done | sort -u > "$cache.classes"
                    cat "$cache.classes"
                fi
              `]
            : ["sh", "-c", "ps -eo comm= | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const procs = new Set(text.split("\n").map(s => s.trim().toLowerCase()).filter(s => s));

                // What's alive, through the index instead of walking
                // every entry for each process.
                const alive = {};
                for (const p of procs) {
                    const id = root.procIndex[p];
                    if (id !== undefined) alive[id] = true;
                }

                // Pinned apps need their own check: their binary may
                // not be in the index if another entry claimed it
                // first.
                const out = {};
                for (const id of root.pinned) {
                    const entry = root.entryFor(id);
                    out[id] = alive[id] === true
                        || (entry ? root.matchesProcess(entry, procs) : false);
                }

                const extra = [];
                if (Config.data.showRunning ?? true) {
                    // Don't repeat what the pinned ones already cover:
                    // two .desktop files of the same app share a binary.
                    const covered = {};
                    for (const id of root.pinned) {
                        const e = root.entryFor(id);
                        if (e) for (const c of root.candidatesFor(e)) covered[c] = true;
                    }

                    for (const id in alive) {
                        if (root.pinned.indexOf(id) !== -1) continue;
                        if (root.neverShow.indexOf(id) !== -1) continue;
                        const e = root.entryFor(id);
                        if (!e || !e.icon) continue;
                        const cands = root.candidatesFor(e);
                        if (cands.some(c => covered[c])) continue;
                        for (const c of cands) covered[c] = true;
                        extra.push(id);
                        out[id] = true;
                    }
                    extra.sort();
                }

                root.runningIds = out;
                // Reassigning an identical list would fire animations
                // every couple of seconds with nothing having changed.
                if (extra.join("\u0000") !== root.runningExtra.join("\u0000"))
                    root.runningExtra = extra;
            }
        }
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

    // ── Persisting the pinned apps ─────────────────────────────
    FileView {
        id: pinnedFile
        path: root.pinnedPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(pinnedFile.text());
                if (Array.isArray(parsed) && parsed.length) {
                    root.pinned = parsed;
                    root.revision++;
                }
            } catch (e) { /* corrupto: nos quedamos con lo que haya */ }
        }
        // First run: inherit whatever is already pinned in the Plasma
        // task manager, which is what one expects to see.
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) root.importFromPlasma();
        }
    }

    // Reorder and remove, from dragging in the dock or from settings.
    function move(from, to) {
        if (from === to || from < 0 || to < 0) return;
        const list = root.pinned.slice();
        if (from >= list.length || to >= list.length) return;
        list.splice(to, 0, list.splice(from, 1)[0]);
        root.pinned = list;
        root.savePinned();
    }

    function unpin(id) {
        root.pinned = root.pinned.filter(x => x !== id);
        root.savePinned();
    }

    function pin(id) {
        if (root.pinned.indexOf(id) !== -1) return;
        root.pinned = root.pinned.concat([id]);
        root.savePinned();
        scan.running = true;
    }

    function savePinned() {
        pinnedFile.setText(JSON.stringify(root.pinned, null, 2));
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
