pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// KWin's night light, switched the way its own settings page does it.
//
// The D-Bus interface is read-only — it offers inhibit(), but an
// inhibition lives only as long as the connection that took it, so it
// would lift itself the moment the shell restarted. Writing the
// setting with --notify is what actually turns it on and off, and KWin
// picks the change up without a reconfigure.
Singleton {
    id: root

    property bool available: false
    property bool enabled: false      // the setting is on
    property bool running: false      // KWin's own idea of active
    property int temperature: 6500    // K, right now
    property int dayTemperature: 6500 // K, the untinted end

    // On is not the same as doing something. With a schedule the
    // setting can be on all day and only tint after sunset, so the
    // interface has to tell the two apart or it reads as broken.
    readonly property bool tinting:
        root.enabled && root.temperature < root.dayTemperature

    property bool active: false

    Process {
        id: probe
        // The day temperature is not on the bus, only in the config,
        // and it is what says whether the current one is a tint.
        command: ["sh", "-c",
            "busctl --user --json=short call org.kde.KWin "
            + "/org/kde/KWin/NightLight org.freedesktop.DBus.Properties "
            + "GetAll s org.kde.KWin.NightLight; "
            + "kreadconfig6 --file kwinrc --group NightColor "
            + "--key DayTemperature --default 6500"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }

    // KWin needs a moment to reread the file and recompute the ramp.
    Timer {
        id: settle
        interval: 350
        onTriggered: root.refresh()
    }

    function refresh() {
        if (!probe.running) probe.running = true;
    }

    function parse(text) {
        const lines = text.trim().split("\n");
        try {
            const p = JSON.parse(lines[0]).data[0];
            root.available = p.available.data;
            root.enabled = p.enabled.data;
            root.running = p.running.data;
            root.temperature = p.currentTemperature.data;
        } catch (e) {
            // KWin restarting, or a build without the interface.
            root.available = false;
            return;
        }
        const day = parseInt(lines[1], 10);
        if (!isNaN(day) && day > 0) root.dayTemperature = day;
    }

    Process { id: writer }

    function toggle() {
        if (!root.available) return;
        const next = !root.enabled;
        root.enabled = next;            // optimistic, the probe confirms
        writer.command = ["kwriteconfig6", "--notify",
            "--file", "kwinrc", "--group", "NightColor",
            "--key", "Active", "--type", "bool", next ? "true" : "false"];
        writer.running = true;
        settle.restart();
    }

    Component.onCompleted: root.refresh()
}
