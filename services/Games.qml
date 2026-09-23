pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Games that came from somewhere other than Steam.
//
// Steam names a game's window after the game — steam_app_105600 — so
// one number is enough to know what is on screen, and that is what the
// dock leans on. Heroic and Lutris do not: what runs is the game's own
// executable, under Wine or not, and its window is called whatever
// that file is called. The only thing that knows which executable
// belongs to which game is the launcher's own catalogue.
//
// Reading those catalogues is a page of Python rather than a line of
// shell — one is JSON and the other is SQLite — so it lives in
// helper/shima-games and prints a line per game.
Singleton {
    id: root

    // window class → { name, icon, source }
    property var byClass: ({})
    property int revision: 0

    // Empty when the shell was started by hand with `qs` rather than
    // through the launcher script, which is the only thing that knows
    // where the program was installed.
    readonly property string helper:
        Paths.dataDir !== "" ? Paths.dataDir + "/helper/shima-games" : ""

    Process {
        id: reader
        command: [root.helper]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.split("\n")) {
                    const parts = line.split("\t");
                    if (parts.length < 4) continue;
                    const cls = parts[0].trim();
                    if (cls === "") continue;
                    found[cls] = {
                        name: parts[1].trim(),
                        icon: parts[2].trim(),
                        source: parts[3].trim()
                    };
                }
                root.byClass = found;
                root.revision++;
            }
        }
    }

    // Read again when the launcher opens, which is where the list of
    // what is running is looked at. A game installed since the shell
    // started is in the catalogue by then. There is no telling an
    // unknown game's window from any other unknown window — that is
    // the whole difficulty — so there is nothing to react to, and
    // re-reading on every unknown class would mean re-reading on
    // every window nobody has claimed.
    function refresh() {
        if (root.helper === "" || reader.running) return;
        reader.running = true;
    }

    Component.onCompleted: root.refresh()

    function entryFor(cls) {
        const game = root.byClass[cls];
        if (!game) return null;
        return {
            id: "game:" + cls,
            name: game.name,
            icon: game.icon,
            comment: "",
            isGame: true,
            windowClass: cls,
            source: game.source
        };
    }
}
