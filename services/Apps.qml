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

        // A game is only known while its window is there — the
        // catalogue says which executable belongs to it, not how its
        // launcher would start it. So there is nothing to do here, and
        // clicking one that has closed does nothing rather than
        // something wrong.
        if (entry.isGame) return;

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
        Windows.raiseWhenItAppears(entry.id);
    }
}
