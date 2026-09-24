import QtQuick
import Quickshell
import "../services"

// Settings: notifications, and the quiet a focus session asks for.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 2

    // The values, which write themselves when touched.
    readonly property var c: Config.data

    Controls.Section_ { text: I18n.t.notifications }

    Controls.Row_ {
        label: I18n.t.notificationsEnabled
        hint: I18n.t.notificationsEnabledHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.notificationsEnabled ?? true
            onToggled: (v) => { root.c.notificationsEnabled = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.notificationPeekSeconds
        visible: root.c.notificationsEnabled ?? true
        Controls.Slider_ {
            from: 2; to: 15; step: 1; suffix: " s"
            value: root.c.notificationPeekSeconds ?? 5
            onMoved: (v) => { root.c.notificationPeekSeconds = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.notificationCards
        hint: I18n.t.notificationCardsHint
        visible: root.c.notificationsEnabled ?? true
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.notificationCards ?? true
            onToggled: (v) => { root.c.notificationCards = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.notificationCardSeconds
        visible: (root.c.notificationsEnabled ?? true)
                 && (root.c.notificationCards ?? true)
        Controls.Slider_ {
            from: 4; to: 40; step: 1; suffix: " s"
            value: root.c.notificationCardSeconds ?? 12
            onMoved: (v) => { root.c.notificationCardSeconds = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.notificationHistory
        visible: root.c.notificationsEnabled ?? true
        Controls.Slider_ {
            from: 10; to: 200; step: 10
            value: root.c.notificationHistory ?? 50
            onMoved: (v) => { root.c.notificationHistory = v; Config.save(); }
        }
    }

    Item { width: 1; height: 6 }

    Controls.Section_ { text: I18n.t.focus }

    Controls.Row_ {
        label: I18n.t.duration
        hint: I18n.t.durationHint
        Controls.Slider_ {
            from: 1; to: 120; step: 1; suffix: " min"
            value: root.c.focusMinutes ?? 25
            onMoved: (v) => { root.c.focusMinutes = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.chainBreak
        hint: I18n.t.chainBreakHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.focusChain ?? true
            onToggled: (v) => { root.c.focusChain = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.breakSetting
        visible: root.c.focusChain ?? true
        Controls.Slider_ {
            from: 1; to: 30; step: 1; suffix: " min"
            value: root.c.breakMinutes ?? 5
            onMoved: (v) => { root.c.breakMinutes = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.longBreakSetting
        visible: root.c.focusChain ?? true
        Controls.Slider_ {
            from: 5; to: 60; step: 5; suffix: " min"
            value: root.c.longBreakMinutes ?? 15
            onMoved: (v) => { root.c.longBreakMinutes = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.roundsBeforeLong
        visible: root.c.focusChain ?? true
        Controls.Slider_ {
            from: 2; to: 8; step: 1
            value: root.c.focusRounds ?? 4
            onMoved: (v) => { root.c.focusRounds = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.notifyOnEnd
        hint: I18n.t.notifyOnEndHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.focusNotify ?? true
            onToggled: (v) => { root.c.focusNotify = v; Config.save(); }
        }
    }

    Controls.Row_ {
        label: I18n.t.silenceWhile
        hint: I18n.t.silenceWhileHint
        Controls.Toggle_ {
            anchors.right: parent.right
            checked: root.c.focusInhibit ?? true
            onToggled: (v) => { root.c.focusInhibit = v; Config.save(); }
        }
    }
}
