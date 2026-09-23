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
    Process {
        id: sweep
        command: ["sh", "-c", 'rm -rf -- "$1" && mkdir -p "$1"', "shima", root.clipDir]
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
    Process {
        id: textWatcher
        running: root.available && root.wanted
        command: ["wl-paste", "--type", "text", "--watch", "sh", "-c",
            "types=$(wl-paste --list-types 2>/dev/null); "
            // What the program that copied it marked as a password is
            // not history. Saying so is the whole point of the mark.
            + "case \"$types\" in *password*) exit 0;; esac; "
            // Something offering a picture as well as a description of
            // it is a picture. The other watcher has it.
            + "case \"$types\" in *image/*) exit 0;; esac; "
            + "printf 'txt\\t\\t'; cat; printf '\\036'"]
        stdout: SplitParser {
            splitMarker: "\u001e"
            onRead: (data) => root.remember(data)
        }
    }

    Process {
        id: imageWatcher
        running: root.available && root.wanted && root.wantImages
        command: ["wl-paste", "--type", "image/png", "--watch", "sh", "-c",
            "mkdir -p \"$1\" || exit 0; "
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
            "shima", root.clipDir, String(root.imageLimit)]
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
    Process { id: remover }

    function discard(list) {
        const paths = [];
        for (const e of list)
            if (e.kind === "image" && e.path) paths.push(e.path);
        if (paths.length === 0) return;
        remover.command = ["sh", "-c",
            'for f in "$@"; do rm -f -- "$f"; done', "shima"].concat(paths);
        remover.running = true;
    }

    // Whether what was copied is a list of files rather than a piece
    // of text. Whoever copies files offers their addresses as text as
    // well, which is how they get in here at all.
    function isFiles(text) { return /^file:\/\//.test(text.trim()); }

    Process { id: setter }

    function copy(entry) {
        if (!root.available || !entry) return;

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
