pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The power profile, and keeping the machine awake.
//
// Profiles come from power-profiles-daemon over the system bus, which
// is the same place KDE's own applet reads and writes them, and it
// allows the change without asking for a password.
Singleton {
    id: root

    readonly property string service: "net.hadess.PowerProfiles"
    readonly property string path: "/net/hadess/PowerProfiles"

    property string profile: ""       // power-saver · balanced · performance
    property var profiles: []
    readonly property bool available: root.profiles.length > 0

    property bool active: false       // polled while the control centre is up

    Process {
        id: probe
        command: ["sh", "-c",
            "S=net.hadess.PowerProfiles; P=/net/hadess/PowerProfiles; "
            + "busctl --system --json=short get-property $S $P $S ActiveProfile "
            + "  2>/dev/null; "
            + "busctl --system --json=short get-property $S $P $S Profiles "
            + "  2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Timer {
        interval: 4000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }

    function refresh() { if (!probe.running) probe.running = true; }

    function parse(text) {
        const lines = text.trim().split("\n");
        if (lines.length < 1) return;

        try {
            root.profile = JSON.parse(lines[0]).data;
        } catch (e) { /* daemon not there */ }

        if (lines.length < 2) return;
        try {
            // The list comes as an array of dictionaries; only the
            // name of each one matters here.
            const found = [];
            for (const entry of JSON.parse(lines[1]).data) {
                const name = entry.Profile ? entry.Profile.data : undefined;
                if (name) found.push(name);
            }
            if (found.length > 0) root.profiles = found;
        } catch (e) { /* leave whatever was there */ }
    }

    Process { id: writer }

    function setProfile(name) {
        if (name === root.profile) return;
        root.profile = name;          // optimistic; the poll confirms
        writer.command = ["busctl", "--system", "set-property",
                          root.service, root.path, root.service,
                          "ActiveProfile", "s", name];
        writer.running = true;
    }

    // ── Keeping it awake ───────────────────────────────────────
    //
    // Not a setting but an inhibition, which lives exactly as long as
    // whoever holds it. So it is held by a process of our own: while
    // it runs the machine will not idle or sleep, and stopping it
    // lets go. It dies with the shell, which is the right thing —
    // nothing should keep a machine awake after the shell is gone.
    property bool keepAwake: false

    Process {
        id: inhibitor
        running: root.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=Shima",
                  "--why=Keep awake", "--mode=block",
                  "sleep", "infinity"]
    }
}
