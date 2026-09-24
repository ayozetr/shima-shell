import QtQuick
import Quickshell
import "../services"

// Settings: the island.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 2

    // The values, which write themselves when touched.
    readonly property var c: Config.data

    Controls.Section_ { text: I18n.t.secIsland }

    Controls.Row_ {
        label: I18n.t.showIsland
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.islandEnabled ?? true
            onToggled: (v) => { root.c.islandEnabled = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.clockFormat
        Controls.Choice_ {
            options: [{value: "24", label: "24 h"}, {value: "12", label: "12 h"}]
            value: (root.c.clock24 ?? true) ? "24" : "12"
            onPicked: (v) => { root.c.clock24 = (v === "24"); Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.cornerRadius
        Controls.Slider_ {
            from: 0; to: 34; step: 1; suffix: " px"
            value: root.c.islandRadius ?? 22
            onMoved: (v) => { root.c.islandRadius = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.collapsedWidth
        Controls.Slider_ {
            from: 220; to: 620; step: 5; suffix: " px"
            value: root.c.islandCollapsedWidth ?? 410
            onMoved: (v) => { root.c.islandCollapsedWidth = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.expandedWidth
        Controls.Slider_ {
            from: 320; to: 720; step: 5; suffix: " px"
            value: root.c.islandExpandedWidth ?? 425
            onMoved: (v) => { root.c.islandExpandedWidth = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.collapsedHeight
        Controls.Slider_ {
            from: 26; to: 60; step: 1; suffix: " px"
            value: root.c.islandCollapsedHeight ?? 38
            onMoved: (v) => { root.c.islandCollapsedHeight = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.detached
        hint: I18n.t.detachedHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.islandFloating ?? false
            onToggled: (v) => { root.c.islandFloating = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.topGap
        visible: root.c.islandFloating ?? false
        Controls.Slider_ {
            from: 0; to: 40; step: 1; suffix: " px"
            value: root.c.islandMargin ?? 8
            onMoved: (v) => { root.c.islandMargin = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.autoHide
        hint: I18n.t.autoHideIslandHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.islandAutoHide ?? false
            onToggled: (v) => { root.c.islandAutoHide = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.hideDelay
        visible: root.c.islandAutoHide ?? false
        Controls.Slider_ {
            from: 200; to: 2000; step: 50; suffix: " ms"
            value: root.c.islandHideDelay ?? 700
            onMoved: (v) => { root.c.islandHideDelay = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.opacity
        Controls.Slider_ {
            from: 0.2; to: 1; step: 0.01
            value: root.c.islandOpacity ?? 1.0
            onMoved: (v) => { root.c.islandOpacity = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.blur
        hint: I18n.t.blurIslandHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.islandBlur ?? false
            onToggled: (v) => { root.c.islandBlur = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.islandTint
        Controls.Swatches_ {
            anchors.right: parent.right
            colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
            value: root.c.islandTint ?? "#000000"
            onPicked: (v) => { root.c.islandTint = v; Config.save(); }
        }
    }

    Item { width: 1; height: 6 }
}
