pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's own view of what is installed: KDE's menu, the
// categories down the side and the list the grid draws.
//
// The launcher shows what the K menu shows, because reading the
// .desktop files ourselves shows entries that were deliberately hidden
// from it — deleting one in KDE's menu editor does not delete
// anything, it parks the entry in a ".hidden" submenu and excludes it.
// Resolving all that (merges, per-user edits, excludes, .directory
// names) is what KDE already does, and it will print the result.
//
// It only reads: the cache is left alone when it is up to date.
Singleton {
    id: root

    // Read as soon as this exists rather than when the launcher first
    // opens, so the sidebar is already itself by then. When this
    // exists is the shell's business: see the waking list in Shima.qml.
    Component.onCompleted: root.read()

    property var menuApps: ({})     // category → [ids], KDE's own order
    property var menuCats: []       // category names, as KDE names them
    property bool hasMenu: false
    property real menuReadAt: 0

    Process {
        id: menuProbe
        command: ["kbuildsycoca6", "--menutest"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    function read() {
        // Cheap (some 45 ms) but not free, and the launcher asks every
        // time it opens.
        if (menuProbe.running || Date.now() - root.menuReadAt < 3000) return;
        root.menuReadAt = Date.now();
        menuProbe.running = true;
    }

    function parse(text) {
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
        const changed = !root.same(root.menuApps, byCat);
        root.menuApps = byCat;
        root.menuCats = order;
        root.hasMenu = true;
        if (changed) Apps.revision++;
    }

    // Whether two readings of the menu say the same thing. Turning
    // both into text was the obvious way of asking and the expensive
    // one — the whole menu serialised twice, every time the launcher
    // opens. Walking them answers the same question and stops at the
    // first difference.
    function same(a, b) {
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
            { id: "clipboard", label: I18n.t.catClipboard, match: [] },
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
        { id: "clipboard", label: I18n.t.catClipboard, match: [] },
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
                || c.id === "recent" || c.id === "places"
                || c.id === "clipboard") continue;
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
    function list(category, query) {
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
            for (const id of Favorites.list) {
                const e = Apps.entryFor(id);
                if (!e || e.noDisplay) continue;
                if (!root.matchesQuery(e, q)) continue;
                out.push(e);
            }
            return out;
        }

        // Already in the order that matters: newest first.
        if (category === "recent") {
            for (const e of Recent.all) {
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
                    const e = Apps.entryFor(id);
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

    // How many apps each category holds, so empty ones stay hidden.
    //
    // Worked out once and kept, rather than on demand: the sidebar
    // asked for it once per category and every call built the whole
    // map again, so reading fifteen numbers meant fifteen passes over
    // the catalogue — and the revision it hangs on moves a dozen times
    // while the shell is still starting.
    readonly property var categoryCounts: {
        Apps.revision;
        const counts = {};
        if (root.hasMenu) {
            const seen = {};
            for (const c of root.menuCats) {
                counts[c] = (root.menuApps[c] || []).length;
                for (const id of (root.menuApps[c] || [])) seen[id] = true;
            }
            counts.all = Object.keys(seen).length;
            counts.favorites = Favorites.list.length;
            counts.recent = Recent.all.length;
            counts.places = Places.entries.length;
            counts.clipboard = Clipboard.entries.length;
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
        counts.favorites = Favorites.list.length;
        counts.recent = Recent.all.length;
        counts.places = Places.entries.length;
        counts.clipboard = Clipboard.entries.length;
        return counts;
    }
}
