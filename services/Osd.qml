pragma Singleton
import QtQuick
import Quickshell

// The level that flashes on the island when you change the volume with
// the keys — the on-screen display, moved into the notch.
//
// Off by default: KDE shows its own, and two at once is one too many.
// Whoever would rather have this one turns it on and, if they like,
// turns the other off. Only volume for now; brightness needs the shell
// to be told of a change it does not currently hear while idle.
Singleton {
    id: root

    readonly property bool enabled: Config.data.islandOsd ?? false

    // { kind: "volume", value: 0–1, muted }, or null.
    property var peek: null
    // Held open while the pointer rests on it, like the other peeks, and
    // held shut while the island is expanded so dragging its own slider
    // does not flash the display over the control it is on.
    property bool held: false
    property bool inhibited: false

    // The volume arrives once at startup as the sink is found, which is
    // not a change anybody made: swallowed, like the clipboard's first
    // reading, by arming a moment after the singleton is up.
    property bool armed: false
    Component.onCompleted: armTimer.start()
    Timer { id: armTimer; interval: 1200; onTriggered: root.armed = true }

    Timer { id: peekTimer; interval: 1400; onTriggered: root.peek = null }
    onHeldChanged: {
        if (root.peek === null) return;
        if (root.held) peekTimer.stop();
        else peekTimer.restart();
    }

    function show(data) {
        if (!root.enabled || !root.armed || root.inhibited) return;
        root.held = false;
        root.peek = data;
        peekTimer.restart();
    }
    function dismiss() { root.peek = null; peekTimer.stop(); }

    Connections {
        target: Audio
        function onVolumeChanged() {
            root.show({ kind: "volume", value: Audio.volume, muted: Audio.muted });
        }
        function onMutedChanged() {
            root.show({ kind: "volume", value: Audio.volume, muted: Audio.muted });
        }
    }
}
