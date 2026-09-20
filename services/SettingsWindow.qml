pragma Singleton
import Quickshell

// Tracks whether the settings window is open.
Singleton {
    id: root
    property bool open: false
    function toggle() { root.open = !root.open; }
    function show()   { root.open = true; }
    function hide()   { root.open = false; }
}
