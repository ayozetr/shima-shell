pragma Singleton
import Quickshell
import Quickshell.Io

// Whether the launcher is open and which category it is showing.
Singleton {
    id: root
    property bool open: false
    property string category: "all"
    property string query: ""

    function toggle() { root.open ? root.hide() : root.show(); }
    // Rereading KDE's menu on open is what makes an entry you edited
    // there show up here without restarting anything.
    function show() {
        Apps.readMenu();
        Apps.refreshFavorites();
        Apps.readFrequent();
        // Favourites first, which is the point of having them — unless
        // there are none yet, and an empty panel would be a poor
        // greeting.
        root.category = Apps.favorites.length > 0 ? "favorites" : "all";
        root.query = "";
        root.open = true;
    }
    function hide()   { root.open = false; }

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
    }
}
