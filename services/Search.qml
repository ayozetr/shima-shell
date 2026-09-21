pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the launcher finds besides applications.
//
// KRunner's own runners are plugins loaded into it, not services, so
// they cannot be asked from outside — the only two on the bus here are
// activities and Baloo, and Baloo is switched off. So the useful ones
// are done again: a calculator, files by name, and commands.
Singleton {
    id: root

    property string query: ""
    property var files: []
    property string answer: ""      // the calculator's, empty when not one
    property string command: ""     // an executable in PATH, or empty

    // True from the keystroke that starts a search until its answer
    // arrives, so the view can hold the space instead of jumping when
    // the files turn up.
    property bool searching: false

    onQueryChanged: {
        root.answer = root.calculate(root.query);
        // Hitting the disk on every keystroke is what makes a search
        // box feel heavy, so it waits for a pause in the typing.
        if (root.query.trim().length >= 2) {
            root.searching = true;
            settle.restart();
        } else {
            settle.stop();
            root.searching = false;
            root.files = [];
            root.command = "";
        }
    }

    Timer {
        id: settle
        interval: 280
        onTriggered: root.look()
    }

    // ── Arithmetic ─────────────────────────────────────────────
    //
    // Only what a calculator would accept: digits, operators and
    // brackets. Anything else is not evaluated at all, so there is no
    // way for a search term to become code.
    function calculate(text) {
        const expr = text.trim().replace(/,/g, ".").replace(/\^/g, "**");
        if (expr === "" || !/[0-9]/.test(expr)) return "";
        if (!/^[0-9+\-*/%(). ]+$/.test(expr.replace(/\*\*/g, "*"))) return "";
        if (!/[+\-*/%]/.test(expr)) return "";     // a bare number is not a sum

        try {
            const value = Function('"use strict"; return (' + expr + ')')();
            if (typeof value !== "number" || !isFinite(value)) return "";
            // Trim the noise floating point leaves behind.
            return String(Math.round(value * 1e10) / 1e10);
        } catch (e) {
            return "";
        }
    }

    // ── Files and commands ─────────────────────────────────────
    Process {
        id: finder
        stdout: StdioCollector { onStreamFinished: root.collect(text) }
    }

    function look() {
        if (finder.running) return;
        const q = root.query.trim();
        if (q === "") return;

        finder.command = ["sh", "-c",
            // Whether the first word is something that can be run.
            "cmd=$(printf '%s' \"$1\" | cut -d' ' -f1); "
            + "command -v \"$cmd\" >/dev/null 2>&1 && printf 'cmd\\t%s\\n' \"$cmd\"; "
            // Then files, by name, under the home directory only:
            // searching the whole disk answers with the icon theme.
            + "if command -v fd >/dev/null 2>&1; then "
            + "  timeout 3 fd -i -H -E .git -E node_modules -E .cache "
            + "    --max-results 8 -- \"$1\" \"$HOME\" 2>/dev/null "
            + "    | while read -r f; do printf 'file\\t%s\\n' \"$f\"; done; "
            + "else "
            + "  timeout 3 find \"$HOME\" -maxdepth 4 -iname \"*$1*\" 2>/dev/null "
            + "    | head -8 | while read -r f; do printf 'file\\t%s\\n' \"$f\"; done; "
            + "fi",
            "shima", q];
        finder.running = true;
    }

    function collect(text) {
        const found = [];
        let cmd = "";
        for (const line of text.split("\n")) {
            const tab = line.indexOf("\t");
            if (tab < 0) continue;
            const kind = line.slice(0, tab);
            const value = line.slice(tab + 1).trim();
            if (kind === "cmd") cmd = value;
            else if (kind === "file" && value !== "") found.push(Apps.fileEntry(value));
        }
        root.command = cmd;
        root.files = found;
        root.searching = false;
    }

    // In a terminal, and left open afterwards. Running it detached was
    // the first attempt: a console program then prints into nowhere
    // and exits, so it looked like nothing happened. Graphical
    // applications are in the list above with their own icons; this
    // row is for commands, and a command wants a terminal.
    function runCommand() {
        if (root.command === "") return;
        Quickshell.execDetached(["sh", "-c",
            "term=$(kreadconfig6 --file kdeglobals --group General "
            + "  --key TerminalApplication 2>/dev/null); "
            + "[ -n \"$term\" ] || term=konsole; "
            + "case $term in "
            // --hold keeps the window up once the command is done,
            // which is the whole point of running one by hand.
            + "  konsole) exec konsole --hold -e sh -c \"$1\";; "
            + "  *) exec \"$term\" -e sh -c \"$1\";; "
            + "esac",
            "shima", root.query.trim()]);
    }

    // Klipper first, which is KDE's own clipboard and needs nothing
    // installed; the command line tools are the fallback for a session
    // without it.
    function copyAnswer() {
        if (root.answer === "") return;
        Quickshell.execDetached(["sh", "-c",
            "qdbus6 org.kde.klipper /klipper setClipboardContents \"$1\" 2>/dev/null "
            + "|| printf '%s' \"$1\" | wl-copy 2>/dev/null "
            + "|| printf '%s' \"$1\" | xclip -selection clipboard 2>/dev/null",
            "shima", root.answer]);
    }
}
