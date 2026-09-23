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
    // brackets. It used to hand the expression to Function(), behind a
    // regular expression that let nothing else through — safe as it
    // stood, and one relaxed rule away from not being. Nobody edits a
    // pattern like that thinking about what it now admits, so the sums
    // are read here instead and there is no evaluator to reach.
    function calculate(text) {
        const expr = text.trim().replace(/,/g, ".");
        if (expr === "" || !/[0-9]/.test(expr)) return "";
        if (!/[+\-*/%^]/.test(expr)) return "";   // a bare number is not a sum

        let value;
        try { value = root.evaluate(expr); }
        catch (e) { return ""; }
        if (typeof value !== "number" || !isFinite(value)) return "";

        // Trim the noise floating point leaves behind — but only where
        // there is room for it: multiplying a large result by 1e10
        // overflows, and 2^1000 came out as "Infinity".
        if (Math.abs(value) >= 1e12) return String(value);
        return String(Math.round(value * 1e10) / 1e10);
    }

    // Sums, products, powers and brackets, in that order of binding.
    // Anything it does not understand throws, and an expression that
    // does not read to the end is not half a sum: it is not one.
    function evaluate(expr) {
        let i = 0;

        function fail() { throw new Error("not arithmetic"); }
        function space() { while (expr[i] === " ") i++; }
        function digits() { while (expr[i] >= "0" && expr[i] <= "9") i++; }

        function number() {
            const start = i;
            digits();
            if (expr[i] === ".") { i++; digits(); }
            const text = expr.slice(start, i);
            if (text === "" || text === ".") fail();
            return parseFloat(text);
        }

        function primary() {
            space();
            if (expr[i] === "(") {
                i++;
                const value = sum();
                space();
                if (expr[i] !== ")") fail();
                i++;
                return value;
            }
            return number();
        }

        // Right to left, so 2^3^2 is 512 and not 64.
        function power() {
            const base = primary();
            space();
            if (expr[i] === "^") { i++; return Math.pow(base, unary()); }
            if (expr[i] === "*" && expr[i + 1] === "*") {
                i += 2;
                return Math.pow(base, unary());
            }
            return base;
        }

        // Below the power, so -2^2 is -4, the way it is written down.
        function unary() {
            space();
            if (expr[i] === "-") { i++; return -unary(); }
            if (expr[i] === "+") { i++; return unary(); }
            return power();
        }

        function product() {
            let value = unary();
            for (;;) {
                space();
                if (expr[i] === "*" && expr[i + 1] === "*") return value;
                if (expr[i] === "*") { i++; value *= unary(); }
                else if (expr[i] === "/") { i++; value /= unary(); }
                else if (expr[i] === "%") { i++; value %= unary(); }
                else return value;
            }
        }

        function sum() {
            let value = product();
            for (;;) {
                space();
                if (expr[i] === "+") { i++; value += product(); }
                else if (expr[i] === "-") { i++; value -= product(); }
                else return value;
            }
        }

        const value = sum();
        space();
        if (i !== expr.length) fail();
        return value;
    }

    // ── Files and commands ─────────────────────────────────────
    Process {
        id: finder
        stdout: StdioCollector { onStreamFinished: root.collect(text) }
    }

    // The query the running search was launched with. An answer can
    // arrive long after the keystroke that asked for it, and by then
    // the query has usually moved on.
    property string inFlight: ""

    function look() {
        const q = root.query.trim();
        if (q === "") return;
        // One search at a time; the one already out will start this
        // one on its way back, once it sees the query changed.
        if (finder.running) return;
        root.inFlight = q;

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
        const asked = root.inFlight;
        root.inFlight = "";
        if (asked !== root.query.trim()) {
            // Whoever asked for this has kept typing. Answering now
            // would put a list of one query under the text of another.
            if (root.query.trim().length >= 2) again.restart();
            else root.searching = false;
            return;
        }

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

    // Through a timer rather than called from collect(), so it does
    // not rest on the process having been marked as finished by the
    // time its output arrives: if it had not, look() would see it
    // still running, return, and leave the spinner up for good.
    Timer {
        id: again
        interval: 0
        onTriggered: root.look()
    }

    // In a terminal, and left open afterwards. Running it detached was
    // the first attempt: a console program then prints into nowhere
    // and exits, so it looked like nothing happened. Graphical
    // applications are in the list above with their own icons; this
    // row is for commands, and a command wants a terminal.
    //
    // Which terminal is no longer TerminalApplication on its own.
    // Plasma's own chooser writes TerminalService — the name of a
    // desktop file — and leaves the old key empty, so reading only
    // that one handed every session Konsole no matter what it had
    // chosen. And --hold is Konsole's spelling of "stay open"; the
    // rest each have their own or none at all, so the wait goes in the
    // command, where every terminal keeps it.
    function runCommand() {
        if (root.command === "") return;
        Quickshell.execDetached(["sh", "-c",
            "svc=$(kreadconfig6 --file kdeglobals --group General "
            + "  --key TerminalService 2>/dev/null); "
            + "case $svc in \"\") ;; *.desktop) ;; *) svc=$svc.desktop;; esac; "
            + "term=; "
            + "if [ -n \"$svc\" ]; then "
            + "  IFS=:; "
            + "  for d in ${XDG_DATA_HOME:-$HOME/.local/share}:"
            + "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do "
            + "    [ -f \"$d/applications/$svc\" ] || continue; "
            + "    term=$(sed -n 's/^Exec=//p' \"$d/applications/$svc\" "
            + "      | head -n1 | cut -d' ' -f1); "
            + "    break; "
            + "  done; "
            + "  unset IFS; "
            + "fi; "
            + "[ -n \"$term\" ] || term=$(kreadconfig6 --file kdeglobals "
            + "  --group General --key TerminalApplication 2>/dev/null); "
            + "[ -n \"$term\" ] || term=konsole; "
            + "SHIMA_DONE=$2; export SHIMA_DONE; "
            + "run=\"$1\"'; printf \"\\n%s \" \"$SHIMA_DONE\"; read _'; "
            // The GNOME family reads everything after -- as the
            // command; everyone else spells that -e.
            + "case ${term##*/} in "
            + "  gnome-terminal|tilix) exec \"$term\" -- sh -c \"$run\";; "
            + "  *) exec \"$term\" -e sh -c \"$run\";; "
            + "esac",
            "shima", root.query.trim(), I18n.t.commandDone]);
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
