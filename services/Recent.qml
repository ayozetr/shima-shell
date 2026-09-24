pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What was opened recently, for the launcher's own category.
//
// Two sources, because they are two different things. The activity
// database scores what gets opened and stamps it with a time, which is
// where the applications come from. Files come from the freedesktop
// list of recent documents — the same one the file dialogs fill —
// since nothing records those for us.
Singleton {
    id: root

    // Merged rather than shown apart: what you were doing a minute
    // ago is one answer, not two.
    property var all: []             // both, for searching
    property var apps: []            // the ones you open most
    property var files: []           // what you opened last

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
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    function read() {
        if (!recentProbe.running) recentProbe.running = true;
    }

    function parse(text) {
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
                const entry = Apps.entryFor(id);
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
                files.push(Apps.fileEntry(path));
            }
        }

        const merged = apps.concat(files);
        if (root.sameList(merged, root.all)) return;

        root.apps = apps;
        root.files = files;
        root.all = merged;
        Apps.revision++;
    }

    function sameList(a, b) {
        if (a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if ((a[i].id || a[i].name) !== (b[i].id || b[i].name)) return false;
        }
        return true;
    }
}
