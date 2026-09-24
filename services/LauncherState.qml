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

    // By identity where there is one and by id otherwise: an entry
    // made up for a Steam game is a new object every time it is asked
    // for, so comparing the objects would never say they are the same.
    function sameList(a, b) {
        if (a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++)
            if (a[i] !== b[i] && a[i].id !== b[i].id) return false;
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
    IpcHandler {
        target: "launcher"

        function toggle(): string {
            root.toggle();
            return root.open ? "open" : "closed";
        }

        function show(): string { root.show(); return "open"; }
        function hide(): string { root.hide(); return "closed"; }

        function clipboard(): string {
            root.showClipboard();
            return root.open ? "open" : "closed";
        }
    }
}
