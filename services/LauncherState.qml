pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Whether the launcher is open and which category it is showing.
Singleton {
    id: root
    property bool open: false
    property string category: "all"
    property string query: ""

    // One launcher window exists per screen, and only one surface can
    // hold exclusive keyboard focus: if two ask, one of them is left
    // deaf — you type and nothing happens. The first one to come up
    // claims it and the rest stay quiet. Cleared on close so the next
    // opening is decided again.
    property string focusScreen: ""

    function toggle() { root.open ? root.hide() : root.show(); }
    // Rereading KDE's menu on open is what makes an entry you edited
    // there show up here without restarting anything.
    function show() {
        Menu.read();
        Favorites.refresh();
        Recent.read();
        Games.refresh();
        // Favourites first, which is the point of having them — unless
        // there are none yet, and an empty panel would be a poor
        // greeting.
        root.category = Favorites.list.length > 0 ? "favorites" : "all";
        root.query = "";
        root.open = true;
    }
    function hide()   { root.open = false; root.focusScreen = ""; }

    // ── What the launcher shows ──────────────────────────────────
    //
    // Here and not in the window, because there is a launcher window
    // per screen and they all show the same thing: worked out in the
    // window, every keystroke walked the catalogue once per monitor
    // and filtered the clipboard once per monitor, for two panels
    // showing the same list.
    //
    // Replaced only when it really differs, for the reason the dock's
    // list carries: a new array means the grid throws away every tile
    // and builds it again, and a tile takes a frame to load its icon.
    property var apps: []
    property var clips: []

    function refresh() {
        const nextApps = root.open
            ? Menu.list(root.category, root.query) : [];
        if (!root.sameList(nextApps, root.apps)) root.apps = nextApps;

        const q = root.query.trim();
        const nextClips = [];
        for (const e of Clipboard.entries)
            if (Clipboard.matches(e, q)) nextClips.push(e);
        if (!root.sameList(nextClips, root.clips)) root.clips = nextClips;
    }

    // Two entries are the same when they are the same object, or when
    // both carry an id and it matches: an entry made up for a Steam
    // game is a new object every time it is asked for, so the id is
    // what says it is still the same game.
    //
    // A clipboard entry has no id, and comparing the two missing ones
    // used to say "undefined is undefined" and call them the same — so
    // re-copying a picture, a new entry with a new file but the same
    // length of list, left the launcher showing the old one, whose file
    // had just been deleted under it. Without an id it falls back to the
    // object, which a re-copy does change.
    function sameList(a, b) {
        if (a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) {
            if (a[i] === b[i]) continue;
            if (a[i].id !== undefined && a[i].id === b[i].id) continue;
            return false;
        }
        return true;
    }

    onOpenChanged: root.refresh()
    onCategoryChanged: root.refresh()
    onQueryChanged: root.refresh()

    Connections {
        target: Apps
        function onRevisionChanged() { root.refresh(); }
    }

    Connections {
        target: Clipboard
        function onEntriesChanged() { root.refresh(); }
    }

    // The favourites grid is a snapshot: `apps` is set by refresh()
    // and nothing re-derives it. Until now it followed the favourites
    // only by way of Apps.revision, which every function that changes
    // the list has to remember to bump. All four of them do, today —
    // but the grid showing one list while another is on disk is a
    // thing that happened, right after an install with everything
    // still settling, and the fix for it is not to remember harder.
    // What the grid shows is this list, so it listens to this list.
    Connections {
        target: Favorites
        function onListChanged() { root.refresh(); }
    }

    // Meta+V, which is where hands already go for a clipboard. Opening
    // it is the same as opening the launcher and then picking the
    // category, minus the picking; pressing it again closes it, the
    // way the launcher key does.
    function showClipboard() {
        if (root.open && root.category === "clipboard") { root.hide(); return; }
        root.show();
        root.category = "clipboard";
    }

    // What the global shortcut calls. It is a plain toggle so the same
    // key closes what it opened.
    // The way in from outside: the shortcut helper, which owns the
    // keys registered with KDE, calls these.
    IpcHandler {
        target: "launcher"

        function toggle(): string {
            if (SettingsWindow.capturing) return "capturing";
            root.toggle();
            return root.open ? "open" : "closed";
        }

        // `open` and not `show`, which is the obvious name and is
        // unreachable: `show` is one of the five words the tool keeps
        // for itself — show, call, wait, listen, prop — so
        // `qs ipc call launcher show` prints the list of targets
        // instead of opening anything. Nothing here ever called it, so
        // nobody noticed until somebody tried it by hand.
        //
        // This also leaves the launcher reading like the settings
        // window next door, which has open, close and toggle.
        function open(): string { root.show(); return "open"; }
        function close(): string { root.hide(); return "closed"; }
        function hide(): string { root.hide(); return "closed"; }

        function clipboard(): string {
            // Not while somebody is setting that very key. The press
            // belongs to the box waiting for it, not to us.
            if (SettingsWindow.capturing) return "capturing";
            root.showClipboard();
            return root.open ? "open" : "closed";
        }
    }
}
