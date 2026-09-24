pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's favourites, kept in step with the K menu's.
//
Singleton {
    id: root

    // Favourites are not the dock. Pinning puts an app on the bar,
    // where there is room for a handful; favouriting puts it first in
    // the launcher, where there is room for the ones you reach for
    // without wanting them on screen all day.
    property var list: []
    readonly property string favoritesPath: Paths.stateDir + "/favorites.json"

    function has(id) { return root.list.indexOf(id) !== -1; }

    // ── Inheriting the K menu's own ────────────────────────────
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
        stdout: StdioCollector { onStreamFinished: root.applyImported(text) }
    }

    function importFromPlasma() {
        if (!favImport.running) favImport.running = true;
    }

    // Called whenever the launcher opens, so a favourite added in the
    // K menu shows up here. A write of our own is given a moment to
    // reach Plasma first, or reading back would undo it.
    function refresh() {
        if (Date.now() - root.favWroteAt < 1500) return;
        root.importFromPlasma();
    }

    function applyImported(text) {
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
            if (!Apps.entryFor(id)) continue;
            out.push(id);
        }
        if (out.length === 0) return;
        if (out.join("\u0000") === root.list.join("\u0000")) return;
        root.list = out;
        favoritesFile.setText(JSON.stringify(root.list, null, 2));
        Apps.revision++;
    }

    function toggle(id) {
        const wanted = !root.has(id);
        root.list = wanted
            ? root.list.concat([id])
            : root.list.filter(x => x !== id);
        favoritesFile.setText(JSON.stringify(root.list, null, 2));
        Apps.revision++;
        root.setInKde(id, wanted);
    }

    function move(from, to) {
        if (from === to || from < 0 || to < 0) return;
        const list = root.list.slice();
        if (from >= list.length) return;
        to = Math.min(to, list.length - 1);
        list.splice(to, 0, list.splice(from, 1)[0]);
        root.list = list;
        favoritesFile.setText(JSON.stringify(root.list, null, 2));
        Apps.revision++;
        root.writeOrder();
    }

    // Plasma keeps the order of its favourites apart from the links
    // themselves, in its own config, and only rewrites it when the
    // menu applet happens to be running. Writing it here is what keeps
    // the two in step without depending on that.
    Process { id: favOrderWriter }

    function writeOrder() {
        const parts = [];
        for (const id of root.list) parts.push("applications:" + id + ".desktop");
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

    function setInKde(id, on) {
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

    FileView {
        id: favoritesFile
        path: root.favoritesPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(favoritesFile.text());
                if (Array.isArray(parsed)) {
                    root.list = parsed;
                    Apps.revision++;
                }
            } catch (e) { /* corrupt: keep whatever is already loaded */ }
        }
        // First run: start from whatever is already favourited in the
        // K menu, which is what one expects to see.
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound)
                root.importFromPlasma();
        }
    }
}
