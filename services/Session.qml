pragma Singleton
import Quickshell
import Quickshell.Io

// Power and session actions, through the same interfaces Plasma's own
// menu uses rather than raw systemctl: that way logging out asks the
// applications to close properly and the session is torn down in
// order, instead of being pulled from under them.
Singleton {
    id: root

    Process { id: proc }

    function run(args) { proc.exec(args); }

    function kde(method) {
        root.run(["gdbus", "call", "--session",
                  "--dest", "org.kde.Shutdown",
                  "--object-path", "/Shutdown",
                  "--method", "org.kde.Shutdown." + method]);
    }

    // ── Power ──────────────────────────────────────────────────
    function shutdown() { root.kde("logoutAndShutdown"); }
    function reboot()   { root.kde("logoutAndReboot"); }

    function suspend() {
        root.run(["gdbus", "call", "--system",
                  "--dest", "org.freedesktop.login1",
                  "--object-path", "/org/freedesktop/login1",
                  "--method", "org.freedesktop.login1.Manager.Suspend", "true"]);
    }

    function hibernate() {
        root.run(["gdbus", "call", "--system",
                  "--dest", "org.freedesktop.login1",
                  "--object-path", "/org/freedesktop/login1",
                  "--method", "org.freedesktop.login1.Manager.Hibernate", "true"]);
    }

    // ── Session ────────────────────────────────────────────────
    function lock() {
        root.run(["gdbus", "call", "--session",
                  "--dest", "org.freedesktop.ScreenSaver",
                  "--object-path", "/ScreenSaver",
                  "--method", "org.freedesktop.ScreenSaver.Lock"]);
    }

    function logout() { root.kde("logout"); }

    // Switching users goes through the display manager, which parks the
    // current session and shows the greeter.
    function switchUser() {
        const seat = Quickshell.env("XDG_SEAT_PATH")
                     || "/org/freedesktop/DisplayManager/Seat0";
        root.run(["gdbus", "call", "--system",
                  "--dest", "org.freedesktop.DisplayManager",
                  "--object-path", seat,
                  "--method", "org.freedesktop.DisplayManager.Seat.SwitchToGreeter"]);
    }
}
