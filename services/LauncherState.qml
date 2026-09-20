pragma Singleton
import Quickshell

// Whether the launcher is open and which category it is showing.
Singleton {
    id: root
    property bool open: false
    property string category: "all"
    property string query: ""

    function toggle() { root.open ? root.hide() : root.show(); }
    function show()   { root.category = "all"; root.query = ""; root.open = true; }
    function hide()   { root.open = false; }
}
