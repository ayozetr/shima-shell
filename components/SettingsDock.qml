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

    // ── What a right click opens ──────────────────────────────
    //
    // The list is written down here because there is no way to ask
    // the system which applications are system monitors: the one KDE
    // ships does not declare the freedesktop "Monitor" category at
    // all, and the ones that do include a hardware topology viewer.
    // Checked against what is installed, so nobody is offered
    // something they do not have — and the settings file takes any
    // application id, which is the way out for anything missing here.
    readonly property var knownMonitors: [
        "org.kde.plasma-systemmonitor", "org.kde.ksysguard",
        "io.missioncenter.MissionCenter", "net.nokyan.Resources",
        "gnome-system-monitor", "org.gnome.SystemMonitor",
        "mate-system-monitor", "xfce4-taskmanager", "lxtask",
        "btop", "htop", "bpytop", "bashtop", "org.kde.kinfocenter"
    ]

    readonly property var rightClickOptions: {
        const out = [{ value: "settings", label: I18n.t.rightClickSettings }];
        for (const id of root.knownMonitors) {
            const e = (Apps.revision, Apps.entryFor(id));
            if (e) out.push({ value: id, label: e.name });
        }
        out.push({ value: "other", label: I18n.t.rightClickOther });
        out.push({ value: "none", label: I18n.t.rightClickNothing });
        return out;
    }

    readonly property string rightClick: root.c.dockRightClick ?? "settings"
    // Anything that is not ours, not nothing and not on the list is
    // something typed by hand, and the box below is where it lives.
    readonly property bool rightClickOther: {
        if (root.rightClick === "settings" || root.rightClick === "none")
            return false;
        return root.knownMonitors.indexOf(root.rightClick) === -1
            || !(Apps.revision, Apps.entryFor(root.rightClick));
    }

    Controls.SelectRow_ {
        label: I18n.t.rightClick
        hint: I18n.t.rightClickHint
        options: root.rightClickOptions
        value: root.rightClickOther ? "other" : root.rightClick
        onPicked: (v) => {
            // Choosing "another one" does not itself mean anything:
            // it opens the box below and waits to be told what.
            root.c.dockRightClick = (v === "other") ? "" : v;
            Config.save();
        }
    }

    Controls.Row_ {
        label: I18n.t.rightClickId
        hint: I18n.t.rightClickIdHint
        visible: root.rightClickOther || root.rightClick === ""
        Controls.Field_ {
            anchors.right: parent.right
            width: parent.width
            placeholder: "org.kde.plasma-systemmonitor"
            value: root.rightClick
            onEdited: (v) => { root.c.dockRightClick = v.trim(); Config.save(); }
        }
    }

    Item { width: 1; height: 6 }

    Controls.Row_ {
        label: I18n.t.dockTint
        Controls.Swatches_ {
            anchors.right: parent.right
            colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
            value: root.c.dockTint ?? "#000000"
            onPicked: (v) => { root.c.dockTint = v; Config.save(); }
        }
    }

    Item { width: 1; height: 6 }

    Controls.Section_ { text: I18n.t.secDockApps }

    PinnedEditor {
        width: parent.width
        topPadding: 6
    }

    Item { width: 1; height: 8 }

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
