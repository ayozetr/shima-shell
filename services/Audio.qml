pragma Singleton
import QtQuick
import Quickshell
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

    readonly property real volume: root.ready ? sink.audio.volume : 0
    readonly property bool muted: root.ready ? sink.audio.muted : false

    function setVolume(v) {
        if (!root.ready) return;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (!root.ready) return;
        sink.audio.muted = !sink.audio.muted;
    }

    // ── Output devices ─────────────────────────────────────────
    //
    // Real outputs only: isStream filters out the per-application
    // streams, which are nodes too but not somewhere you can send
    // sound.
    readonly property var outputs: {
        const out = [];
        for (const n of Pipewire.nodes.values)
            if (n.isSink && !n.isStream) out.push(n);
        return out;
    }

    function labelFor(node) {
        if (!node) return "";
        return node.nickname || node.description || node.name;
    }

    function setOutput(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    // Every output has to be tracked, not just the default one: without
    // it the list shows no names and switching does nothing.
    PwObjectTracker { objects: root.outputs }
}
