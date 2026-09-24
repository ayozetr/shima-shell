import QtQuick
import Quickshell
import "../services"

// Settings: the dock, what it holds and how its icons look.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 2

    // The values, which write themselves when touched.
    readonly property var c: Config.data

    // ── DOCK ────────────────────────────────────────────
    Controls.Section_ { text: I18n.t.secDock }

    Controls.Row_ {
        label: I18n.t.position
        Controls.Choice_ {
            options: [{value: "bottom", label: I18n.t.bottom}, {value: "top", label: I18n.t.top}]
            value: root.c.dockPosition ?? "bottom"
            onPicked: (v) => { root.c.dockPosition = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.floating
        hint: I18n.t.floatingHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.dockFloating ?? false
            onToggled: (v) => { root.c.dockFloating = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.edgeGap
        visible: root.c.dockFloating ?? false
        Controls.Slider_ {
            from: 0; to: 40; step: 1; suffix: " px"
            value: root.c.dockMargin ?? 10
            onMoved: (v) => { root.c.dockMargin = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.autoHide
        hint: I18n.t.autoHideDockHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.dockAutoHide ?? false
            onToggled: (v) => { root.c.dockAutoHide = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.hideDelay
        visible: root.c.dockAutoHide ?? false
        Controls.Slider_ {
            from: 200; to: 2000; step: 50; suffix: " ms"
            value: root.c.dockHideDelay ?? 700
            onMoved: (v) => { root.c.dockHideDelay = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.opacity
        Controls.Slider_ {
            from: 0.2; to: 1; step: 0.01
            value: root.c.dockOpacity ?? 0.8
            onMoved: (v) => { root.c.dockOpacity = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.blur
        hint: I18n.t.blurHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.dockBlur ?? true
            onToggled: (v) => { root.c.dockBlur = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.cornerRadius
        Controls.Slider_ {
            from: 0; to: 40; step: 1; suffix: " px"
            value: root.c.dockCornerRadius ?? 28
            onMoved: (v) => { root.c.dockCornerRadius = v; Config.save(); }
        }
    }

    Controls.Section_ { text: I18n.t.secDockApps }

    PinnedEditor {
        width: parent.width
        topPadding: 6
    }

    Item { width: 1; height: 8 }

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
            anchors.right: parent.right
            value: root.c.clipboardKey ?? 268435542
            label: root.c.clipboardLabel ?? "Meta+V"
            onCaptured: (key, text) => {
                root.c.clipboardKey = key;
                root.c.clipboardLabel = text;
                Config.save();
            }
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
        visible: root.c.shortcutEnabled ?? true
        Controls.KeyCapture_ {
            anchors.right: parent.right
            value: root.c.shortcutKey ?? 16777250
            label: root.c.shortcutLabel ?? "Meta"
            onCaptured: (key, text) => {
                root.c.shortcutKey = key;
                root.c.shortcutLabel = text;
                Config.save();
            }
        }
    }

    Controls.Row_ {
        label: I18n.t.showNames
        hint: I18n.t.showNamesHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.showAppNames ?? true
            onToggled: (v) => { root.c.showAppNames = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.showTray
        hint: I18n.t.showTrayHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.showTray ?? true
            onToggled: (v) => { root.c.showTray = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.trayCollapsible
        hint: I18n.t.trayCollapsibleHint
        visible: root.c.showTray ?? true
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.trayCollapsible ?? true
            onToggled: (v) => { root.c.trayCollapsible = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.showRunning
        hint: I18n.t.showRunningHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.showRunning ?? true
            onToggled: (v) => { root.c.showRunning = v; Config.save(); }
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
        label: I18n.t.inheritTaskbar
        hint: I18n.t.inheritTaskbarHint
        Controls.Button_ {
            anchors.right: parent.right
            label: I18n.t.import
            onTriggered: Pinned.importFromPlasma()
        }
    }

    Item { width: 1; height: 6 }

    Controls.Section_ { text: I18n.t.secIcons }

    Controls.Row_ {
        label: I18n.t.shape
        Controls.Choice_ {
            options: [{value: "squircle", label: I18n.t.rounded},
                      {value: "circle",   label: I18n.t.circle},
                      {value: "square",   label: I18n.t.square}]
            value: root.c.iconShape ?? "squircle"
            onPicked: (v) => { root.c.iconShape = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.curvature
        hint: I18n.t.curvatureHint
        visible: (root.c.iconShape ?? "squircle") === "squircle"
        Controls.Slider_ {
            from: 5; to: 50; step: 1; suffix: " %"
            value: root.c.iconRadiusPct ?? 33
            onMoved: (v) => { root.c.iconRadiusPct = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.size
        hint: I18n.t.sizeHint
        Controls.Slider_ {
            from: 32; to: 88; step: 2; suffix: " px"
            value: root.c.dockIconSize ?? 56
            onMoved: (v) => { root.c.dockIconSize = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.magnify
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.dockMagnify ?? true
            onToggled: (v) => { root.c.dockMagnify = v; Config.save(); }
        }
    }
}
