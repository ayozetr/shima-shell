pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Whether there is a newer Shima than the one running, asked only when
// you ask.
//
// Nothing here runs on a timer. A shell that phones home every few
// hours is a thing people are entitled to object to, and the answer is
// not worth it: Shima is not a browser and a release is not urgent. So
// this is a button, and until it is pressed no request is made.
//
// The version it compares against is the one the launcher put in the
// environment, which is the number written in the launcher itself —
// the one place it is written down.
Singleton {
    id: root

    readonly property string repo: "ayozetr/shima-shell"

    // idle · checking · current · newer · failed · offline
    property string state: "idle"
    property string latest: ""
    readonly property string releaseUrl:
        "https://github.com/" + root.repo + "/releases/latest"

    readonly property bool busy: root.state === "checking"
    readonly property bool knowsVersion: Paths.version !== ""

    function open() { Quickshell.execDetached(["xdg-open", root.releaseUrl]); }

    function check() {
        if (root.busy) return;
        root.latest = "";
        root.state = "checking";
        checker.running = true;
    }

    // "v0.6.0" and "0.6.0" are the same thing said twice; so are
    // trailing zeroes, which is why the parts are compared as numbers
    // and the shorter one is padded rather than losing.
    function compare(a, b) {
        const pa = String(a).replace(/^v/, "").split(".");
        const pb = String(b).replace(/^v/, "").split(".");
        const n = Math.max(pa.length, pb.length);
        for (let i = 0; i < n; i++) {
            const x = parseInt(pa[i] || "0", 10) || 0;
            const y = parseInt(pb[i] || "0", 10) || 0;
            if (x !== y) return x > y ? 1 : -1;
        }
        return 0;
    }

    Process {
        id: checker
        command: ["sh", "-c",
            "curl -fsSL --max-time 12 "
            + "-H 'Accept: application/vnd.github+json' "
            + "https://api.github.com/repos/" + root.repo + "/releases/latest"]

        stdout: StdioCollector {
            onStreamFinished: {
                // An empty body is not a parse error waiting to happen:
                // it is what curl leaves behind when it could not
                // reach anybody, and the exit code below says which.
                if (text.trim() === "") return;
                try {
                    const tag = JSON.parse(text).tag_name;
                    if (!tag) { root.state = "failed"; return; }
                    root.latest = String(tag).replace(/^v/, "");
                    if (!root.knowsVersion) { root.state = "newer"; return; }
                    root.state = root.compare(root.latest, Paths.version) > 0
                        ? "newer" : "current";
                } catch (e) {
                    root.state = "failed";
                }
            }
        }

        onExited: (code) => {
            if (root.state !== "checking") return;
            // curl says 6 for a name it could not resolve and 7 for a
            // host it could not reach; both mean the machine is not on
            // the network, which is worth saying apart from "something
            // went wrong" because there is nothing to fix.
            root.state = (code === 6 || code === 7) ? "offline" : "failed";
        }
    }
}
