pragma Singleton
import Quickshell
import Quickshell.Io

// Tracks whether the settings window is open.
Singleton {
    id: root
    property bool open: false
    function toggle() { root.open = !root.open; }
    function show()   { root.open = true; }
    function hide()   { root.open = false; }
}

    // So it can be opened from outside the shell — from the entry in
    // the application menu, which is the only way in for somebody who
    // has turned the dock off and does not know the launcher has a
    // button for it.
    IpcHandler {
        target: "settings"

        function open(): string { root.show(); return "open"; }
        function close(): string { root.hide(); return "closed"; }
        function toggle(): string {
            root.toggle();
            return root.open ? "open" : "closed";
        }
    }
