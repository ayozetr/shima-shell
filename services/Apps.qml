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

    // DesktopEntries scans lazily: the first access kicks it off and
    // the list arrives later, through applicationsChanged. This gives
    // bindings something to depend on.
    property int revision: 0

    // DesktopEntries scans lazily, and the dock is built out of it,
    // so the scan is started here rather than waiting for the first
    // thing that reads it.
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
            if (!Object.keys(Windows.procIndex).length) Windows.buildIndex();
            tries++;
            if (tries > 12 || root.allResolved()) running = false;
        }
    }

    function allResolved() {
        if (!DesktopEntries.applications.values.length) return false;
        for (const id of Pinned.list) {
            const e = DesktopEntries.byId(id);
            if (!e || !e.icon) return false;
        }
        return true;
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.revision++;
            // Something was installed or removed, so which names
            // kstart can answer to has changed with it.
            root.scanKstartIds();
            // What is installed has changed underneath, so the index
            // that maps a window to an application is stale and the
            // dock may be showing an icon for something that is gone.
            Windows.buildIndex();
            if (Windows.probeDone) Windows.sweepNow();
        }
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
        // Heroic and Lutris, which are known by the name of the
        // window and nothing else.
        if (id && id.indexOf("game:") === 0)
            return Games.entryFor(id.slice("game:".length));
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

    // Read once at startup, and again when a window turns up for a
    // game that was not in it — something installed since. Asked for
    // from the window sweep, which is the only thing that notices.
    function rescanSteam() {
        if (!steamScan.running) steamScan.running = true;
        if (!shortcutScan.running) shortcutScan.running = true;
    }

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

    // The catalogues above, read backwards: the name a game is listed
    // under, down to the Steam id it is listed under it.
    //
    // For windows that have no class. There is nothing else to go on
    // for those, and a title that matches a game Steam has installed
    // is a good deal more than nothing — the alternative on the
    // machine this was found on was a game running fullscreen with no
    // icon in the dock at all.
    //
    // Lowercase on both sides, because a titlebar capitalises for the
    // person reading it and a manifest does not have to agree.
    readonly property var steamByName: {
        const out = {};
        // Manifests last, so an installed game wins over one added by
        // hand under the same name: it has a name Steam itself wrote
        // and an icon installed in the theme.
        for (const sid in root.steamShortcuts) {
            const n = root.steamShortcuts[sid].name;
            if (n) out[String(n).trim().toLowerCase()] = sid;
        }
        for (const gid in root.steamGames) {
            const n = root.steamGames[gid];
            if (n) out[String(n).trim().toLowerCase()] = gid;
        }
        return out;
    }

    function steamEntry(id) {
        const appId = id.slice("steam_app_".length);
        const name = root.steamGames[appId];
        if (name) return {
            id: id,
            name: name,
            icon: "steam_icon_" + appId,
            comment: "",
            isSteamGame: true,
            appId: appId
        };

        // Added to Steam by hand rather than installed by it, so there
        // is no manifest and no icon in the theme either: what Steam
        // knows about it is its own artwork, and often not even that.
        const own = root.steamShortcuts[appId];
        if (!own) return null;
        return {
            id: id,
            name: own.name,
            icon: own.art ? "" : "applications-games",
            iconUrl: own.art ? "file://" + own.art : "",
            comment: "",
            isSteamGame: true,
            appId: appId
        };
    }

    // ── Games added to Steam by hand ───────────────────────────
    //
    // A game that was dragged into Steam rather than installed by it
    // has no appmanifest, so everything above walks straight past it:
    // it ran, its window said steam_app_3323031249, nothing in the
    // catalogue answered to that, and the dock stayed empty while the
    // game was on screen. Four of them on the machine this was found
    // on, one of them a co-op mod that had already cost an evening.
    //
    // Steam keeps them somewhere else and in another format: a binary
    // VDF under userdata, which is why this is read through od instead
    // of sed like the manifests are. The id is stored there as a
    // signed 32 bit integer and the window announces the unsigned form
    // of the same number — -971936047 and 3323031249 are one game —
    // and that sign is the whole reason a plain read of the file would
    // have looked right and matched nothing.
    property var steamShortcuts: ({})

    Process {
        id: shortcutScan
        running: true
        // The artwork is listed next to the bytes because deciding
        // which file to use needs the ids the bytes carry, and going
        // back to the disk a second time for that would mean building
        // a command out of names that came off the disk. One pass,
        // names read from the listing, nothing quoted twice.
        command: ["sh", "-c",
            'for cfg in "$HOME/.steam/steam/userdata"/*/config '
            + '"$HOME/.local/share/Steam/userdata"/*/config; do '
            + '  f="$cfg/shortcuts.vdf"; '
            + '  [ -f "$f" ] || continue; '
            + '  [ "$(wc -c < "$f")" -le 1048576 ] || continue; '
            + '  printf "@%s\\n" "$cfg"; '
            + '  for art in "$cfg"/grid/*; do '
            + '    [ -f "$art" ] && printf "+%s\\n" "${art##*/}"; '
            + '  done; '
            + '  od -An -v -tu1 "$f"; '
            + 'done']
        stdout: StdioCollector {
            onStreamFinished: {
                const found = root.shortcutsFromScan(text, Paths.thumbnailDir);
                root.steamShortcuts = found;
                root.revision++;

                const paths = root.iconFilesToCheck(found);
                if (paths.length > 0) {
                    // As arguments and not inside the command, because
                    // these are paths that came off somebody's disk and
                    // one of them is free to hold a quote.
                    iconCheck.command = ["sh", "-c",
                        'for p in "$@"; do [ -f "$p" ] && printf "%s\\n" "$p"; done; exit 0',
                        "shima"].concat(paths);
                    iconCheck.running = true;
                }
            }
        }
    }

    Process {
        id: iconCheck
        stdout: StdioCollector {
            onStreamFinished: {
                const exists = {};
                for (const line of text.split("\n"))
                    if (line !== "") exists[line] = true;
                root.steamShortcuts =
                    root.withIconFiles(root.steamShortcuts, exists);
                root.revision++;
            }
        }
    }

    // One scan into a table of games. The scan is a section per Steam
    // account: the folder it came from, the names of its artwork, and
    // then the file itself as decimal bytes.
    //
    // Each game comes out with a list of pictures to try in order.
    // Some are known to be there because they were just listed; the
    // rest are paths out of Steam's own file and out of a cache
    // somebody else fills, and those have to be asked about. So the
    // answer is given twice: once now with what is certain, and again
    // once the disk has replied — which means the dock is never left
    // waiting for an icon, and never shows the wrong one meanwhile.
    function shortcutsFromScan(text, thumbs) {
        const out = {};

        for (const section of text.split(/^@/m)) {
            const lines = section.split("\n");
            const dir = lines[0].trim();
            if (dir === "") continue;

            const files = [];
            const bytes = [];
            for (let i = 1; i < lines.length; i++) {
                if (lines[i].charAt(0) === "+") files.push(lines[i].slice(1));
                else bytes.push(lines[i]);
            }

            const games = root.parseShortcuts(bytes.join("\n"));
            for (const id in games) {
                const g = games[id];
                const grid = root.gridArt(files, id);
                const cands = [];

                // An icon slot that Steam filled, then one somebody
                // chose by hand in its Properties box. Both are icons
                // and neither needs guessing at.
                if (grid.icon !== "")
                    cands.push({ p: dir + "/grid/" + grid.icon, sure: true });
                if (g.icon !== "") cands.push({ p: g.icon, sure: false });

                // Then what Steam downloaded for the library, which is
                // a wordmark and two rectangles. Worse in a square
                // tile than an icon, better than nothing, and chosen
                // by the person whose dock this is — so ahead of
                // anything we went looking for ourselves.
                for (const rest of grid.rest)
                    cands.push({ p: dir + "/grid/" + rest, sure: true });

                // And last, the picture a file manager already made of
                // the executable. Only reached when Steam has nothing
                // at all, so at worst it replaces the generic one.
                for (const t of root.thumbnailsFor(g.exe, thumbs))
                    cands.push({ p: t, sure: false });

                out[id] = { name: g.name, cands: cands,
                            art: root.firstArt(cands, {}) };
            }
        }
        return out;
    }

    // The artwork of one game out of a listing of the folder: the icon
    // on its own, and the others in the order they are worth drawing —
    // the logo, the header, the poster. Anything that is not a picture
    // is not a candidate, which the .json beside each of them is.
    function gridArt(files, id) {
        const kinds = ["png", "jpg", "jpeg", "webp", "ico", "bmp"];
        const rest = [];
        let icon = "";
        const rank = {};
        for (const file of files) {
            const dot = file.lastIndexOf(".");
            if (dot < 0) continue;
            if (kinds.indexOf(file.slice(dot + 1).toLowerCase()) < 0) continue;
            const stem = file.slice(0, dot);
            if (stem === id + "_icon") { icon = file; continue; }
            const r = stem === id + "_logo" ? 0
                    : stem === id ? 1
                    : stem === id + "p" ? 2 : -1;
            if (r < 0) continue;
            rank[file] = r;
            rest.push(file);
        }
        rest.sort((a, b) => rank[a] - rank[b]);
        return { icon: icon, rest: rest };
    }

    // Where a file manager would have left its picture of a file. The
    // name is the md5 of the address, percent-escaped — the standard
    // is old enough that this is spelled out in it — and the sizes are
    // tried largest first, since this ends up in a tile and not in a
    // list.
    function thumbnailsFor(exe, thumbs) {
        if (!exe || !thumbs || exe.charAt(0) !== "/") return [];
        const name = Qt.md5(encodeURI("file://" + exe)) + ".png";
        return [thumbs + "/x-large/" + name,
                thumbs + "/large/" + name,
                thumbs + "/normal/" + name];
    }

    // The path out of an Exe line, which is a command and not a path:
    // quoted, and with the game's own arguments after it.
    function exePath(exe) {
        if (!exe) return "";
        const line = exe.trim();
        const path = line.charAt(0) === '"'
            ? line.slice(1, line.indexOf('"', 1) < 0 ? undefined
                                                     : line.indexOf('"', 1))
            : line.split(" ")[0];
        return path.charAt(0) === "/" ? path : "";
    }

    // The first picture of the list that is actually there.
    function firstArt(cands, exists) {
        for (const c of cands)
            if (c.sure || exists[c.p] === true) return c.p;
        return "";
    }

    // Which paths are worth asking the disk about: the unconfirmed
    // ones that could still win, which is those ahead of the first
    // picture we already know is there. Everything past that one is
    // settled whatever the answer, and a game whose icon slot is
    // filled asks nothing at all — which matters once a library has
    // twenty of these in it and each would otherwise have gone looking
    // for three thumbnails it was never going to draw.
    function iconFilesToCheck(found) {
        const out = [];
        for (const id in found) {
            for (const c of found[id].cands) {
                if (c.sure) break;
                if (out.indexOf(c.p) < 0) out.push(c.p);
            }
        }
        return out;
    }

    // And the table again, now that the disk has answered. A new
    // object rather than the same one changed in place, or nothing
    // downstream would notice.
    function withIconFiles(found, exists) {
        const out = {};
        for (const id in found)
            out[id] = { name: found[id].name, cands: found[id].cands,
                        art: root.firstArt(found[id].cands, exists) };
        return out;
    }

    // Valve's binary VDF, as decimal bytes from od.
    //
    // A byte says what comes next: 0 opens an object and carries its
    // name, 1 is a name and a string, 2 is a name and four bytes of
    // number, 8 closes an object. Only two names are wanted out of the
    // whole file, so the rest is walked and dropped — but it has to be
    // walked properly, because the only way to find where a value ends
    // is to know what kind of value it is. A byte that means nothing
    // here is where knowing that stops, so this stops with it rather
    // than reading a length out of somebody's game title.
    function parseShortcuts(dump) {
        const b = [];
        for (const piece of dump.split(/[^0-9]+/))
            if (piece !== "") b.push(parseInt(piece, 10) & 255);

        const out = {};
        let i = 0;
        let id = "", name = "", icon = "", exe = "";

        // Percent escapes and then decodeURIComponent, which is the
        // one decoder that is certainly there and certainly reads
        // UTF-8: a game called Bloodborne™ arrives as three bytes and
        // reading them one at a time would have hung a Â™ on it.
        function str() {
            let enc = "";
            while (i < b.length && b[i] !== 0) {
                enc += "%" + (b[i] < 16 ? "0" : "") + b[i].toString(16);
                i++;
            }
            i++;
            try { return decodeURIComponent(enc); } catch (e) { return ""; }
        }

        function flush() {
            // The icon is whatever was put in Steam's own Properties
            // box, which is a path and may well be a path to nothing:
            // one of the four on the machine this was written for
            // pointed at C:\Program Files, and another at a file that
            // had since been deleted. Kept as it stands and checked
            // later; a Windows path cannot be checked at all, so only
            // an absolute one is worth carrying.
            if (id !== "" && name !== "")
                out[id] = { name: name,
                            icon: icon.charAt(0) === "/" ? icon : "",
                            exe: root.exePath(exe) };
            id = ""; name = ""; icon = ""; exe = "";
        }

        while (i < b.length) {
            const type = b[i++];
            if (type === 8) { flush(); continue; }
            if (type === 0) { str(); continue; }
            if (type === 1) {
                const key = str().toLowerCase();
                const value = str();
                if (key === "appname") name = value;
                else if (key === "icon") icon = value;
                else if (key === "exe") exe = value;
                continue;
            }
            if (type === 2) {
                const key = str().toLowerCase();
                if (i + 4 > b.length) break;
                const n = b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);
                i += 4;
                // The sign is the point: Steam writes it as a signed
                // number and the window class carries the unsigned one.
                if (key === "appid") id = (n >>> 0).toString();
                continue;
            }
            break;
        }
        flush();
        return out;
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

    // The name kstart has to be given, for each id we might be asked
    // to start.
    //
    // kstart looks a program up by the name of its .desktop file. The
    // id the spec gives that file is the path under applications/ with
    // the slashes turned into dashes, so for one sitting directly in
    // there the two strings are the same and nobody noticed the
    // difference. For one in a subfolder they are not:
    // wine/Programs/MobaXterm/MobaXterm.desktop has the id
    // `wine-Programs-MobaXterm-MobaXterm`, kstart answers `No such
    // service ""` to that — and then does not exit, so every click on
    // the icon did nothing, said nothing, and left another kstart
    // behind. Wine installs everything it touches into such a
    // subfolder, so that was every Windows program on the machine.
    //
    // Three things were tried before this one, and all three are
    // written down because each looks reasonable until you measure it:
    //
    //  * giving kstart the full path to the .desktop file: it hangs on
    //    that too;
    //  * cutting the id at its last dash: `brave-browser` is a file in
    //    applications/ whose own name has a dash, and that would break
    //    a launch that works today;
    //  * leaving kstart out and calling entry.execute(): it starts,
    //    but a .desktop with a `Path=` of its own is then run from the
    //    wrong directory, and a program that keeps its settings beside
    //    itself comes up looking like a different program.
    //
    // So the names are not guessed at. The directories are walked, the
    // id is built the way the spec builds it, and the file name is
    // taken from the file. A name that turns up twice is left out
    // rather than resolved by chance.
    property var kstartNames: ({})

    function kstartName(id) {
        if (!id) return "";
        if (!Object.prototype.hasOwnProperty.call(root.kstartNames, id)) return "";
        return root.kstartNames[id];
    }

    function scanKstartIds() { kstartScan.running = true; }

    Process {
        id: kstartScan
        running: true
        command: ["sh", "-c",
            'set -- "${XDG_DATA_HOME:-$HOME/.local/share}"; '
            + 'IFS=:; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do '
            + '  set -- "$@" "$d"; done; unset IFS; '
            + 'for d in "$@"; do '
            + '  [ -d "$d/applications" ] || continue; '
            + '  ( cd "$d/applications" 2>/dev/null || exit 0; '
            + '    find . -name "*.desktop" -type f 2>/dev/null | while read -r rel; do '
            + '      rel=${rel#./}; base=${rel##*/}; '
            + '      printf "%s\t%s\n" "$(printf "%s" "${rel%.desktop}" | tr "/" "-")" "${base%.desktop}"; '
            + '    done ) ; '
            + 'done 2>/dev/null']
        stdout: StdioCollector {
            onStreamFinished: {
                // Counted first, so a name shared by two files can be
                // left out of both rather than sending one of them to
                // whichever kstart happens to find.
                const count = {};
                const pairs = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 1) continue;
                    const id = line.slice(0, tab).trim();
                    const base = line.slice(tab + 1).trim();
                    if (id === "" || base === "") continue;
                    pairs.push([id, base]);
                    count[base] = (count[base] || 0) + 1;
                }
                const out = {};
                for (const [id, base] of pairs)
                    if (count[base] === 1) out[id] = base;
                root.kstartNames = out;
            }
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

        // A game is only known while its window is there — the
        // catalogue says which executable belongs to it, not how its
        // launcher would start it. So there is nothing to do here, and
        // clicking one that has closed does nothing rather than
        // something wrong.
        if (entry.isGame) return;

        const kname = root.kstartName(entry.id);
        if (root.hasKstart && kname !== "")
            Quickshell.execDetached(["kstart", "--application", kname]);
        else
            entry.execute();

        // And then bring it to the front ourselves. Handing over an
        // activation token is not something a launcher can do from
        // outside: the token has to be asked for by a window that
        // already has the focus, which is why Plasma's own menu
        // manages it and a separate process cannot. Raising through
        // kdotool goes to KWin directly and is not subject to that.
        Windows.raiseWhenItAppears(entry.id);
    }
}
