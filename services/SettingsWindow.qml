pragma Singleton
import QtQuick
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

    // And whether a dropdown inside the window is unfolded. The
    // window closes on Escape, and Qt hands shortcuts out ahead of key
    // events, so that shortcut used to take the whole window while a
    // list was open -- the first press should fold the list.
    //
    // Said here rather than claimed with Keys.onShortcutOverride in
    // the list itself, which is the tidier idea and does not work:
    // tried on 27 September and Escape still closed the window. A flag
    // the shortcut can read is plain and does.
    property bool listOpen: false

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

    // The marker is only ever removed by the shell that wrote it, and
    // that is not good enough: if the shell dies with the capture box
    // open -- or the window goes without it noticing -- the file stays
    // and the helper keeps our two keys out of KDE's hands **for the
    // rest of the session**, with nothing on screen to explain why
    // Meta stopped opening the launcher.
    //
    // Two halves, and neither is enough alone. A marker found at
    // startup is a leftover by definition, since nothing can be
    // capturing before the window exists.
    Process {
        running: true
        command: ["sh", "-c", 'rm -f "$1"', "shima",
                  Paths.runtimeDir + "/capturing"]
    }

    // And while a capture really is up, the shell says so again every
    // twenty seconds. That is what lets the helper distinguish a
    // marker that means it from one nobody cleaned up: the first keeps
    // being touched, the second stops. Without this the helper would
    // have to guess a length for how long somebody may sit with the
    // box open, and be wrong about anybody slower than the guess.
    Timer {
        running: root.capturing
        interval: 20000
        repeat: true
        onTriggered: beat.exec(["sh", "-c",
            '[ -e "$1" ] && : > "$1"', "shima",
            Paths.runtimeDir + "/capturing"])
    }

    Process { id: beat }
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
