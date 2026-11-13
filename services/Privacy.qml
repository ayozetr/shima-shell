pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Whether the microphone is being recorded right now, for a dot on the
// island the way a phone warns you.
//
// Driven by events, not a poll: `pactl subscribe` wakes a check only
// when a recording stream comes or goes, and the check reads `pw-dump`
// to tell a real microphone capture from an app merely monitoring what
// is playing — a visualiser, a recorder — which carries `stream.monitor`
// and must not light the dot.
//
// Only the microphone for now: a camera and a screencast are muddier to
// tell from a remote-desktop server or the compositor's own screen
// capture, and are left for later.
Singleton {
    id: root

    readonly property bool enabled: Config.data.privacyMic ?? true
    property bool micActive: false

    Process {
        id: sub
        running: root.enabled
        command: ["pactl", "subscribe"]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.indexOf("source-output") !== -1) beat.restart();
            }
        }
    }

    // One check per burst of events, a moment after, so the node is
    // settled by the time pw-dump is read. If a dump is still running
    // when the timer fires — an event arrived mid-read — wait and try
    // again rather than drop it, or the last change is missed until
    // the next event happens to come along.
    Timer {
        id: beat
        interval: 200
        onTriggered: { if (dump.running) beat.restart(); else dump.running = true; }
    }

    Process {
        id: dump
        command: ["pw-dump"]
        stdout: StdioCollector {
            onStreamFinished: {
                let on = false;
                try {
                    const nodes = JSON.parse(text);
                    for (const o of nodes) {
                        if (o.type !== "PipeWire:Interface:Node") continue;
                        const p = (o.info && o.info.props) || {};
                        if (p["media.class"] === "Stream/Input/Audio"
                            && o.info.state === "running"
                            && p["stream.monitor"] !== "true"
                            && p["stream.monitor"] !== true) {
                            on = true;
                            break;
                        }
                    }
                } catch (e) {}
                root.micActive = on;
            }
        }
    }

    onEnabledChanged: {
        if (root.enabled) beat.restart();
        else root.micActive = false;
    }
    Component.onCompleted: if (root.enabled) beat.restart();
}
