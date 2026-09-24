pragma Singleton
import Quickshell

// Where everything lives.
//
// Installed, the program is read-only and lives apart from anything
// the user owns, so each kind of file has its own home: the settings
// under the config directory, throwaway work under the runtime one.
// The launcher script works these out and creates them before the
// shell starts; the fallbacks here are for running `qs` by hand
// during development, when nobody has exported anything.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/tmp"

    function env(name, fallback) {
        const v = Quickshell.env(name);
        return (v && v !== "") ? v : fallback;
    }

    // Where the program itself is: a checkout while it is being
    // worked on, /usr/share/shima once installed. The launcher knows
    // and says so; asked without it, the shell is being run by hand
    // from its own directory.
    readonly property string programDir: root.env("SHIMA_DATA_DIR", ".")

    // What it calls itself. Said by the launcher, which is the one
    // place the number is written down.
    readonly property string version: root.env("SHIMA_VERSION", "")

    // Settings you edit and expect to keep.
    readonly property string configDir:
        root.env("SHIMA_CONFIG_DIR",
                 root.env("XDG_CONFIG_HOME", root.home + "/.config") + "/shima")

    // Things we can rebuild at any time.
    readonly property string cacheDir:
        root.env("SHIMA_CACHE_DIR",
                 root.env("XDG_CACHE_HOME", root.home + "/.cache") + "/shima")

    // Scratch files for one run of the shell. This one matters for
    // more than tidiness: XDG_RUNTIME_DIR is created per user with
    // nobody else allowed in, while a fixed name under /tmp is a
    // guess anyone sharing the machine can make first — and then our
    // `>` writes through their symlink instead of to our file. Falls
    // back to the cache directory, which is at least inside $HOME.
    readonly property string runtimeDir:
        root.env("SHIMA_RUNTIME_DIR",
                 root.env("XDG_RUNTIME_DIR", "") !== ""
                 ? root.env("XDG_RUNTIME_DIR", "") + "/shima"
                 : root.cacheDir)

    // What the shell remembers between runs: the pinned dock, the
    // favourites. Deliberately not Quickshell.statePath(), which
    // derives its directory from the path the shell was started from
    // — so moving the files, or installing them, silently hands the
    // user an empty dock and a fresh set of favourites.
    readonly property string stateDir:
        root.env("SHIMA_STATE_DIR",
                 root.env("XDG_STATE_HOME", root.home + "/.local/state") + "/shima")

    // Where the program itself was installed, which is not somewhere
    // we may write. Only needed to find files that ship with it.
    readonly property string dataDir:
        root.env("SHIMA_DATA_DIR", "")
}
