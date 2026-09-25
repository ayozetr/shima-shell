pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Whether the shell starts with the session, which is one file being
// there or not: ~/.config/autostart/shima.desktop.
//
// The installer used to be the only place this could be decided, and
// only through a flag on a command line that most people never type —
// the documented way in is a pipe into sh. A shell that takes over the
// panels and then does not come back after a restart leaves a bare
// desktop and no clue why, so it belongs in the settings window, where
// it can also be turned off again.
Singleton {
    id: root

    // What the file says right now. Read rather than remembered: it is
    // an ordinary file, and the installer, a package or the person
    // themselves may have put it there or taken it away.
    property bool enabled: false

    // Asked while the settings window is open and not once at startup:
    // nothing else in the shell cares, and this way the switch is right
    // even if the file changed behind our back.
    property bool watching: false

    onWatchingChanged: if (root.watching) root.refresh()

    function refresh() { check.running = true; }

    Process {
        id: check
        command: ["sh", "-c", "test -e \"$1\" && echo yes || echo no",
                  "shima", Paths.autostartFile]
        stdout: StdioCollector {
            onStreamFinished: root.enabled = text.trim() === "yes"
        }
    }

    // Written here rather than copied from the installed desktop file,
    // because the two say different things: the installed one carries
    // `Exec=shima`, which is a name the session has to be able to find,
    // and this one carries the full path of the launcher that is
    // running. A login session builds its PATH before Shima is
    // installed, so the name is exactly what cannot be relied on.
    function setEnabled(on) {
        if (on && Paths.launcher === "") return;
        write.exec(on ? ["sh", "-c",
            'mkdir -p "$(dirname "$1")" && cat > "$1" <<EOF\n'
            + '[Desktop Entry]\n'
            + 'Type=Application\n'
            + 'Name=Shima Shell\n'
            + 'Comment=Dynamic island and dock for KDE Plasma\n'
            + 'Exec=$2\n'
            + 'Icon=shima\n'
            + 'Terminal=false\n'
            + 'NoDisplay=true\n'
            + 'OnlyShowIn=KDE;\n'
            + 'X-KDE-autostart-phase=2\n'
            + 'X-GNOME-Autostart-enabled=true\n'
            + 'EOF\n',
            "shima", Paths.autostartFile, Paths.launcher]
          : ["rm", "-f", Paths.autostartFile]);
    }

    Process {
        id: write
        onExited: root.refresh()
    }
}
