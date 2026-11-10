pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// The earbud battery an open case broadcasts, held out on the island
// for a few seconds.
//
// Earbuds that speak Google Fast Pair announce the battery of each bud
// and of the case over BLE while they sit in an open case, and stop
// once they are in your ears — so this is the one moment the three
// figures can be read at all. Catching it needs an LE scan running,
// which the helper does and nothing else here does; it runs only while
// this is switched on, off by default because a background scan is not
// free. See helper/shima-fastpair.
Singleton {
    id: root

    readonly property bool enabled: Config.data.fastPairPeek ?? false

    // Empty when started by hand with `qs`: only the launcher script
    // knows where the helper was installed. Same as Games and Windows.
    readonly property string helper:
        Paths.dataDir !== "" ? Paths.dataDir + "/helper/shima-fastpair" : ""

    // What is held out right now: { name, left, right, caseLevel }, or
    // null. Each level is 0–100, or -1 where the device did not report
    // it (a case with nothing in one side, say). The island reads this.
    property var peek: null
    // Held open while the pointer is on it, the way the other peeks are.
    property bool peekHeld: false

    Timer {
        id: peekTimer
        interval: 7000
        onTriggered: root.peek = null
    }

    onPeekHeldChanged: {
        if (root.peek === null) return;
        if (root.peekHeld) peekTimer.stop();
        else peekTimer.restart();
    }

    function dismiss() { root.peek = null; peekTimer.stop(); }

    // Only something this machine is paired with gets to take the
    // island: a stranger's earbuds opening across the room are not
    // yours to announce. Matched on the name BlueZ resolved, because
    // the Fast Pair advertisement rides a random address and not the
    // paired one, so the address alone would never line up.
    function mine(name) {
        const n = String(name).trim().toLowerCase();
        if (n === "") return false;
        const devs = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (const d of devs) {
            if (!d || !(d.paired || d.bonded)) continue;
            const dn = String(d.name || d.deviceName || "").trim().toLowerCase();
            if (dn === n) return true;
        }
        return false;
    }

    function show(name, left, right, caseLevel) {
        if (!root.mine(name)) return;
        root.peekHeld = false;
        root.peek = { name: name, left: left, right: right, caseLevel: caseLevel };
        peekTimer.restart();
    }

    // The helper streams one tab-separated line per opened case:
    // addr, name, left, right, case, rssi. It keeps the scan down when
    // this process is gone, so nothing is left scanning once switched
    // off.
    Process {
        running: root.enabled && root.helper !== ""
        command: [root.helper]
        stdout: SplitParser {
            onRead: (line) => {
                const p = line.split("\t");
                if (p.length < 6) return;
                root.show(p[1], parseInt(p[2]), parseInt(p[3]), parseInt(p[4]));
            }
        }
    }
}
