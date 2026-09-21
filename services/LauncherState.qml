pragma Singleton
import Quickshell

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
        root.category = "all";
        root.query = "";
        root.open = true;
    }
    function hide()   { root.open = false; }
}
