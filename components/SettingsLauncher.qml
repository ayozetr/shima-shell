import QtQuick
import Quickshell
import "../services"

// Settings: the application tray — how it opens, how it looks, and
// the clipboard that lives inside it.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 2

    // The values, which write themselves when touched.
    readonly property var c: Config.data

    Controls.Section_ { text: I18n.t.secLauncher }


    Controls.Row_ {
        label: I18n.t.shortcut
        hint: I18n.t.shortcutHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.shortcutEnabled ?? true
            onToggled: (v) => { root.c.shortcutEnabled = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.shortcutKey
        hint: I18n.t.shortcutKeyHint
        visible: root.c.shortcutEnabled ?? true
        Controls.KeyCapture_ {
            id: launcherKey
            anchors.right: parent.right
            role: "launcher"
            value: root.c.shortcutKey ?? 16777250
            label: root.c.shortcutLabel ?? "Meta"
            onCaptured: (key, text) => {
                root.c.shortcutKey = key;
                root.c.shortcutLabel = text;
                Config.save();
            }
        }
    }

    Controls.Notice_ {
        visible: launcherKey.tookFrom !== ""
        grave: launcherKey.tookFromOurs
        text: {
            if (launcherKey.tookFrom === "") return "";
            return (launcherKey.tookFromOurs ? I18n.t.shortcutTaken
                                    : I18n.t.shortcutBorrowed)
                + " " + launcherKey.tookFrom;
        }
    }


    Controls.Row_ {
        label: I18n.t.launcherButton
        hint: I18n.t.launcherButtonHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.showLauncher ?? true
            onToggled: (v) => { root.c.showLauncher = v; Config.save(); }
        }
    }


    Controls.Row_ {
        label: I18n.t.launcherLift
        hint: I18n.t.launcherLiftHint
        visible: root.c.showLauncher ?? true
        Controls.Slider_ {
            from: 0; to: 400; step: 5; suffix: " px"
            value: root.c.launcherLift ?? 0
            onMoved: (v) => { root.c.launcherLift = v; Config.save(); }
        }
    }


    Controls.Row_ {
        label: I18n.t.launcherTint
        visible: root.c.showLauncher ?? true
        Controls.Swatches_ {
            anchors.right: parent.right
            colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
            value: root.c.launcherTint ?? "#000000"
            onPicked: (v) => { root.c.launcherTint = v; Config.save(); }
        }
    }


    Controls.Row_ {
        label: I18n.t.inheritFavorites
        hint: I18n.t.inheritFavoritesHint
        Controls.Button_ {
            anchors.right: parent.right
            label: I18n.t.import
            onTriggered: Favorites.importFromPlasma()
        }
    }


    Controls.Row_ {
        label: I18n.t.keepAwakeRemember
        hint: I18n.t.keepAwakeRememberHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.keepAwakeRemember ?? false
            onToggled: (v) => {
                root.c.keepAwakeRemember = v;
                if (v) root.c.keepAwakeOn = Power.keepAwake;
                Config.save();
            }
        }
    }

    Item { width: 1; height: 6 }

    Controls.Section_ { text: I18n.t.secClipboard }


    Controls.Row_ {
        label: I18n.t.clipboardHistory
        hint: I18n.t.clipboardHistoryHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.clipboardHistory ?? true
            onToggled: (v) => { root.c.clipboardHistory = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.clipboardImages
        hint: I18n.t.clipboardImagesHint
        visible: root.c.clipboardHistory ?? true
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.clipboardImages ?? true
            onToggled: (v) => { root.c.clipboardImages = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.clipboardShortcut
        visible: root.c.clipboardHistory ?? true
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.clipboardShortcutEnabled ?? true
            onToggled: (v) => {
                root.c.clipboardShortcutEnabled = v;
                Config.save();
            }
        }
    }

    Controls.Row_ {
        label: I18n.t.clipboardShortcutKey
        visible: (root.c.clipboardHistory ?? true)
                 && (root.c.clipboardShortcutEnabled ?? true)
        Controls.KeyCapture_ {
            id: clipboardKey
            anchors.right: parent.right
            role: "clipboard"
            value: root.c.clipboardKey ?? 268435542
            label: root.c.clipboardLabel ?? "Meta+V"
            onCaptured: (key, text) => {
                root.c.clipboardKey = key;
                root.c.clipboardLabel = text;
                Config.save();
            }
        }
    }

    Controls.Notice_ {
        visible: clipboardKey.tookFrom !== ""
        grave: clipboardKey.tookFromOurs
        text: {
            if (clipboardKey.tookFrom === "") return "";
            return (clipboardKey.tookFromOurs ? I18n.t.shortcutTaken
                                    : I18n.t.shortcutBorrowed)
                + " " + clipboardKey.tookFrom;
        }
    }
}
