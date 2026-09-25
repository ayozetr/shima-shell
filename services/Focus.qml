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

    // At least a minute each. A phase of nought seconds ends on the
    // tick it starts and chains straight into the next one, so a zero
    // here is a notification every second until somebody stops it by
    // hand — and it is a number in a file people edit.
    readonly property int focusSeconds:
        Config.number(Config.data.focusMinutes, 25, 1, 600) * 60
    readonly property int breakSeconds:
        Config.number(Config.data.breakMinutes, 5, 1, 600) * 60
    readonly property int longBreakSeconds:
        Config.number(Config.data.longBreakMinutes, 15, 1, 600) * 60
    // Zero would make the "every so many rounds" arithmetic divide by
    // it, and the long break would never come.
    readonly property int roundsBeforeLong:
        Config.number(Config.data.focusRounds, 4, 1, 100)

    readonly property bool onBreak: phase === "break" || phase === "longBreak"

    readonly property string phaseLabel: {
        switch (root.phase) {
            case "break":     return I18n.t.breakLabel;
            case "longBreak": return I18n.t.longBreak;
            default:          return I18n.t.focus;
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
    }

    function pause() {
        root.running = false;
    }

    function reset() {
        root.running = false;
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
        // Not `long`, which is a word JavaScript keeps for itself. Qt
        // 6.11 lets it through and 6.10 does not, so this file parsed
        // here and failed to parse on Ubuntu — where the whole shell
        // then refused to start, over one word in one line.
        const earned = root.roundsBeforeLong > 0
                       && root.completed % root.roundsBeforeLong === 0;
        root.beginPhase(earned ? "longBreak" : "break");
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
                root.phase = "idle";
                root.remaining = root.focusSeconds;
                return;
            }

            if (wasFocus) {
                root.finishFocus();
            } else {
                root.beginPhase("focus");
            }
        }
    }

    // ── Notification when a phase ends ─────────────────────────
    Process { id: notifier }

    function notify(wasFocus) {
        if (!(Config.data.focusNotify ?? true)) return;
        const title = wasFocus ? I18n.t.focusOver : I18n.t.breakOver;
        const body = wasFocus ? I18n.t.takeABreak : I18n.t.backToWork;
        notifier.exec(["notify-send", "-a", "Shima", "-i", "clock", title, body]);
    }

    // ── Silencing notifications while focusing ─────────────
    //
    // Whether notifications should be held back right now, and nothing
    // more than that: whoever shows them reads it.
    //
    // It used to be asked of the notification server over D-Bus, with
    // Inhibit. That is KDE's own extension and not part of the
    // specification, and on a session where Shima is the server there
    // is nobody to ask — Quickshell's server does not implement it, so
    // the call failed, the error went to a channel nothing reads, the
    // cookie stayed at zero and the switch has never done anything at
    // all. Shima shows the notifications; Shima holds them back.
    readonly property bool hushing:
        root.running && root.phase === "focus"
        && (Config.data.focusInhibit ?? true)

    // A duration change while idle should be reflected straight away.
    onFocusSecondsChanged: if (root.phase === "idle") root.remaining = root.focusSeconds;

}
