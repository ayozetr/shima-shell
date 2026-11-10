pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Who is logged in and where: the name, the machine's name, and the
// picture the account carries, for the session bar to show.
Singleton {
    id: root

    readonly property string name:
        Quickshell.env("USER") || Quickshell.env("USERNAME") || "user"

    // Filled once the little probe below has run.
    property string host: ""
    property string avatar: ""

    // The hostname, and the first avatar there is — the one the login
    // screen uses, else the dotfiles a plain login reads. Separated by a
    // line nothing else prints, so the two come apart cleanly.
    Process {
        running: true
        command: ["sh", "-c",
            "cat /proc/sys/kernel/hostname 2>/dev/null; echo '\x1e'; "
            + 'for p in "/var/lib/AccountsService/icons/$USER" '
            + '"$HOME/.face.icon" "$HOME/.face"; do '
            + '[ -f "$p" ] && { printf "%s" "$p"; break; }; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\u001e");
                root.host = (parts[0] || "").trim();
                root.avatar = (parts[1] || "").trim();
            }
        }
    }
}
