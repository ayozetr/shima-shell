pragma Singleton
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
        Apps.readMenu();
        Apps.refreshFavorites();
        Apps.readRecent();
        Games.refresh();
        // Favourites first, which is the point of having them — unless
        // there are none yet, and an empty panel would be a poor
        // greeting.
        root.category = Apps.favorites.length > 0 ? "favorites" : "all";
        root.query = "";
        root.open = true;
    }
    function hide()   { root.open = false; root.focusScreen = ""; }

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
