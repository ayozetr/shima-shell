pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Who already answers to a key.
//
// Ours are known from our own settings; everybody else's are read out
// of the file KDE keeps them in. It is read rather than asked because
// asking means KGlobalAccel, which is D-Bus, which is the helper's
// job — and the helper cannot be spoken to. The file is KDE's own and
// is written the moment a shortcut changes, so it is as fresh as the
// question.
Singleton {
    id: root

    readonly property string path:
        Paths.env("XDG_CONFIG_HOME", Paths.home + "/.config")
        + "/kglobalshortcutsrc"

    // component id → what a person would call it.
    property var names: ({})
    // key text ("Meta+V") → component id.
    property var holders: ({})

    FileView {
        id: file
        path: root.path
        onLoaded: root.parse(file.text())
        onLoadFailed: { root.names = {}; root.holders = {}; }
    }

    function refresh() { file.reload(); }

    function parse(text) {
        const names = {};
        const holders = {};
        let group = "";

        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line === "" || line.startsWith("#")) continue;

            if (line.startsWith("[") && line.endsWith("]")) {
                // Only the top level: KDE nests groups for friendly
                // names per language, and those are not shortcuts.
                group = line.slice(1, -1);
                continue;
            }
            const eq = line.indexOf("=");
            if (eq < 0 || group === "") continue;

            const name = line.slice(0, eq);
            const value = line.slice(eq + 1);
            if (name === "_k_friendly_name") { names[group] = value; continue; }
            // Ours are answered from the settings, which are true even
            // while the helper has taken them out of KDE's hands.
            if (group === "shima") continue;

            // "current,default,description", and the current one may
            // hold several keys separated by an escaped tab.
            const current = value.split(",")[0];
            if (!current || current === "none") continue;
            for (const key of current.split("\\t")) {
                const k = key.trim();
                if (k !== "" && k !== "none" && holders[k] === undefined)
                    holders[k] = group;
            }
        }
        root.names = names;
        root.holders = holders;
    }

    // What a person would call whoever holds `label`, or "" if it is
    // free. `mine` is the one being set, so it is not reported as
    // being in the way of itself.
    function usedBy(label, mine) {
        if (!label) return "";

        const ourKey = {
            launcher: Config.data.shortcutKey ?? 0,
            clipboard: Config.data.clipboardKey ?? 0
        };
        const ourLabel = {
            launcher: Config.data.shortcutLabel ?? "",
            clipboard: Config.data.clipboardLabel ?? ""
        };
        const ourName = {
            launcher: I18n.t.pageLauncher,
            clipboard: I18n.t.catClipboard
        };
        for (const who in ourLabel) {
            if (who === mine) continue;
            if (ourLabel[who] !== "" && ourLabel[who] === label)
                return ourName[who];
        }

        const group = root.holders[label];
        if (group === undefined) return "";
        return root.names[group] || group;
    }

    // Takes the key for `mine`, and says who had it: { who, ours }.
    //
    // The two cases are not the same and used to be told the same way.
    // Taking a key off another program is what this has always done —
    // the helper notes it and gives it back on the way out — and
    // saying it in red made ordinary working look like a fault.
    // Taking it off ourselves is different: the other one is left with
    // no shortcut at all, because two things on one key means pressing
    // it does both, which is never what was meant.
    function claim(mine, label) {
        const who = root.usedBy(label, mine);
        if (who === "") return { who: "", ours: false };

        let ours = false;
        if (mine !== "launcher" && (Config.data.shortcutLabel ?? "") === label) {
            Config.data.shortcutKey = 0;
            Config.data.shortcutLabel = "";
            Config.save();
            ours = true;
        }
        if (mine !== "clipboard" && (Config.data.clipboardLabel ?? "") === label) {
            Config.data.clipboardKey = 0;
            Config.data.clipboardLabel = "";
            Config.save();
            ours = true;
        }
        return { who: who, ours: ours };
    }
}
