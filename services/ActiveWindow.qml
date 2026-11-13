pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which screens have a window covering them, so the island can step
// aside for one that is maximised or fullscreen over it.
//
// KWin does not speak the wlr foreign-toplevel protocol Quickshell
// reads, and its own bus has no "is a window covering this screen" call.
// So the helper runs a one-shot KWin script that reads the window list —
// the one place the maximised, fullscreen and minimised state lives —
// and answers which outputs are covered.
//
// Two things fall out of asking KWin the window list rather than, as
// before, kdotool for the active window's geometry. A maximised window
// sitting behind whatever is focused now counts, where before only the
// focused one did — a browser left maximised on one screen while you
// type on another kept the island showing over it. And the answer comes
// back as output names straight from KWin, so no screen geometry is
// compared here any more, which is what used to go wrong on a scaled
// display.
Singleton {
    id: root

    // Polling runs only while the feature that needs it is on, so an
    // untouched install never runs the helper on a timer.
    readonly property bool wanted: (Config.data.islandAutoHide ?? false)
                                && (Config.data.islandAutoHideMaximized ?? false)

    // Empty when started by hand with `qs`: only the launcher script
    // knows where the helper was installed. Same as the other helpers.
    readonly property string helper:
        Paths.dataDir !== "" ? Paths.dataDir + "/helper/shima-window-cover" : ""

    // Output name → true for every screen that has a maximised or
    // fullscreen window (not minimised) on it.
    property var covered: ({})

    function coversScreen(name) { return root.covered[name] === true; }

    Timer {
        running: root.wanted && root.helper !== ""
        interval: 1200
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }

    Process {
        id: probe
        command: root.helper !== "" ? ["sh", root.helper] : ["true"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        // The helper answers {} on any trouble and exits 0, so a non-zero
        // exit is the process itself failing: treat it as nothing covered
        // rather than leave a stale answer holding the island hidden.
        onExited: (code) => { if (code !== 0) root.covered = ({}); }
    }

    function parse(text) {
        try {
            const o = JSON.parse(text);
            root.covered = (o && typeof o === "object") ? o : ({});
        } catch (e) {
            root.covered = ({});
        }
    }
}
