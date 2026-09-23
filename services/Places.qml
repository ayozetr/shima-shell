pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The places Dolphin shows down its side.
//
// KDE keeps them in an XBEL file, which is the same list the file
// manager and the K menu read, so adding or renaming one there shows
// up here with nothing else to do.
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.local/share/user-places.xbel"

    // [{ id, name, icon, url, isPlace }]
    property var entries: []

    FileView {
        id: file
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parse(file.text())
    }

    function refresh() { file.reload(); }

    function parse(xml) {
        const out = [];
        const bookmarks = xml.split("<bookmark href=\"");

        for (let i = 1; i < bookmarks.length; i++) {
            const chunk = bookmarks[i];

            const endQuote = chunk.indexOf("\"");
            // Without a closing tag the chunk would run to the end of
            // the document, and the bookmark would come out carrying
            // the next ones' data. Skipping it loses one entry;
            // trusting it corrupts the rest.
            const endTag = chunk.indexOf("</bookmark>");
            if (endQuote < 0 || endTag < 0) continue;

            const url = chunk.slice(0, endQuote);
            const body = chunk.slice(0, endTag);

            // Hidden ones are still in the file, with a flag.
            if (/<IsHidden>true<\/IsHidden>/.test(body)) continue;

            const title = root.between(body, "<title>", "</title>");
            const icon = root.attr(body, "<bookmark:icon name=\"");
            const system = /<isSystemItem>true<\/isSystemItem>/.test(body);

            out.push({
                id: "place:" + url,
                name: root.nameFor(url, title, system),
                icon: icon || "folder",
                comment: root.readable(url),
                url: url,
                isPlace: true
            });
        }
        root.entries = out;
    }

    function between(text, open, close) {
        const a = text.indexOf(open);
        if (a < 0) return "";
        const b = text.indexOf(close, a + open.length);
        return b < 0 ? "" : text.slice(a + open.length, b);
    }

    function attr(text, open) {
        const a = text.indexOf(open);
        if (a < 0) return "";
        const b = text.indexOf("\"", a + open.length);
        return b < 0 ? "" : text.slice(a + open.length, b);
    }

    // The file stores English titles for the standard entries, and KDE
    // translates them when it draws them. For the folders that is the
    // folder's own name, which the system already localised — so the
    // path is a better source than the title. The rest are not folders
    // and need saying.
    function nameFor(url, title, system) {
        if (url === "trash:/") return I18n.t.placeTrash;
        if (url === "remote:/") return I18n.t.placeNetwork;
        if (url.indexOf("recentlyused:") === 0) return I18n.t.placeRecent;
        if (url.indexOf("timeline:") === 0) return I18n.t.placeRecent;

        if (url.indexOf("file://") === 0) {
            const p = root.decode(url.slice("file://".length));
            if (p === Quickshell.env("HOME")) return I18n.t.placeHome;
            if (system || title === "") {
                const last = p.replace(/\/+$/, "").split("/").pop();
                if (last) return last;
            }
        }
        return title;
    }

    function readable(url) {
        if (url.indexOf("file://") !== 0) return url;
        return root.decode(url.slice("file://".length));
    }

    // decodeURIComponent throws on a stray or malformed %, and this is
    // called from inside the parsing loop: one odd bookmark and the
    // exception left before anything was stored, so every other place
    // disappeared too. An undecoded path is worse than a decoded one
    // and better than none.
    function decode(s) {
        try {
            return decodeURIComponent(s);
        } catch (e) {
            return s;
        }
    }

    function open(entry) {
        if (!entry || !entry.url) return;
        Quickshell.execDetached(["xdg-open", entry.url]);
    }
}
