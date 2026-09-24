import QtQuick
import Quickshell
import "../services"

// Settings: which screens it appears on, the language it speaks
// and the colours it wears.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 2

    // The values, which write themselves when touched.
    readonly property var c: Config.data

    // ── SCREENS ─────────────────────────────────────────
    Controls.Section_ {
        text: I18n.t.secScreens
        visible: Quickshell.screens.length > 1
    }

    ScreenPicker {
        width: parent.width
        visible: Quickshell.screens.length > 1
        topPadding: 6
    }

    Item {
        width: 1; height: 8
        visible: Quickshell.screens.length > 1
    }

    // ── LANGUAGE ────────────────────────────────────────
    Controls.Section_ { text: I18n.t.secLanguage }

    // Nine of them, so a list and not a row of buttons.
    Controls.SelectRow_ {
        label: I18n.t.language
        hint: I18n.t.languageHint
        options: I18n.available.map(l => ({ value: l.code, label: l.label }))
        value: root.c.language ?? "auto"
        onPicked: (v) => { root.c.language = v; Config.save(); }
    }

    // ── COLOUR ──────────────────────────────────────────
    Controls.Section_ { text: I18n.t.secColour }

    Controls.Row_ {
        label: I18n.t.accent
        hint: I18n.t.accentHint
        Controls.Swatches_ {
            anchors.right: parent.right
            colors: ["#a78bfa", "#60a5fa", "#34d399", "#fbbf24", "#f87171", "#ffffff"]
            value: root.c.accent ?? "#a78bfa"
            onPicked: (v) => { root.c.accent = v; Config.save(); }
        }
    }

    // One tone for the three surfaces at once. Not a fourth setting
    // kept somewhere: picking here writes the dock's, the island's and
    // the launcher's, and each of them can still be changed on its own
    // page afterwards. When they are not all the same it marks
    // nothing, which says "these are mixed" instead of naming one of
    // the three and being wrong about the other two.
    Controls.Row_ {
        label: I18n.t.tintAll
        hint: I18n.t.tintAllHint
        Controls.Swatches_ {
            anchors.right: parent.right
            colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
            value: {
                const dock = root.c.dockTint ?? "#000000";
                const island = root.c.islandTint ?? "#000000";
                const launcher = root.c.launcherTint ?? "#000000";
                return (dock === island && island === launcher) ? dock : "";
            }
            onPicked: (v) => {
                root.c.dockTint = v;
                root.c.islandTint = v;
                root.c.launcherTint = v;
                Config.save();
            }
        }
    }
}
