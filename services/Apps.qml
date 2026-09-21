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

    // Favourites are not the dock. Pinning puts an app on the bar,
    // where there is room for a handful; favouriting puts it first in
    // the launcher, where there is room for the ones you reach for
    // without wanting them on screen all day.
    property var favorites: []
    readonly property string favoritesPath: Quickshell.statePath("favorites.json")

    property bool hasKdotool: false
    // Don't scan until we know whether kdotool is around: the first
    // sweep would fall back to the process list and light up icons that
    // vanish as soon as the real window list arrives.
    property bool probeDone: false

    // DesktopEntries scans lazily: the first access kicks it off and
    // the list arrives later, through applicationsChanged. This gives
    // bindings something to depend on.
    property int revision: 0

    Component.onCompleted: {
        DesktopEntries.applications.values.length;
        root.readMenu();
    }

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

    // ── The KDE menu ───────────────────────────────────────────
    //
    // The launcher shows what the K menu shows, because reading the
    // .desktop files ourselves shows entries that were deliberately
    // hidden from it — deleting one in KDE's menu editor does not
    // delete anything, it parks the entry in a ".hidden" submenu and
    // excludes it. Resolving all that (merges, per-user edits,
    // excludes, .directory names) is what KDE already does, and it
    // will print the result.
    //
    // It only reads: the cache is left alone when it is up to date.
    property var menuApps: ({})     // category → [ids], KDE's own order
    property var menuCats: []       // category names, as KDE names them
    property bool hasMenu: false
    property real menuReadAt: 0

    Process {
        id: menuProbe
        command: ["kbuildsycoca6", "--menutest"]
        stdout: StdioCollector { onStreamFinished: root.parseMenu(text) }
    }

    function readMenu() {
        // Cheap (some 45 ms) but not free, and the launcher asks every
        // time it opens.
        if (menuProbe.running || Date.now() - root.menuReadAt < 3000) return;
        root.menuReadAt = Date.now();
        menuProbe.running = true;
    }

    function parseMenu(text) {
        const byCat = {};
        const order = [];

        for (const line of text.split("\n")) {
            const parts = line.split("\t");
            if (parts.length < 2) continue;
            const path = parts[0].replace(/\/+$/, "");
            const file = parts[1].trim();
            if (!path || !file.endsWith(".desktop")) continue;

            // Nested submenus (Wine/Programs/Vital) fold into their
            // top level: a sidebar one level deep is a sidebar you can
            // read at a glance.
            const cat = path.split("/")[0];
            const id = file.slice(0, -".desktop".length);

            if (!byCat[cat]) { byCat[cat] = []; order.push(cat); }
            if (byCat[cat].indexOf(id) === -1) byCat[cat].push(id);
        }

        if (order.length === 0) {
            // No KDE menu to read: fall back to sorting by the
            // categories in each .desktop, which is what this did
            // before.
            root.hasMenu = false;
            return;
        }

        order.sort((a, b) => a.localeCompare(b, I18n.language));
        root.menuApps = byCat;
        root.menuCats = order;
        root.hasMenu = true;
        root.revision++;
    }

    // ── Categories ─────────────────────────────────────────────
    //
    // A .desktop declares several categories at once ("Qt;KDE;System;"),
    // so we keep the first of the main ones that shows up, in this
    // order.
    readonly property var categories: {
        if (!root.hasMenu) return root.ownCategories;
        const out = [
            { id: "favorites", label: I18n.t.catFavorites, match: [] },
            { id: "frequent", label: I18n.t.catFrequent, match: [] },
            { id: "all", label: I18n.t.catAll, match: [] }
        ];
        // KDE has already translated these, so they are its words and
        // not ours. That is the point: the sidebar says what the K
        // menu says.
        for (const c of root.menuCats) out.push({ id: c, label: c, match: [] });
        return out;
    }

    // Used only when KDE's menu can't be read.
    readonly property var ownCategories: [
        { id: "favorites", label: I18n.t.catFavorites, match: [] },
        { id: "frequent", label: I18n.t.catFrequent, match: [] },
        { id: "all",     label: I18n.t.catAll,      match: [] },
        { id: "net",     label: I18n.t.catNet,   match: ["Network", "WebBrowser", "Email"] },
        { id: "media",   label: I18n.t.catMedia, match: ["AudioVideo", "Audio", "Video", "Player"] },
        { id: "games",   label: I18n.t.catGames,     match: ["Game"] },
        { id: "gfx",     label: I18n.t.catGfx,   match: ["Graphics", "Photography"] },
        { id: "office",  label: I18n.t.catOffice,    match: ["Office", "TextEditor", "Spreadsheet"] },
        { id: "dev",     label: I18n.t.catDev, match: ["Development", "IDE"] },
        { id: "system",  label: I18n.t.catSystem,    match: ["System", "Settings", "Security"] },
        { id: "utils",   label: I18n.t.catUtils, match: ["Utility", "Accessories", "Archiving"] },
        { id: "other",   label: I18n.t.catOther,      match: [] }
    ]

    function categoryOf(entry) {
        const cats = entry.categories || [];
        for (const c of root.ownCategories) {
            // These three are not read off the .desktop: two are
            // catch-alls and the third is a list you keep yourself.
            if (c.id === "all" || c.id === "other"
                || c.id === "favorites" || c.id === "frequent") continue;
            for (const m of c.match)
                if (cats.indexOf(m) !== -1) return c.id;
        }
        return "other";
    }

    // Search the comment and keywords too: "browser" finds Brave even
    // though its name doesn't contain it.
    function matchesQuery(entry, q) {
        if (!q) return true;
        const hay = [entry.name, entry.genericName, entry.comment]
            .concat(entry.keywords || [])
            .filter(x => x)
            .join(" ")
            .toLowerCase();
        return hay.indexOf(q) !== -1;
    }

    // Visible apps, sorted by name and filtered by category and by
    // whatever was typed.
    function listApps(category, query) {
        const q = (query || "").trim().toLowerCase();
        const out = [];

        // These two are ordered lists, not catalogues: favourites by
        // the order you arranged them, frequent by how much you use
        // them. Sorting either alphabetically would throw away the
        // only thing they say.
        if (category === "favorites" || category === "frequent") {
            const ids = category === "favorites" ? root.favorites : root.frequent;
            for (const id of ids) {
                const e = root.entryFor(id);
                if (!e || e.noDisplay) continue;
                if (!root.matchesQuery(e, q)) continue;
                out.push(e);
            }
            return out;
        }

        if (root.hasMenu) {
            // One pass over the menu, so an app that KDE lists in two
            // places is not listed twice here.
            const seen = {};
            const cats = (category && category !== "all")
                ? [category] : root.menuCats;
            for (const c of cats) {
                for (const id of (root.menuApps[c] || [])) {
                    if (seen[id]) continue;
                    seen[id] = true;
                    const e = root.entryFor(id);
                    if (!e || e.noDisplay) continue;
                    if (!root.matchesQuery(e, q)) continue;
                    out.push(e);
                }
            }
        } else {
            for (const e of DesktopEntries.applications.values) {
                if (e.noDisplay) continue;
                if (category && category !== "all"
                    && root.categoryOf(e) !== category) continue;
                if (!root.matchesQuery(e, q)) continue;
                out.push(e);
            }
        }

        out.sort((a, b) => a.name.localeCompare(b.name, I18n.language));
        return out;
    }

    function isFavorite(id) { return root.favorites.indexOf(id) !== -1; }

    // ── Frequently used ────────────────────────────────────────
    //
    // The same database that holds the favourites also scores what
    // gets opened, which is where the K menu's "frequently used" comes
    // from. A resource can be scored once per activity, so the scores
    // are added up rather than taken one by one.
    property var frequent: []

    Process {
        id: freqProbe
        command: ["sh", "-c",
            "sqlite3 \"$HOME/.local/share/kactivitymanagerd/resources/database\" "
            + "\"SELECT targettedResource FROM ResourceScoreCache "
            + "  WHERE targettedResource LIKE 'applications:%' "
            + "  GROUP BY targettedResource "
            + "  ORDER BY SUM(cachedScore) DESC LIMIT 40;\" 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parseFrequent(text) }
    }

    function readFrequent() {
        if (!freqProbe.running) freqProbe.running = true;
    }

    function parseFrequent(text) {
        const out = [];
        for (const raw of text.split("\n")) {
            let id = raw.trim();
            if (id.indexOf("applications:") !== 0) continue;
            id = id.slice("applications:".length);
            if (id.endsWith(".desktop")) id = id.slice(0, -".desktop".length);
            if (out.indexOf(id) !== -1) continue;
            if (!root.entryFor(id)) continue;
            out.push(id);
        }
        root.frequent = out;
        root.revision++;
    }

    // ── Inheriting the K menu's favourites ─────────────────────
    //
    // Plasma stopped keeping these in its config: since 5.19 they live
    // in the KActivities database, which is why there is a
    // favoritesPortedToKAstats=true and nothing else to read there.
    // That table has no order, though — the order is a separate list
    // in kactivitymanagerd-statsrc — so both are read and joined:
    // ordered ones first, then anything the list forgot.
    Process {
        id: favImport
        command: ["sh", "-c",
            "cfg=\"$HOME/.config/kactivitymanagerd-statsrc\"; "
            + "db=\"$HOME/.local/share/kactivitymanagerd/resources/database\"; "
            + "awk '/^\\[Favorites-.*-global\\]/{f=1;next} "
            + "     f&&/^ordering=/{sub(/^ordering=/,\"\");print;exit}' "
            + "  \"$cfg\" 2>/dev/null | tr ',' '\\n'; "
            + "sqlite3 \"$db\" \"SELECT targettedResource FROM ResourceLink "
            + "  WHERE initiatingAgent='org.kde.plasma.favorites.applications';\" "
            + "  2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.applyImportedFavorites(text) }
    }

    function importFavoritesFromPlasma() {
        if (!favImport.running) favImport.running = true;
    }

    // Called whenever the launcher opens, so a favourite added in the
    // K menu shows up here. A write of our own is given a moment to
    // reach Plasma first, or reading back would undo it.
    function refreshFavorites() {
        if (Date.now() - root.favWroteAt < 1500) return;
        root.importFavoritesFromPlasma();
    }

    function applyImportedFavorites(text) {
        const out = [];
        for (const raw of text.split("\n")) {
            let id = raw.trim();
            if (id === "") continue;
            // "applications:spotify.desktop" and "org.kde.discover.desktop"
            // are both ways of saying the same thing.
            if (id.indexOf("applications:") === 0)
                id = id.slice("applications:".length);
            if (id.endsWith(".desktop")) id = id.slice(0, -".desktop".length);
            if (out.indexOf(id) !== -1) continue;
            if (!root.entryFor(id)) continue;
            out.push(id);
        }
        if (out.length === 0) return;
        root.favorites = out;
        favoritesFile.setText(JSON.stringify(root.favorites, null, 2));
        root.revision++;
    }

    function toggleFavorite(id) {
        const wanted = !root.isFavorite(id);
        root.favorites = wanted
            ? root.favorites.concat([id])
            : root.favorites.filter(x => x !== id);
        favoritesFile.setText(JSON.stringify(root.favorites, null, 2));
        root.revision++;
        root.setKdeFavorite(id, wanted);
    }

    function moveFavorite(from, to) {
        if (from === to || from < 0 || to < 0) return;
        const list = root.favorites.slice();
        if (from >= list.length) return;
        to = Math.min(to, list.length - 1);
        list.splice(to, 0, list.splice(from, 1)[0]);
        root.favorites = list;
        favoritesFile.setText(JSON.stringify(root.favorites, null, 2));
        root.revision++;
        root.writeFavoriteOrder();
    }

    // Plasma keeps the order of its favourites apart from the links
    // themselves, in its own config, and only rewrites it when the
    // menu applet happens to be running. Writing it here is what keeps
    // the two in step without depending on that.
    Process { id: favOrderWriter }

    function writeFavoriteOrder() {
        const parts = [];
        for (const id of root.favorites) parts.push("applications:" + id + ".desktop");
        root.favWroteAt = Date.now();

        favOrderWriter.command = ["sh", "-c",
            "cfg=\"$HOME/.config/kactivitymanagerd-statsrc\"; "
            // Every favourites group gets the same order: there is one
            // per applet instance and one per activity, and leaving
            // any of them behind brings the old order back.
            + "grep -oE '^\\[Favorites-[^]]+\\]' \"$cfg\" 2>/dev/null "
            + "  | tr -d '[]' | while read -r g; do "
            + "    kwriteconfig6 --notify --file kactivitymanagerd-statsrc "
            + "      --group \"$g\" --key ordering \"$1\"; "
            + "  done",
            "shima", parts.join(",")];
        favOrderWriter.running = true;
    }

    // The favourites are one list, shared with the K menu, so a change
    // here is a change there. It goes through the activity manager
    // rather than into its database: writing to the file underneath a
    // running daemon would either be ignored or overwritten, and this
    // is what tells Plasma to redraw.
    property real favWroteAt: 0

    Process { id: favWriter }

    function setKdeFavorite(id, on) {
        root.favWroteAt = Date.now();
        const call = "busctl --user call org.kde.ActivityManager"
            + " /ActivityManager/Resources/Linking"
            + " org.kde.ActivityManager.ResourcesLinking";
        const agent = "org.kde.plasma.favorites.applications";
        const method = on ? "LinkResourceToActivity" : "UnlinkResourceFromActivity";

        // Plasma stores some of these with the applications: prefix
        // and some without, so removal tries both. Unlinking something
        // that was never linked is a no-op.
        const forms = on
            ? ["applications:" + id + ".desktop"]
            : ["applications:" + id + ".desktop", id + ".desktop"];

        const parts = [];
        for (const res of forms) {
            parts.push(call + " " + method + " sss '" + agent + "' '"
                       + res + "' ':global'");
        }
        favWriter.command = ["sh", "-c", parts.join("; ") + " >/dev/null 2>&1"];
        favWriter.running = true;
    }

    // Editing an entry opens KDE's properties dialog for its .desktop,
    // which is where the name, icon, command, arguments and categories
    // all live, and which writes the file itself.
    //
    // Not kmenuedit, although it takes an entry on the command line:
    // it does not navigate to it. Tried the bare id, the English
    // submenu name and the translated one — it lands on "Lost &
    // Found" either way. And half of these entries are not in the
    // menu at all: a Steam game's .desktop never reaches it, so there
    // would be nothing to navigate to.
    //
    // The path is searched rather than guessed, because an entry can
    // come from the user's directory, the system's or a flatpak
    // export, and the id alone doesn't say which.
    function editApp(id) {
        // Plain strings, not a template literal: in one, ${...} is
        // JavaScript interpolation and the shell variables vanish.
        Quickshell.execDetached(["sh", "-c",
            "IFS=:; "
            + "for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" "
            + "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do "
            + "  f=\"$d/applications/$1.desktop\"; "
            + "  [ -f \"$f\" ] && exec kioclient openProperties \"$f\"; "
            + "done; "
            // Entries that live in a subdirectory carry it in their
            // id, so fall back to looking for the file itself.
            + "unset IFS; "
            + "f=$(find \"$HOME/.local/share/applications\" "
            + "  /usr/share/applications /usr/local/share/applications "
            + "  -name \"$1.desktop\" 2>/dev/null | head -1); "
            + "[ -n \"$f\" ] && exec kioclient openProperties \"$f\"",
            "shima", id]);
    }

    // How many apps each category holds, so empty ones stay hidden.
    function categoryCounts() {
        const counts = {};
        if (root.hasMenu) {
            const seen = {};
            for (const c of root.menuCats) {
                counts[c] = (root.menuApps[c] || []).length;
                for (const id of (root.menuApps[c] || [])) seen[id] = true;
            }
            counts.all = Object.keys(seen).length;
            counts.favorites = root.favorites.length;
            counts.frequent = root.frequent.length;
            return counts;
        }
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            const c = root.categoryOf(e);
            counts[c] = (counts[c] || 0) + 1;
            counts.all = (counts.all || 0) + 1;
        }
        // Not read off the .desktop, so it has to be counted apart or
        // the category would hide itself for being empty.
        counts.favorites = root.favorites.length;
        counts.frequent = root.frequent.length;
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

        // Steam games have no window class of their own: they run as
        // steam_app_<id>, and the id is in the URL their .desktop
        // launches. Ignoring the "steam" binary above is what keeps
        // them from all claiming the Steam process, but it also threw
        // away the one thing that identifies them, so it is read back
        // from the URL — which points at one game and one only.
        if (entry.execString) {
            const url = entry.execString.match(/steam:\/\/(?:rungameid|run)\/(\d+)/);
            if (url) out.push("steam_app_" + url[1]);
        }
        return out;
    }

    function entryFor(id) {
        return DesktopEntries.byId(id) ?? null;
    }

    // Find the application a notification came from.
    //
    // The spec has a field for this, but plenty of senders leave it
    // empty and only give a display name, so that is matched too. It
    // is the difference between every notification wearing the same
    // generic icon and wearing the sender's own.
    function matchApp(desktopEntry, appName) {
        if (desktopEntry) {
            const id = desktopEntry.replace(/\.desktop$/, "");
            const byId = DesktopEntries.byId(id);
            if (byId) return byId;
        }
        if (!appName) return null;

        const want = appName.toLowerCase();
        let tail = null;
        for (const e of DesktopEntries.applications.values) {
            if (e.name && e.name.toLowerCase() === want) return e;
            if (e.id && e.id.toLowerCase() === want) return e;
            // "org.kde.discover" answers to "discover", but only if
            // nothing matched outright.
            if (!tail && e.id && e.id.split(".").pop().toLowerCase() === want) tail = e;
        }
        return tail;
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
            } catch (e) { /* corrupt: keep whatever is already loaded */ }
        }
        // First run: inherit whatever is already pinned in the Plasma
        // task manager, which is what one expects to see.
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) root.importFromPlasma();
        }
    }

    FileView {
        id: favoritesFile
        path: root.favoritesPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(favoritesFile.text());
                if (Array.isArray(parsed)) {
                    root.favorites = parsed;
                    root.revision++;
                }
            } catch (e) { /* corrupt: keep whatever is already loaded */ }
        }
        // First run: start from whatever is already favourited in the
        // K menu, which is what one expects to see.
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                root.importFavoritesFromPlasma();
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
