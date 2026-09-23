pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and network, read from /proc. Nothing else is needed:
// on Linux this is a text file, not a service query.
Singleton {
    id: root

    property real cpu: 0        // 0–1
    property real memUsed: 0    // GiB
    property real memTotal: 0   // GiB
    property real memRatio: 0   // 0–1
    property real rxRate: 0     // KiB/s
    property real txRate: 0     // KiB/s
    property int  cpuTemp: 0    // °C, 0 when unknown

    property bool active: false

    // Previous snapshot, to diff between readings.
    property var lastCpu: null
    property var lastNet: null
    property real lastNetTime: 0

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process {
        id: probe
        command: ["sh", "-c",
            "head -1 /proc/stat; "
            + "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; "
            // Only the interfaces that are a piece of hardware. Every
            // one of them used to be added up, and there are more of
            // those than it looks: loopback, a Docker bridge, the
            // bridges of each container network, a VPN, one per
            // virtual machine. Copying a file to yourself was counted
            // — twice, once going and once coming — as if it had gone
            // out over the wire, and a VPN counts its own traffic on
            // top of the card that actually carried it. What has a
            // device behind it in sysfs is a card; the rest is not.
            + "rx=0; tx=0; "
            + "for n in /sys/class/net/*; do "
            + "  [ -e \"$n/device\" ] || continue; "
            + "  read -r r < \"$n/statistics/rx_bytes\" 2>/dev/null || continue; "
            + "  read -r t < \"$n/statistics/tx_bytes\" 2>/dev/null || continue; "
            + "  rx=$((rx + r)); tx=$((tx + t)); "
            + "done; "
            + "printf 'NET %s %s\\n' \"$rx\" \"$tx\"; "
            // The hwmon number shifts between boots, so the sensor is
            // found by name rather than by a fixed path.
            + "for d in /sys/class/hwmon/hwmon*; do "
            + "  case \"$(cat $d/name 2>/dev/null)\" in "
            + "    k10temp|coretemp|zenpower) "
            + "      echo \"CPUTEMP $(cat $d/temp1_input 2>/dev/null)\"; break;; "
            + "  esac; done; "
            ]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(text) {
        const now = Date.now() / 1000;
        let memTotalKb = 0, memAvailKb = 0;

        for (const line of text.split("\n")) {
            if (line.startsWith("cpu ")) {
                const f = line.split(/\s+/).slice(1).map(Number);
                // user+nice+system+idle+iowait+irq+softirq+steal
                const idle = f[3] + f[4];
                const total = f.slice(0, 8).reduce((a, b) => a + b, 0);
                if (root.lastCpu) {
                    const dTotal = total - root.lastCpu.total;
                    const dIdle = idle - root.lastCpu.idle;
                    if (dTotal > 0) root.cpu = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
                }
                root.lastCpu = { total: total, idle: idle };
            } else if (line.startsWith("MemTotal:")) {
                memTotalKb = parseInt(line.split(/\s+/)[1], 10);
            } else if (line.startsWith("MemAvailable:")) {
                memAvailKb = parseInt(line.split(/\s+/)[1], 10);
            } else if (line.startsWith("CPUTEMP ")) {
                const v = parseInt(line.split(/\s+/)[1], 10);
                if (!isNaN(v)) root.cpuTemp = Math.round(v / 1000);
            } else if (line.startsWith("NET ")) {
                const p = line.split(/\s+/);
                const rx = parseInt(p[1], 10), tx = parseInt(p[2], 10);
                if (root.lastNet && root.lastNetTime) {
                    const dt = now - root.lastNetTime;
                    if (dt > 0) {
                        root.rxRate = Math.max(0, (rx - root.lastNet.rx) / dt / 1024);
                        root.txRate = Math.max(0, (tx - root.lastNet.tx) / dt / 1024);
                    }
                }
                root.lastNet = { rx: rx, tx: tx };
                root.lastNetTime = now;
            }
        }

        if (memTotalKb > 0) {
            root.memTotal = memTotalKb / 1048576;
            root.memUsed = (memTotalKb - memAvailKb) / 1048576;
            root.memRatio = root.memUsed / root.memTotal;
        }
    }

    function rate(kib) {
        if (kib >= 1024) return (kib / 1024).toFixed(1) + " MB/s";
        return Math.round(kib) + " KB/s";
    }
}
