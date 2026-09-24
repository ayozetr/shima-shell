pragma Singleton
import Quickshell
import Quickshell.Io

// Tracks whether the settings window is open.
Singleton {
    id: root
    property bool open: false

    // True while the settings window is waiting for you to press the
    // combination you want. The shortcuts are registered with KDE, so
    // they fire whatever has the focus — pressing Meta+V to set it as
    // the clipboard key also opened the clipboard. The keys still
    // reach the box that is listening; what stops is us acting on
    // them.
    property bool capturing: false

    // Said out loud in the runtime directory, because the one that has
    // to know is the shortcut helper — a process of its own, which
    // takes our keys out of KDE's hands while this is up so that they
    // can be typed into the box asking for them. A file rather than a
    // message because the helper already watches files and owns no
    // channel to be spoken to.
    onCapturingChanged: {
        marker.exec(["sh", "-c",
            root.capturing
                ? 'mkdir -p "$(dirname "$1")" && : > "$1"'
                : 'rm -f "$1"',
            "shima", Paths.runtimeDir + "/capturing"]);
    }

    Process { id: marker }
    function toggle() { root.open = !root.open; }
    function show()   { root.open = true; }
    function hide()   { root.open = false; }

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
}
