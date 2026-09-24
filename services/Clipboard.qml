pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The clipboard, and what was in it before.
//
// Plasma's history lives inside its panel applet, so putting the
// panels away — which is what Shima is for — takes the history and
// Meta+V with it, and leaves nothing in their place. This is that
// place, images included, because the one it replaces had them.
//
// Nothing outlives the session. Text is held here and nowhere else;
// an image cannot be, since it has to be a file for anything to draw
// it, so it goes to the runtime directory, which is memory with a
// path — a tmpfs the system empties when the session ends. Neither
// ever reaches the disk. A clipboard holds a password often enough
// that leaving a trail of them behind would cost more than the
// convenience is worth.
Singleton {
    id: root

    readonly property bool wanted: Config.data.clipboardHistory ?? true
    readonly property bool wantImages: Config.data.clipboardImages ?? true
    readonly property int limit: 50

    // Bigger than this and it is not a clipboard entry, it is a file.
    readonly property int imageLimit: 8 * 1024 * 1024

    readonly property string clipDir: Paths.runtimeDir + "/clips"

    // Newest first. Each one is { kind: "text", text } or
    // { kind: "image", path, mark }, where the mark is what tells two
    // copies of the same picture apart from two different ones.
    property var entries: []

    // Whether wl-clipboard is installed. Without it there is no way to
    // be told about a change on Wayland at all — the protocol offers
    // nothing to poll.
    property bool available: false
    property bool probed: false

    Component.onCompleted: sweep.running = true

    // Anything left by a shell that did not get to clean up after
    // itself. Nothing in here is meant to outlive the process.
    // Anything left by a shell that did not get to clean up after
    // itself, which is two things: the files, and the watchers.
    //
    // A watcher does not always die with what started it. The pipe
    // takes care of the shell going away, but a hot reload — and a
    // package update is one — kills the wrapper outright, and what it
    // was watching is handed to init and goes on reading the clipboard
    // and writing files. Every leftover writes its own copy of every
    // picture, which is how one image came to leave three files.
    //
    // The pattern is written with a bracket so it cannot match the
    // command line it is written in, or this would take itself down
    // with them.
    Process {
        id: sweep
        command: ["sh", "-c",
            'pkill -f "shima-clip[-]watch" 2>/dev/null; '
            + 'rm -rf -- "$1" && mkdir -p "$1"', "shima", root.clipDir]
        onExited: detect.running = true
    }

    Process {
        id: detect
        command: ["sh", "-c", "command -v wl-paste >/dev/null && echo yes"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.trim() === "yes";
                root.probed = true;
            }
        }
    }

    // Two watchers and not one, and it took finding out the hard
    // way. wl-paste --watch hands the command whatever the clipboard
    // is offering, on standard input; asked for one type it hands
    // that type, and asked for nothing in particular it picks. A
    // picture cannot be read back by calling wl-paste again from
    // inside the callback — tried, and the second read comes back
    // empty every time, while the same call outside works — so each
    // watcher asks for the type it wants and reads what it is given.
    //
    // The separator goes after each record rather than before, so a
    // reader sees whole ones and never the front half of one.
    // Held open through standard input, and not started directly.
    //
    // wl-paste --watch does not die with whatever started it: kill the
    // shell and the watcher is handed to init, still reading the
    // clipboard and still writing files into the runtime directory —
    // and the next shell starts its own, so every restart leaves
    // another pair behind and every picture copied afterwards is
    // written once per leftover. Seen, counted, and it is why three
    // files appeared for one image.
    //
    // The same answer as the sleep inhibitor: while the shell lives
    // the pipe stays open and the read blocks; the moment it dies —
    // cleanly, crashed or killed outright — the pipe closes, the read
    // returns and the watcher is taken down with it.
    // A word of our own, carried in the command line of both the
    // wrapper and the watcher it starts, so that what is left over
    // from a previous shell can be told from anything else on the
    // machine and taken down. See the sweep above.
    readonly property string mark: "shima-clip-watch"

    // The trap as well as the read: closing the pipe covers the shell
    // dying. It does not cover a hot reload, which kills the wrapper
    // outright and leaves nothing able to run — that is what the sweep
    // at startup is for.
    readonly property string keeper:
        'wl-paste --type "$1" --watch sh -c "$2" shima "$3" "$4" & '
        + 'w=$!; trap \'kill "$w" 2>/dev/null\' EXIT HUP INT TERM; '
        + 'read _'

    Process {
        id: textWatcher
        running: root.available && root.wanted
        stdinEnabled: true
        command: ["sh", "-c", root.keeper, "shima", "text",
            ": " + root.mark + "; "
            + "types=$(wl-paste --list-types 2>/dev/null); "
            // What the program that copied it marked as a password is
            // not history. Saying so is the whole point of the mark.
            + "case \"$types\" in *password*) exit 0;; esac; "
            // Something offering a picture as well as a description of
            // it is a picture. The other watcher has it.
            + "case \"$types\" in *image/*) exit 0;; esac; "
            + "printf 'txt\\t\\t'; cat; printf '\\036'",
            "", ""]
        stdout: SplitParser {
            splitMarker: "\u001e"
            onRead: (data) => root.remember(data)
        }
    }

    Process {
        id: imageWatcher
        running: root.available && root.wanted && root.wantImages
        stdinEnabled: true
        command: ["sh", "-c", root.keeper, "shima", "image/png",
            ": " + root.mark + "; "
            + "mkdir -p \"$1\" || exit 0; "
            + "f=\"$1/$(date +%s%N).png\"; "
            + "cat > \"$f\" || { rm -f \"$f\"; exit 0; }; "
            + "size=$(wc -c < \"$f\"); "
            + "[ \"$size\" -gt 0 ] && [ \"$size\" -le \"$2\" ] "
            + "  || { rm -f \"$f\"; exit 0; }; "
            // Read after the picture is safely out of the pipe, so
            // nothing is waiting on anything.
            + "case \"$(wl-paste --list-types 2>/dev/null)\" in "
            + "  *password*) rm -f \"$f\"; exit 0;; esac; "
            + "printf 'img\\t%s\\t%s\\036' "
            + "  \"$(cksum < \"$f\" | cut -d' ' -f1,2)\" \"$f\"",
            root.clipDir, String(root.imageLimit)]
        stdout: SplitParser {
            splitMarker: "\u001e"
            onRead: (data) => root.remember(data)
        }
    }

    function remember(record) {
        const first = record.indexOf("\t");
        if (first < 0) return;
        const second = record.indexOf("\t", first + 1);
        if (second < 0) return;

        const kind = record.slice(0, first);
        const mark = record.slice(first + 1, second);
        const body = record.slice(second + 1);

        if (kind === "img") root.add({ kind: "image", path: body, mark: mark });
        else if (body.trim() !== "") root.add({ kind: "text", text: body, mark: body });
    }

    function add(entry) {
        // Copying the same thing again moves it back to the front
        // rather than filling the list with itself.
        const next = [entry];
        const dropped = [];
        for (const e of root.entries) {
            if (e.mark === entry.mark) { dropped.push(e); continue; }
            if (next.length >= root.limit) { dropped.push(e); continue; }
            next.push(e);
        }
        root.entries = next;
        root.discard(dropped);
    }

    // A picture that has fallen off the end is a file nobody can reach
    // any more, so it goes with it.
    //
    // Through a list rather than straight to the process: writing a
    // command over one that is still running loses it, and losing this
    // one leaves a file nothing will ever delete. Emptying a history
    // with pictures in it is exactly the burst that does it.
    Process {
        id: remover
        onExited: root.sweepPending()
    }

    property var pending: []

    function discard(list) {
        const paths = [];
        for (const e of list)
            if (e.kind === "image" && e.path) paths.push(e.path);
        if (paths.length === 0) return;
        root.pending = root.pending.concat(paths);
        root.sweepPending();
    }

    function sweepPending() {
        if (remover.running || root.pending.length === 0) return;
        const go = root.pending;
        root.pending = [];
        remover.command = ["sh", "-c",
            'for f in "$@"; do rm -f -- "$f"; done', "shima"].concat(go);
        remover.running = true;
    }

    // Whether what was copied is a list of files rather than a piece
    // of text. Whoever copies files offers their addresses as text as
    // well, which is how they get in here at all.
    function isFiles(text) { return /^file:\/\//.test(text.trim()); }

    // One at a time, for the same reason: two clicks in quick
    // succession would leave the second holding nothing.
    Process {
        id: setter
        onExited: root.sendPending()
    }

    property var queued: null

    function copy(entry) {
        if (!root.available || !entry) return;
        root.queued = entry;
        root.sendPending();
    }

    function sendPending() {
        if (setter.running || !root.queued) return;
        const entry = root.queued;
        root.queued = null;

        if (entry.kind === "image") {
            setter.command = ["sh", "-c",
                'wl-copy --type image/png < "$1"', "shima", entry.path];
            setter.running = true;
            return;
        }

        // Put back as what it was. Handing a file's address back as
        // plain text gives a file manager a piece of text where it
        // expected a file; naming the type restores both, since
        // wl-copy offers text alongside it.
        const script = root.isFiles(entry.text)
            ? 'printf "%s" "$1" | wl-copy --type text/uri-list'
            : 'printf "%s" "$1" | wl-copy';
        setter.command = ["sh", "-c", script, "shima", entry.text];
        setter.running = true;
    }

    function forget() {
        const old = root.entries;
        root.entries = [];
        root.discard(old);
    }

    // One line, whitespace collapsed, because a snippet of code or a
    // paragraph would otherwise be a wall.
    function preview(entry) {
        if (!entry) return "";
        if (entry.kind === "image") return "";

        let flat = entry.text.replace(/\s+/g, " ").trim();

        // A file is worth showing as a path and not as an address:
        // "file:///home/…/Some%20Report.pdf" says less than the thing
        // it points at.
        if (root.isFiles(flat)) {
            const paths = [];
            for (const uri of flat.split(" ")) {
                if (!uri) continue;
                let path = uri.replace(/^file:\/\//, "");
                try { path = decodeURIComponent(path); } catch (e) {}
                paths.push(path);
            }
            flat = paths.join("  ");
        }

        return flat.length > 120 ? flat.slice(0, 120) + "…" : flat;
    }

    function matches(entry, query) {
        if (!query) return true;
        // A picture has nothing to search, so a search leaves it out
        // rather than keeping it around as an answer to everything.
        if (entry.kind === "image") return false;
        return entry.text.toLowerCase().indexOf(query.toLowerCase()) !== -1;
    }
}
