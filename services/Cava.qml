pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Audio visualiser. On Windows this would mean capturing system audio
// with WASAPI and running the FFT by hand; here cava already does it
// off the PipeWire monitor, so we just consume its bands.
Singleton {
    id: root

    property int bars: 5
    property var levels: [0, 0, 0, 0, 0]   // 0.0 – 1.0
    property bool active: false

    readonly property string configPath: "/tmp/shima-cava.conf"

    // Only burn CPU while something is actually playing.
    function setActive(on) {
        if (on === root.active) return;
        root.active = on;
        if (on) writeConfig.running = true;
        else {
            cava.running = false;
            root.levels = new Array(root.bars).fill(0);
        }
    }

    Process {
        id: writeConfig
        command: ["sh", "-c",
            "printf '[general]\\nframerate=60\\nbars=" + root.bars + "\\nautosens=1\\n"
            + "[input]\\nmethod=pulse\\nsource=auto\\n"
            + "[output]\\nmethod=raw\\ndata_format=ascii\\nascii_max_range=1000\\n"
            + "channels=mono\\n[smoothing]\\nnoise_reduction=35\\n' > " + root.configPath]
        onExited: (code) => { if (code === 0) cava.running = true; }
    }

    Process {
        id: cava
        command: ["cava", "-p", root.configPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (!line) return;
                const parts = line.split(";").filter(s => s.length > 0);
                if (parts.length < root.bars) return;
                const out = [];
                for (let i = 0; i < root.bars; i++)
                    out.push(Math.min(1, parseInt(parts[i], 10) / 1000));
                root.levels = out;
            }
        }
    }

    Component.onDestruction: cava.running = false
}
