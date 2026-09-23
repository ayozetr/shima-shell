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
    // How many sweeps in a row have failed to see each application.
    property var misses: ({})
    readonly property string pinnedPath: Paths.stateDir + "/pinned.json"

    // Favourites are not the dock. Pinning puts an app on the bar,
    // where there is room for a handful; favouriting puts it first in
    // the launcher, where there is room for the ones you reach for
    // without wanting them on screen all day.
    property var favorites: []
    readonly property string favoritesPath: Paths.stateDir + "/favorites.json"

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
        root.syncDockItems();
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
            if (root.probeDone) root.sweepNow();
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

        // The launcher rereads this every time it opens, and saying
        // "something changed" when nothing did makes every icon in the
        // dock reload: they are bound to the revision counter, so the
        // pinned ones blink out and back in.
        const changed = !root.sameMenu(root.menuApps, byCat);
        root.menuApps = byCat;
        root.menuCats = order;
        root.hasMenu = true;
        if (changed) root.revision++;
    }

    // Whether two readings of the menu say the same thing. Turning
    // both into text was the obvious way of asking and the expensive
    // one — the whole menu serialised twice, every time the launcher
    // opens. Walking them answers the same question and stops at the
    // first difference.
    function sameMenu(a, b) {
        const keys = Object.keys(a);
        if (keys.length !== Object.keys(b).length) return false;
        for (const k of keys) {
            const x = a[k], y = b[k];
            if (!y || x.length !== y.length) return false;
            for (let i = 0; i < x.length; i++) if (x[i] !== y[i]) return false;
        }
        return true;
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
            { id: "recent", label: I18n.t.catRecent, match: [] },
            { id: "places", label: I18n.t.catPlaces, match: [] },
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
        { id: "recent", label: I18n.t.catRecent, match: [] },
        { id: "places",  label: I18n.t.catPlaces,   match: [] },
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
            if (c.id === "all" || c.id === "other" || c.id === "favorites"
                || c.id === "recent" || c.id === "places") continue;
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

        // Not applications at all, but the same grid draws them: a
        // name, an icon and something to open.
        if (category === "places") {
            for (const place of Places.entries) {
                if (q && place.name.toLowerCase().indexOf(q) === -1) continue;
                out.push(place);
            }
            return out;
        }

        // These are ordered lists, not catalogues: favourites by the
        // order you arranged them, recent by when you last touched
        // them. Sorting either alphabetically would throw away the
        // only thing they say.
        if (category === "favorites") {
            for (const id of root.favorites) {
                const e = root.entryFor(id);
                if (!e || e.noDisplay) continue;
                if (!root.matchesQuery(e, q)) continue;
                out.push(e);
            }
            return out;
        }

        // Already in the order that matters: newest first.
        if (category === "recent") {
            for (const e of root.recent) {
                if (q && e.name.toLowerCase().indexOf(q) === -1) continue;
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

    // ── Recently used ──────────────────────────────────────────
    //
    // Two sources, because they are two different things. The activity
    // database scores what gets opened and stamps it with a time,
    // which is where the applications come from. Files come from the
    // freedesktop list of recent documents — the same one the file
    // dialogs fill — since nothing records those for us.
    //
    // They are merged by time rather than shown apart: what you were
    // doing a minute ago is one answer, not two.
    property var recent: []          // both, for searching
    property var recentApps: []      // the ten you open most
    property var recentFiles: []     // what you opened last

    Process {
        id: recentProbe
        command: ["sh", "-c",
            "db=\"$HOME/.local/share/kactivitymanagerd/resources/database\"; "
            // Applications by how much they are used, which is what
            // the score is for; files by when they were last touched.
            + "sqlite3 \"$db\" \"SELECT 'app' || char(9) || SUM(cachedScore) "
            + "  || char(9) || targettedResource FROM ResourceScoreCache "
            + "  WHERE targettedResource LIKE 'applications:%' "
            + "  GROUP BY targettedResource ORDER BY SUM(cachedScore) DESC "
            + "  LIMIT 14;\" 2>/dev/null; "
            // The attribute order in this file is fixed, so one pass
            // of grep is enough and there is no need to parse XML.
            + "rec=\"$HOME/.local/share/recently-used.xbel\"; "
            + "[ -f \"$rec\" ] || exit 0; "
            + "grep -oE '<bookmark added=\"[^\"]*\" href=\"[^\"]*\" modified=\"[^\"]*\"' \"$rec\" "
            + "  | sed -E 's/.*href=\"([^\"]*)\" modified=\"([^\"]*)\"/\\2\\t\\1/' "
            + "  | sort -r | head -40 | while IFS=\"\t\" read -r when url; do "
            + "      path=${url#file://}; "
            // Percent-decoding, so the file can be checked for and its
            // name shown as it really is.
            + "      dec=$(printf '%b' \"$(printf '%s' \"$path\" | sed 's/%/\\\\x/g')\"); "
            + "      [ -e \"$dec\" ] || continue; "
            + "      printf 'file\\t%s\\t%s\\n' \"$when\" \"$dec\"; "
            + "  done | head -12"]
        stdout: StdioCollector { onStreamFinished: root.parseRecent(text) }
    }

    function readRecent() {
        if (!recentProbe.running) recentProbe.running = true;
    }

    function parseRecent(text) {
        const apps = [];
        const files = [];
        const seen = {};

        for (const line of text.split("\n")) {
            const parts = line.split("\t");
            if (parts.length < 3) continue;

            if (parts[0] === "app") {
                // Two rows of four.
                if (apps.length >= 8) continue;
                let id = parts[2].trim();
                if (id.indexOf("applications:") === 0)
                    id = id.slice("applications:".length);
                if (id.endsWith(".desktop")) id = id.slice(0, -".desktop".length);
                const entry = root.entryFor(id);
                if (!entry || entry.noDisplay || seen[id]) continue;

                // The same application can be installed twice over —
                // Discord is here as both "discord" and
                // "com.discordapp.Discord" — and each is scored apart,
                // so it would show up twice. The name is what tells
                // them apart for a reader, so it is what decides.
                const label = (entry.name || "").toLowerCase();
                if (label !== "" && seen["name:" + label]) continue;
                seen["name:" + label] = true;

                seen[id] = true;
                apps.push(entry);
            } else {
                if (files.length >= 12) continue;
                const path = parts[2];
                if (seen[path]) continue;
                seen[path] = true;
                files.push(root.fileEntry(path));
            }
        }

        const merged = apps.concat(files);
        if (root.sameList(merged, root.recent)) return;

        root.recentApps = apps;
        root.recentFiles = files;
        root.recent = merged;
        root.revision++;
    }

    function sameList(a, b) {
        if (a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if ((a[i].id || a[i].name) !== (b[i].id || b[i].name)) return false;
        }
        return true;
    }

    // A file drawn like an application: a name, an icon and something
    // to open. The icon comes from the type the way freedesktop names
    // them — "text/plain" is "text-plain", falling back to the family.
    function fileEntry(path) {
        const name = path.replace(/\/+$/, "").split("/").pop();
        const dot = name.lastIndexOf(".");
        const ext = dot > 0 ? name.slice(dot + 1).toLowerCase() : "";
        // A name with no extension is usually a folder here, since the
        // list holds both.

        return {
            id: "file:" + path,
            name: name,
            icon: root.iconForExtension(ext),
            comment: path,
            url: "file://" + encodeURI(path).replace(/#/g, "%23"),
            isPlace: true
        };
    }

    readonly property var extensionIcons: ({
        png: "image-x-generic", jpg: "image-x-generic", jpeg: "image-x-generic",
        gif: "image-x-generic", webp: "image-x-generic", svg: "image-x-generic",
        mp4: "video-x-generic", mkv: "video-x-generic", webm: "video-x-generic",
        mp3: "audio-x-generic", flac: "audio-x-generic", ogg: "audio-x-generic",
        wav: "audio-x-generic",
        pdf: "application-pdf",
        zip: "application-zip", rar: "application-zip", "7z": "application-zip",
        tar: "application-zip", gz: "application-zip",
        txt: "text-x-generic", md: "text-x-generic", log: "text-x-generic",
        qml: "text-x-script", js: "text-x-script", py: "text-x-script",
        sh: "text-x-script", json: "text-x-script",
        desktop: "application-x-executable"
    })

    function iconForExtension(ext) {
        return root.extensionIcons[ext] || (ext === "" ? "folder" : "text-x-generic");
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
        if (out.join("\u0000") === root.favorites.join("\u0000")) return;
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

    // A copy of the .desktop on the desktop, marked as yours to run.
    // Without that flag the file managers show it as an untrusted file
    // and ask before every launch.
    function addToDesktop(id) {
        Quickshell.execDetached(["sh", "-c",
            "desk=$(xdg-user-dir DESKTOP 2>/dev/null); "
            + "[ -n \"$desk\" ] || desk=\"$HOME/Desktop\"; "
            + "[ -d \"$desk\" ] || exit 0; "
            + "IFS=:; "
            + "for d in \"${XDG_DATA_HOME:-$HOME/.local/share}\" "
            + "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do "
            + "  f=\"$d/applications/$1.desktop\"; "
            + "  if [ -f \"$f\" ]; then "
            + "    cp -f \"$f\" \"$desk/\" && chmod +x \"$desk/$1.desktop\"; "
            + "    gio set \"$desk/$1.desktop\" metadata::trusted true 2>/dev/null; "
            + "    exit 0; "
            + "  fi; "
            + "done",
            "shima", id]);
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
    //
    // Worked out once and kept, rather than on demand: the sidebar
    // asked for it once per category and every call built the whole
    // map again, so reading fifteen numbers meant fifteen passes over
    // the catalogue — and the revision it hangs on moves a dozen times
    // while the shell is still starting.
    readonly property var categoryCounts: {
        root.revision;
        const counts = {};
        if (root.hasMenu) {
            const seen = {};
            for (const c of root.menuCats) {
                counts[c] = (root.menuApps[c] || []).length;
                for (const id of (root.menuApps[c] || [])) seen[id] = true;
            }
            counts.all = Object.keys(seen).length;
            counts.favorites = root.favorites.length;
            counts.recent = root.recent.length;
            counts.places = Places.entries.length;
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
        counts.recent = root.recent.length;
        counts.places = Places.entries.length;
        return counts;
    }

    // Open apps that are not pinned. They go into the dock behind the
    // pinned ones, like any task manager does.
    property var runningExtra: []
    // What the dock shows. Kept as a plain list and replaced only when
    // it really differs: concatenating in a binding hands the Repeater
    // a brand new array every time anything it reads changes, and a
    // new array means every icon is destroyed and built again — which
    // is visible, because an icon takes a frame to load and the gap
    // shows.
    property var dockItems: []

    function syncDockItems() {
        const next = root.pinned.concat(root.runningExtra);
        if (next.join("\u0000") === root.dockItems.join("\u0000")) return;
        root.dockItems = next;
    }

    onPinnedChanged: root.syncDockItems()
    onRunningExtraChanged: root.syncDockItems()

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

        // A game that runs under Proton names its window after the
        // Steam id, which the line above covers. One built for Linux
        // names it after its binary instead — Terraria's window class
        // is "Terraria.bin.x86_64" — and that is not in the .desktop
        // at all, since the Exec goes through Steam. Its display name
        // is the only thing left to match on.
        if (entry.name && entry.name.indexOf(" ") === -1)
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

    // ── Our own settings window ────────────────────────────────
    //
    // It is a window like any other program's: you open it, it can end
    // up behind something else, and there has to be a way back to it.
    // Nothing installed on the system claims its window class, and the
    // shell's own surfaces are kept out of the dock on purpose, so the
    // entry is made up here the way a Steam game's is.
    //
    // The class tells them apart: the island, the dock and the launcher
    // are layer surfaces and keep Quickshell's own namespace, while a
    // real window carries the app id the launcher sets — which is how
    // it also comes to wear our icon in its titlebar instead of
    // Quickshell's cog.
    readonly property string settingsClass: "shima"
    readonly property string settingsId: "shima:settings"

    // Installed, the icon is in the theme where every other one is.
    // Run from a checkout it is not installed anywhere, so the file in
    // the tree stands in — which is also the only copy there is then.
    readonly property bool settingsIconInTheme: Quickshell.hasThemeIcon("shima")

    function settingsEntry() {
        return {
            id: root.settingsId,
            name: I18n.t.settingsWindowTitle,
            icon: root.settingsIconInTheme ? "shima" : "",
            iconUrl: root.settingsIconInTheme
                ? "" : Qt.resolvedUrl("../packaging/shima.svg"),
            comment: "",
            isShimaSettings: true
        };
    }

    function entryFor(id) {
        const real = DesktopEntries.byId(id);
        if (real) return real;
        if (id === root.settingsId) return root.settingsEntry();
        // A game with no shortcut created has no .desktop at all, so
        // one is made up from what Steam already knows.
        if (id && id.indexOf("steam_app_") === 0) return root.steamEntry(id);
        return null;
    }

    // ── Steam games without a shortcut ─────────────────────────
    //
    // Creating a shortcut writes a .desktop; not creating one leaves
    // nothing to read, and the game is simply missing from the dock
    // even while you are playing it. Steam does keep a manifest per
    // installed game with its name, and installs an icon for it, so
    // that is enough to stand in for the entry.
    property var steamGames: ({})

    Process {
        id: steamScan
        running: true
        command: ["sh", "-c",
            "for lib in \"$HOME/.steam/steam/steamapps\" "
            + "\"$HOME/.local/share/Steam/steamapps\"; do "
            + "  [ -d \"$lib\" ] || continue; "
            + "  for f in \"$lib\"/appmanifest_*.acf; do "
            + "    [ -f \"$f\" ] || continue; "
            + "    id=${f##*appmanifest_}; id=${id%.acf}; "
            + "    name=$(sed -n 's/^\\t\"name\"\\t*\"\\(.*\\)\"$/\\1/p' \"$f\" | head -1); "
            + "    [ -n \"$name\" ] && printf '%s\\t%s\\n' \"$id\" \"$name\"; "
            + "  done; "
            + "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const games = {};
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0) continue;
                    games[line.slice(0, tab).trim()] = line.slice(tab + 1).trim();
                }
                root.steamGames = games;
                root.revision++;
            }
        }
    }

    function steamEntry(id) {
        const appId = id.slice("steam_app_".length);
        const name = root.steamGames[appId];
        if (!name) return null;
        return {
            id: id,
            name: name,
            icon: "steam_icon_" + appId,
            comment: "",
            isSteamGame: true,
            appId: appId
        };
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

    // Starting an application, as opposed to raising one.
    //
    // Not entry.execute(): on Wayland a window may only take the focus
    // from another if whoever started it hands over an activation
    // token, and without one KWin leaves it behind whatever was in
    // front — which over a fullscreen game means you never see it.
    // kstart is KDE's own launcher and does that part properly.
    property bool hasKstart: false

    Process {
        running: true
        command: ["sh", "-c", "command -v kstart >/dev/null && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: root.hasKstart = text.trim() === "yes"
        }
    }

    function start(entry) {
        if (!entry) return;
        // A place is a folder, not a program: it opens in whatever
        // handles it, which here is the file manager.
        if (entry.isPlace) { Places.open(entry); return; }
        if (entry.isSteamGame) {
            Quickshell.execDetached(["steam", "steam://rungameid/" + entry.appId]);
            return;
        }
        // Ours opens itself; there is no program to start.
        if (entry.isShimaSettings) { SettingsWindow.show(); return; }

        if (root.hasKstart && entry.id)
            Quickshell.execDetached(["kstart", "--application", entry.id]);
        else
            entry.execute();

        // And then bring it to the front ourselves. Handing over an
        // activation token is not something a launcher can do from
        // outside: the token has to be asked for by a window that
        // already has the focus, which is why Plasma's own menu
        // manages it and a separate process cannot. Raising through
        // kdotool goes to KWin directly and is not subject to that.
        if (root.hasKdotool && entry.id) {
            root.raiseId = entry.id;
            root.raiseUntil = Date.now() + 10000;
            raiseTimer.restart();
        }
    }

    // ── Raising what was just started ──────────────────────────
    property string raiseId: ""
    property real raiseUntil: 0

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

    function launch(id) {
        const entry = root.entryFor(id);
        if (!entry) return;

        // Without kdotool there is no way to raise someone else's
        // window on Wayland, so all that's left is launching the app.
        if (!root.hasKdotool) { root.start(entry); return; }

        const lookups = root.windowLookup(id);
        if (!lookups) { root.start(entry); return; }

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
        if (id === root.settingsId)
            return 'wins=$(kdotool search --class '
                 + JSON.stringify("^" + root.settingsClass + "$")
                 + ' 2>/dev/null)';

        const entry = root.entryFor(id);
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
        if (entry) root.start(entry);
    }

    Process { id: windowProc }

    // If there was no window to raise, launch the app instead.
    Process {
        id: activate
        property string pendingId: ""
        onExited: (code) => {
            if (code === 0) return;
            const entry = root.entryFor(activate.pendingId);
            if (entry) root.start(entry);
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
                    console.log("[shima] the task manager has no pinned apps to import");
                    return;
                }
                root.pinned = ids;
                root.savePinned();
                root.revision++;
                root.sweepNow();
            }
        }
    }

    function importFromPlasma() { importer.running = true; }

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
            if (p === root.settingsClass) {
                alive[root.settingsId] = true;
                continue;
            }
            const id = root.idForClass(p);
            if (id !== undefined) { alive[id] = true; continue; }
            // An installed game with no .desktop is known by its window
            // class and nothing else.
            if (p.indexOf("steam_app_") !== 0) continue;
            const app = p.slice("steam_app_".length);
            if (root.steamGames[app] !== undefined) { alive[p] = true; continue; }
            // Installed after the shell started, so it is not in a list
            // that was read once and never again.
            if (!root.steamAsked[app]) {
                root.steamAsked[app] = true;
                if (!steamScan.running) steamScan.running = true;
            }
        }

        // Pinned apps need their own check: their binary may not be in
        // the index if another entry claimed it first.
        const out = {};
        for (const id of root.pinned) {
            const entry = root.entryFor(id);
            out[id] = alive[id] === true
                || (entry ? root.matchesProcess(entry, procs) : false);
        }

        const extra = [];
        if (Config.data.showRunning ?? true) {
            // Don't repeat what the pinned ones already cover: two
            // .desktop files of the same app share a binary.
            const covered = {};
            for (const id of root.pinned) {
                const e = root.entryFor(id);
                if (e) for (const c of root.candidatesFor(e)) covered[c] = true;
            }

            for (const id in alive) {
                if (root.pinned.indexOf(id) !== -1) continue;
                if (root.neverShow.indexOf(id) !== -1) continue;
                const e = root.entryFor(id);
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
        root.sweepNow();
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
