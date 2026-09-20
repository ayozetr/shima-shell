pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The pomodoro behind the island's calendar mode.
//
// Beyond counting down it can silence notifications while you work and
// chain a break afterwards, which is what makes it a focus session
// rather than a stopwatch.
Singleton {
    id: root

    // idle · focus · break · longBreak
    property string phase: "idle"
    property bool running: false
    property int remaining: root.focusSeconds
    property int completed: 0        // finished focus rounds

    readonly property int focusSeconds:     (Config.data.focusMinutes ?? 25) * 60
    readonly property int breakSeconds:     (Config.data.breakMinutes ?? 5) * 60
    readonly property int longBreakSeconds: (Config.data.longBreakMinutes ?? 15) * 60
    readonly property int roundsBeforeLong: Config.data.focusRounds ?? 4

    readonly property bool onBreak: phase === "break" || phase === "longBreak"

    readonly property string phaseLabel: {
        switch (root.phase) {
            case "focus":     return "ENFOQUE";
            case "break":     return "DESCANSO";
            case "longBreak": return "DESCANSO LARGO";
            default:          return "ENFOQUE";
        }
    }

    readonly property string timeText: {
        const m = Math.floor(root.remaining / 60);
        const s = root.remaining % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // ── Controls ───────────────────────────────────────────────
    function toggle() { root.running ? root.pause() : root.start(); }

    function start() {
        if (root.phase === "idle") root.beginPhase("focus");
        root.running = true;
        if (root.phase === "focus") root.inhibit();
    }

    function pause() {
        root.running = false;
        root.release();
    }

    function reset() {
        root.running = false;
        root.release();
        root.phase = "idle";
        root.completed = 0;
        root.remaining = root.focusSeconds;
    }

    // Jump to the next phase by hand, without waiting it out.
    function skip() {
        if (root.phase === "focus") root.finishFocus();
        else root.beginPhase("focus");
    }

    function beginPhase(next) {
        root.phase = next;
        root.remaining = next === "focus" ? root.focusSeconds
                       : next === "break" ? root.breakSeconds
                                          : root.longBreakSeconds;
    }

    function finishFocus() {
        root.completed++;
        root.release();
        const long = root.roundsBeforeLong > 0
                     && root.completed % root.roundsBeforeLong === 0;
        root.beginPhase(long ? "longBreak" : "break");
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: {
            if (root.remaining > 0) { root.remaining--; return; }

            const wasFocus = root.phase === "focus";
            root.notify(wasFocus);

            if (!(Config.data.focusChain ?? true)) {
                root.running = false;
                root.release();
                root.phase = "idle";
                root.remaining = root.focusSeconds;
                return;
            }

            if (wasFocus) {
                root.finishFocus();
            } else {
                root.beginPhase("focus");
                root.inhibit();
            }
        }
    }

    // ── Notification when a phase ends ─────────────────────────
    Process { id: notifier }

    function notify(wasFocus) {
        if (!(Config.data.focusNotify ?? true)) return;
        const title = wasFocus ? "Sesión terminada" : "Descanso terminado";
        const body = wasFocus
            ? "Tómate un descanso."
            : "De vuelta al trabajo.";
        notifier.exec(["notify-send", "-a", "Shima", "-i", "clock", title, body]);
    }

    // ── Silencing notifications while focusing ─────────────────
    //
    // An inhibition with a cookie, not a change to your Do Not Disturb
    // setting: it is temporary and disappears with the session.
    property int cookie: 0

    Process {
        id: inhibitProc
        stdout: StdioCollector {
            onStreamFinished: {
                // gdbus answers "(uint32 7,)"
                const m = text.match(/(\d+)/);
                if (m) root.cookie = parseInt(m[1], 10);
            }
        }
    }

    Process { id: uninhibitProc }

    function inhibit() {
        if (!(Config.data.focusInhibit ?? true) || root.cookie !== 0) return;
        inhibitProc.exec(["gdbus", "call", "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.Inhibit",
            "shima", "Sesión de enfoque", "{}"]);
    }

    function release() {
        if (root.cookie === 0) return;
        uninhibitProc.exec(["gdbus", "call", "--session",
            "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications",
            "--method", "org.freedesktop.Notifications.UnInhibit",
            String(root.cookie)]);
        root.cookie = 0;
    }

    // A duration change while idle should be reflected straight away.
    onFocusSecondsChanged: if (root.phase === "idle") root.remaining = root.focusSeconds;

    Component.onDestruction: root.release()
}
