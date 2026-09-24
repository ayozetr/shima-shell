pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the dock holds: the applications you pinned, in your order,
// and the row that is drawn from them.
//
// Pinning is not favouriting. Pinning puts an application on the bar,
// where there is room for a handful; favouriting puts it first in the
// launcher — see Favorites.
Singleton {
    id: root

    // .desktop IDs, in order. On first run they are inherited from the
    // Plasma task manager, and where there is nothing to inherit — no
    // panel has ever been set up, which is exactly the desktop the
    // README describes — from what the system answers for a browser,
    // a file manager and a terminal. It used to start as a written
    // list, which was the author's own dock arriving on somebody
    // else's machine.
    property var list: []
    readonly property string path: Paths.stateDir + "/pinned.json"


    // What the dock shows. Kept as a plain list and replaced only when
    // it really differs: concatenating in a binding hands the Repeater
    // a brand new array every time anything it reads changes, and a
    // new array means every icon is destroyed and built again — which
    // is visible, because an icon takes a frame to load and the gap
    // shows.
    property var items: []
    // How many of those are pinned ones, which is where the divider
    // goes. Not the length of `pinned`: what cannot be drawn is not in
    // the row.
    property int pinnedCount: 0

    function sync() {
        // Something pinned that is not installed any more draws
        // nothing — there is no entry to take an icon or a name from —
        // but the empty square stayed in the row all the same, taking
        // up its place and swallowing the clicks meant for it. It is
        // left out of the row while it cannot be drawn, and stays in
        // pinned.json, so installing it again brings it back where it
        // was. Not while the catalogue is still being read, though:
        // during that everything looks uninstalled.
        const known = DesktopEntries.applications.values.length > 0;
        const next = [];
        for (const id of root.list)
            if (!known || Apps.entryFor(id)) next.push(id);
        // The ones that are merely open are kept either way: that tile
        // is the way back to a window that is on screen right now.
        for (const id of Windows.runningExtra) next.push(id);

        root.pinnedCount = next.length - Windows.runningExtra.length;

        if (next.join("\u0000") === root.items.join("\u0000")) return;
        root.items = next;
    }

    onListChanged: root.sync()

    // The row is a kept list and not a binding, so it has to be told
    // whenever what goes in it changes: what is open, and — through
    // the revision counter, which is what says so everywhere else —
    // what can be drawn at all, as the catalogue finishes its scan,
    // Steam's manifests are read and Heroic and Lutris answer.
    Connections {
        target: Windows
        function onRunningExtraChanged() { root.sync(); }
    }
    Connections {
        target: Apps
        function onRevisionChanged() { root.sync(); }
    }


    // ── Import the pinned apps from the Plasma task manager ─────
    //
    // The task manager keeps them on a single line of appletsrc, in
    // three shapes: applications:id.desktop, a file:// path, or a
    // preferred://, which has to be resolved by MIME type.
    Process {
        id: importer
        command: ["sh", "-c", `
            f="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
            [ -f "$f" ] || exit 0
            grep -m1 '^launchers=' "$f" | cut -d= -f2- | tr ',' '\n' | while read -r e; do
              case "$e" in
                preferred://browser)     xdg-mime query default x-scheme-handler/https ;;
                preferred://filemanager) xdg-mime query default inode/directory ;;
                preferred://mail)        xdg-mime query default x-scheme-handler/mailto ;;
                preferred://terminal)    echo org.kde.konsole.desktop ;;
                applications:*)          echo "\${e#applications:}" ;;
                file://*)                basename "\${e#file://}" ;;
              esac
            done | sed 's/\\.desktop$//' | awk 'NF && !seen[$0]++'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = text.split("\n").map(s => s.trim()).filter(s => s);
                if (!ids.length) {
                    console.log("[shima] the task manager has nothing pinned; "
                              + "asking the system what it opens things with");
                    starters.running = true;
                    return;
                }
                root.adopt(ids);
            }
        }
    }

    // Nothing to inherit: a session with no panel, or one where the
    // task manager was never touched. Rather than a dock of somebody
    // else's applications, the three the system can name by itself —
    // what it opens a web address with, what it opens a folder with,
    // and the terminal Plasma's own chooser wrote down.
    Process {
        id: starters
        command: ["sh", "-c", `
            {
              xdg-mime query default x-scheme-handler/https
              xdg-mime query default inode/directory
              kreadconfig6 --file kdeglobals --group General --key TerminalService
              echo org.kde.konsole.desktop
            } 2>/dev/null | while read -r e; do
              [ -n "$e" ] || continue
              case "$e" in *.desktop) ;; *) e="$e.desktop";; esac
              IFS=:
              for d in \${XDG_DATA_HOME:-$HOME/.local/share}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do
                [ -f "$d/applications/$e" ] || continue
                echo "$e"
                break
              done
              unset IFS
            done | sed 's/\\.desktop$//' | awk 'NF && !seen[$0]++'
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                const ids = text.split("\n").map(s => s.trim()).filter(s => s);
                if (ids.length) root.adopt(ids);
            }
        }
    }

    // Whatever was worked out is written down at once, so the working
    // out happens on the first run and never again.
    function adopt(ids) {
        root.list = ids;
        root.save();
        Apps.revision++;
        Windows.sweepNow();
    }

    function importFromPlasma() { importer.running = true; }


    // ── Persisting the pinned apps ─────────────────────────────
    FileView {
        id: pinnedFile
        path: root.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const parsed = JSON.parse(pinnedFile.text());
                if (Array.isArray(parsed) && parsed.length) {
                    root.list = parsed;
                    Apps.revision++;
                }
            } catch (e) { /* corrupt: keep whatever is already loaded */ }
        }
        // First run: inherit whatever is already pinned in the Plasma
        // task manager, which is what one expects to see.
        onLoadFailed: (error) => {
            if (error === FileViewError.FileNotFound) root.importFromPlasma();
        }
    }


    // Reordering, from dragging in the dock. The two numbers are
    // places in the row, and the row is not the pinned list — anything
    // pinned that cannot be drawn is missing from it — so they are
    // turned back into what was picked up and what it was dropped on
    // before the pinned list is touched.
    function move(from, to) {
        if (from === to || from < 0 || to < 0) return;
        if (from >= root.items.length || to >= root.items.length) return;
        const list = root.list.slice();
        const a = list.indexOf(root.items[from]);
        const b = list.indexOf(root.items[to]);
        if (a < 0 || b < 0) return;
        list.splice(b, 0, list.splice(a, 1)[0]);
        root.list = list;
        root.save();
    }

    function remove(id) {
        root.list = root.list.filter(x => x !== id);
        root.save();
    }

    function add(id) {
        if (root.list.indexOf(id) !== -1) return;
        root.list = root.list.concat([id]);
        root.save();
        Windows.sweepNow();
    }

    function save() {
        pinnedFile.setText(JSON.stringify(root.list, null, 2));
    }

}
