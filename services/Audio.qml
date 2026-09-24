pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// The default audio sink, kept alive in one place.
//
// PipeWire nodes only expose live properties while something tracks
// them, and a tracker declared inside a component dies with it. Having
// it here means the volume works whichever part of the shell is on
// screen, and it follows along when you switch output device.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null

    // While a drag is in flight the bar shows what was asked for.
    // Writing goes out through wpctl, which takes a few milliseconds
    // to come back, and following the node alone would stutter.
    property real pending: -1

    readonly property real volume: {
        if (root.pending >= 0) return root.pending;
        return root.ready ? sink.audio.volume : 0;
    }
    readonly property bool muted: root.ready ? sink.audio.muted : false

    // ── Setting the volume ─────────────────────────────────────
    //
    // Assigning node.audio.volume works for ALSA devices and silently
    // does nothing on Bluetooth ones: their volume lives on the
    // device's route, which this API does not reach, and the node
    // keeps echoing back the value it was handed while the speaker
    // stays where it was. wpctl writes to the right place for both,
    // so everything goes through it.
    property bool hasWpctl: false
    property real queued: -1
    // The device the queued value was meant for. It used to be read
    // when the value went out rather than when it was asked for, so
    // moving the slider and changing output in the same breath wrote
    // one device's level into the other.
    property var queuedSink: null

    Process {
        id: detect
        running: true
        command: ["sh", "-c", "command -v wpctl >/dev/null && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: root.hasWpctl = text.trim() === "yes"
        }
    }

    Process { id: writer }

    Timer {
        id: throttle
        interval: 50
        onTriggered: if (root.queued >= 0) root.flush()
    }

    // Let go of the optimistic value once the node has caught up, so
    // changes made anywhere else show up again.
    Timer {
        id: settle
        interval: 400
        onTriggered: root.pending = -1
    }

    function setVolume(v) {
        if (!root.ready) return;
        v = Math.max(0, Math.min(1, v));

        if (!root.hasWpctl) {
            // Nothing better available: right for ALSA, a no-op on
            // Bluetooth, which is still better than not moving at all.
            sink.audio.volume = v;
            return;
        }

        root.pending = v;
        root.queued = v;
        root.queuedSink = root.sink;
        settle.restart();
        if (!throttle.running) root.flush();
    }

    function flush() {
        // Never over one still on its way: wpctl talking to a
        // Bluetooth device outlasts the throttle, and the value was
        // dropped with nothing left to try again.
        if (writer.running) { throttle.restart(); return; }

        const v = root.queued;
        const node = root.queuedSink;
        root.queued = -1;
        root.queuedSink = null;
        throttle.restart();
        if (v < 0 || !node || !root.ready) return;
        writer.command = ["wpctl", "set-volume", String(node.id), v.toFixed(3)];
        writer.running = true;
    }

    // Muting does work on the node itself, Bluetooth included.
    function toggleMute() {
        if (!root.ready) return;
        sink.audio.muted = !sink.audio.muted;
    }

    // ── Output devices ─────────────────────────────────────────
    //
    // Real outputs only: isStream filters out the per-application
    // streams, which are nodes too but not somewhere you can send
    // sound.
    // Worked out and kept, not bound. As a binding it handed back a
    // new array every time any PipeWire node changed — and nodes come
    // and go whenever any program opens or closes a stream of sound,
    // not only when a speaker is plugged in. A new array rebuilds the
    // output picker's rows and re-evaluates the tracker that follows
    // them, for a list that had not changed.
    property var outputs: []

    function refreshOutputs() {
        const out = [];
        for (const n of Pipewire.nodes.values)
            if (n.isSink && !n.isStream) out.push(n);

        if (out.length === root.outputs.length) {
            let same = true;
            for (let i = 0; i < out.length; i++)
                if (out[i] !== root.outputs[i]) { same = false; break; }
            if (same) return;
        }
        root.outputs = out;
    }

    Connections {
        target: Pipewire.nodes
        function onValuesChanged() { root.refreshOutputs(); }
    }

    Component.onCompleted: root.refreshOutputs()

    function labelFor(node) {
        if (!node) return "";
        return node.nickname || node.description || node.name;
    }

    function setOutput(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    // Switching device must not carry the old one's level over.
    onSinkChanged: root.pending = -1

    // Every output has to be tracked, not just the default one: without
    // it the list shows no names and switching does nothing.
    PwObjectTracker { objects: root.outputs }
}
