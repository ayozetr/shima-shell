pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Where the active window sits, so the island can step aside for one
// that is maximised or fullscreen over it.
//
// KWin does not speak the wlr foreign-toplevel protocol Quickshell
// reads, so there is nothing to subscribe to: this asks kdotool — which
// goes through KWin's own scripting — for the active window's geometry,
// and only while something actually wants it. A window the size of a
// screen, sitting at its top, is covering the island there; which
// screen is which is why the geometry is compared and not just a flag.
Singleton {
    id: root

    // Polling runs only while the feature that needs it is on, so an
    // untouched install never spawns kdotool on a timer.
    readonly property bool wanted: (Config.data.islandAutoHide ?? false)
                                && (Config.data.islandAutoHideMaximized ?? false)

    // { x, y, w, h } of the active window in layout coordinates, or
    // null when there is none (the desktop has the focus) or kdotool is
    // not installed.
    property var rect: null

    Timer {
        running: root.wanted
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }

    Process {
        id: probe
        command: ["kdotool", "getactivewindow", "getwindowgeometry"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
        onExited: (code) => { if (code !== 0) root.rect = null; }
    }

    function parse(text) {
        // Position: X,Y  /  Geometry: WxH — both may carry a fraction,
        // since a scaled screen rarely lands on a whole pixel.
        const pos = text.match(/Position:\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)/);
        const geo = text.match(/Geometry:\s*([\d.]+)\s*x\s*([\d.]+)/);
        if (!pos || !geo) { root.rect = null; return; }
        root.rect = { x: parseFloat(pos[1]), y: parseFloat(pos[2]),
                      w: parseFloat(geo[1]), h: parseFloat(geo[2]) };
    }

    // Does the active window cover the top centre of this screen, where
    // the island lives? A maximised or fullscreen window does; a window
    // on another screen, or a small one, does not.
    function coversTop(sx, sy, sw, sh) {
        const r = root.rect;
        if (!r) return false;
        const px = sx + sw / 2;
        const py = sy + 3;
        return px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h;
    }
}
