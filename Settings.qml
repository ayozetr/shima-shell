import QtQuick
import Quickshell
import "services"
import "components"

FloatingWindow {
    id: win

    // Through a Binding and not a plain one, and the two are not the
    // same thing here. Closing the window with its own button writes
    // visible from outside, which throws a plain binding away for
    // good: the singleton stayed saying it was open, nothing could put
    // it back on screen, and Settings was gone until the shell was
    // restarted. A Binding object survives that and applies again the
    // next time it is asked for.
    Binding {
        target: win
        property: "visible"
        value: SettingsWindow.open
    }

    // And the other direction, so closing it by hand is the same as
    // closing it from the dock.
    onVisibleChanged: if (!win.visible) SettingsWindow.hide()

    implicitWidth: 520
    implicitHeight: 640
    title: I18n.t.settingsWindowTitle
    color: "#0e0e0e"

    // Shortcut to the values, which write themselves when touched.
    readonly property var c: Config.data

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 2

            Text {
                text: I18n.t.settingsTitle
                color: Theme.textPrimary
                font.pixelSize: 22
                font.weight: Font.DemiBold
                bottomPadding: 2
            }
            Text {
                text: I18n.t.settingsSubtitle
                color: Theme.textTertiary
                font.pixelSize: 11
                bottomPadding: 6
            }

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

            // ── DOCK ────────────────────────────────────────────
            Controls.Section_ { text: I18n.t.secDock }

            Controls.Row_ {
                label: I18n.t.position
                Controls.Choice_ {
                    options: [{value: "bottom", label: I18n.t.bottom}, {value: "top", label: I18n.t.top}]
                    value: win.c.dockPosition ?? "bottom"
                    onPicked: (v) => { win.c.dockPosition = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.floating
                hint: I18n.t.floatingHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.dockFloating ?? false
                    onToggled: (v) => { win.c.dockFloating = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.edgeGap
                visible: win.c.dockFloating ?? false
                Controls.Slider_ {
                    from: 0; to: 40; step: 1; suffix: " px"
                    value: win.c.dockMargin ?? 10
                    onMoved: (v) => { win.c.dockMargin = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.autoHide
                hint: I18n.t.autoHideDockHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.dockAutoHide ?? false
                    onToggled: (v) => { win.c.dockAutoHide = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.hideDelay
                visible: win.c.dockAutoHide ?? false
                Controls.Slider_ {
                    from: 200; to: 2000; step: 50; suffix: " ms"
                    value: win.c.dockHideDelay ?? 700
                    onMoved: (v) => { win.c.dockHideDelay = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.opacity
                Controls.Slider_ {
                    from: 0.2; to: 1; step: 0.01
                    value: win.c.dockOpacity ?? 0.8
                    onMoved: (v) => { win.c.dockOpacity = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.blur
                hint: I18n.t.blurHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.dockBlur ?? true
                    onToggled: (v) => { win.c.dockBlur = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.cornerRadius
                Controls.Slider_ {
                    from: 0; to: 40; step: 1; suffix: " px"
                    value: win.c.dockCornerRadius ?? 28
                    onMoved: (v) => { win.c.dockCornerRadius = v; Config.save(); }
                }
            }

            // ── APPLICATIONS ────────────────────────────────────
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
                    checked: win.c.showLauncher ?? true
                    onToggled: (v) => { win.c.showLauncher = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.launcherLift
                hint: I18n.t.launcherLiftHint
                visible: win.c.showLauncher ?? true
                Controls.Slider_ {
                    from: 0; to: 400; step: 5; suffix: " px"
                    value: win.c.launcherLift ?? 0
                    onMoved: (v) => { win.c.launcherLift = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.keepAwakeRemember
                hint: I18n.t.keepAwakeRememberHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.keepAwakeRemember ?? false
                    onToggled: (v) => {
                        win.c.keepAwakeRemember = v;
                        if (v) win.c.keepAwakeOn = Power.keepAwake;
                        Config.save();
                    }
                }
            }

            Controls.Row_ {
                label: I18n.t.clipboardHistory
                hint: I18n.t.clipboardHistoryHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.clipboardHistory ?? true
                    onToggled: (v) => { win.c.clipboardHistory = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.clipboardImages
                hint: I18n.t.clipboardImagesHint
                visible: win.c.clipboardHistory ?? true
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.clipboardImages ?? true
                    onToggled: (v) => { win.c.clipboardImages = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.clipboardShortcut
                visible: win.c.clipboardHistory ?? true
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.clipboardShortcutEnabled ?? true
                    onToggled: (v) => {
                        win.c.clipboardShortcutEnabled = v;
                        Config.save();
                    }
                }
            }

            Controls.Row_ {
                label: I18n.t.clipboardShortcutKey
                visible: (win.c.clipboardHistory ?? true)
                         && (win.c.clipboardShortcutEnabled ?? true)
                Controls.KeyCapture_ {
                    anchors.right: parent.right
                    value: win.c.clipboardKey ?? 268435542
                    label: win.c.clipboardLabel ?? "Meta+V"
                    onCaptured: (key, text) => {
                        win.c.clipboardKey = key;
                        win.c.clipboardLabel = text;
                        Config.save();
                    }
                }
            }

            Controls.Row_ {
                label: I18n.t.launcherTint
                visible: win.c.showLauncher ?? true
                Controls.Swatches_ {
                    anchors.right: parent.right
                    colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
                    value: win.c.launcherTint ?? "#000000"
                    onPicked: (v) => { win.c.launcherTint = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.shortcut
                hint: I18n.t.shortcutHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.shortcutEnabled ?? true
                    onToggled: (v) => { win.c.shortcutEnabled = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.shortcutKey
                visible: win.c.shortcutEnabled ?? true
                Controls.KeyCapture_ {
                    anchors.right: parent.right
                    value: win.c.shortcutKey ?? 16777250
                    label: win.c.shortcutLabel ?? "Meta"
                    onCaptured: (key, text) => {
                        win.c.shortcutKey = key;
                        win.c.shortcutLabel = text;
                        Config.save();
                    }
                }
            }

            Controls.Row_ {
                label: I18n.t.showNames
                hint: I18n.t.showNamesHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.showAppNames ?? true
                    onToggled: (v) => { win.c.showAppNames = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.showTray
                hint: I18n.t.showTrayHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.showTray ?? true
                    onToggled: (v) => { win.c.showTray = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.trayCollapsible
                hint: I18n.t.trayCollapsibleHint
                visible: win.c.showTray ?? true
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.trayCollapsible ?? true
                    onToggled: (v) => { win.c.trayCollapsible = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.showRunning
                hint: I18n.t.showRunningHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.showRunning ?? true
                    onToggled: (v) => { win.c.showRunning = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.inheritFavorites
                hint: I18n.t.inheritFavoritesHint
                Controls.Button_ {
                    anchors.right: parent.right
                    label: I18n.t.import
                    onTriggered: Apps.importFavoritesFromPlasma()
                }
            }

            Controls.Row_ {
                label: I18n.t.inheritTaskbar
                hint: I18n.t.inheritTaskbarHint
                Controls.Button_ {
                    anchors.right: parent.right
                    label: I18n.t.import
                    onTriggered: Apps.importFromPlasma()
                }
            }

            Item { width: 1; height: 6 }

            // ── ICONS ───────────────────────────────────────────
            Controls.Section_ { text: I18n.t.secIcons }

            Controls.Row_ {
                label: I18n.t.shape
                Controls.Choice_ {
                    options: [{value: "squircle", label: I18n.t.rounded},
                              {value: "circle",   label: I18n.t.circle},
                              {value: "square",   label: I18n.t.square}]
                    value: win.c.iconShape ?? "squircle"
                    onPicked: (v) => { win.c.iconShape = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.curvature
                hint: I18n.t.curvatureHint
                visible: (win.c.iconShape ?? "squircle") === "squircle"
                Controls.Slider_ {
                    from: 5; to: 50; step: 1; suffix: " %"
                    value: win.c.iconRadiusPct ?? 33
                    onMoved: (v) => { win.c.iconRadiusPct = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.size
                hint: I18n.t.sizeHint
                Controls.Slider_ {
                    from: 32; to: 88; step: 2; suffix: " px"
                    value: win.c.dockIconSize ?? 56
                    onMoved: (v) => { win.c.dockIconSize = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.magnify
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.dockMagnify ?? true
                    onToggled: (v) => { win.c.dockMagnify = v; Config.save(); }
                }
            }

            // ── ISLAND ──────────────────────────────────────────
            Controls.Section_ { text: I18n.t.secIsland }

            Controls.Row_ {
                label: I18n.t.showIsland
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.islandEnabled ?? true
                    onToggled: (v) => { win.c.islandEnabled = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.clockFormat
                Controls.Choice_ {
                    options: [{value: "24", label: "24 h"}, {value: "12", label: "12 h"}]
                    value: (win.c.clock24 ?? true) ? "24" : "12"
                    onPicked: (v) => { win.c.clock24 = (v === "24"); Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.cornerRadius
                Controls.Slider_ {
                    from: 0; to: 34; step: 1; suffix: " px"
                    value: win.c.islandRadius ?? 22
                    onMoved: (v) => { win.c.islandRadius = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.collapsedWidth
                Controls.Slider_ {
                    from: 220; to: 620; step: 5; suffix: " px"
                    value: win.c.islandCollapsedWidth ?? 410
                    onMoved: (v) => { win.c.islandCollapsedWidth = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.expandedWidth
                Controls.Slider_ {
                    from: 320; to: 720; step: 5; suffix: " px"
                    value: win.c.islandExpandedWidth ?? 425
                    onMoved: (v) => { win.c.islandExpandedWidth = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.collapsedHeight
                Controls.Slider_ {
                    from: 26; to: 60; step: 1; suffix: " px"
                    value: win.c.islandCollapsedHeight ?? 38
                    onMoved: (v) => { win.c.islandCollapsedHeight = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.detached
                hint: I18n.t.detachedHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.islandFloating ?? false
                    onToggled: (v) => { win.c.islandFloating = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.topGap
                visible: win.c.islandFloating ?? false
                Controls.Slider_ {
                    from: 0; to: 40; step: 1; suffix: " px"
                    value: win.c.islandMargin ?? 8
                    onMoved: (v) => { win.c.islandMargin = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.autoHide
                hint: I18n.t.autoHideIslandHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.islandAutoHide ?? false
                    onToggled: (v) => { win.c.islandAutoHide = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.hideDelay
                visible: win.c.islandAutoHide ?? false
                Controls.Slider_ {
                    from: 200; to: 2000; step: 50; suffix: " ms"
                    value: win.c.islandHideDelay ?? 700
                    onMoved: (v) => { win.c.islandHideDelay = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.opacity
                Controls.Slider_ {
                    from: 0.2; to: 1; step: 0.01
                    value: win.c.islandOpacity ?? 1.0
                    onMoved: (v) => { win.c.islandOpacity = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.blur
                hint: I18n.t.blurIslandHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.islandBlur ?? false
                    onToggled: (v) => { win.c.islandBlur = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.islandTint
                Controls.Swatches_ {
                    anchors.right: parent.right
                    colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
                    value: win.c.islandTint ?? "#000000"
                    onPicked: (v) => { win.c.islandTint = v; Config.save(); }
                }
            }

            Item { width: 1; height: 6 }

            // ── NOTIFICATIONS ───────────────────────────────────
            Controls.Section_ { text: I18n.t.notifications }

            Controls.Row_ {
                label: I18n.t.notificationsEnabled
                hint: I18n.t.notificationsEnabledHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.notificationsEnabled ?? true
                    onToggled: (v) => { win.c.notificationsEnabled = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.notificationPeekSeconds
                visible: win.c.notificationsEnabled ?? true
                Controls.Slider_ {
                    from: 2; to: 15; step: 1; suffix: " s"
                    value: win.c.notificationPeekSeconds ?? 5
                    onMoved: (v) => { win.c.notificationPeekSeconds = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.notificationCards
                hint: I18n.t.notificationCardsHint
                visible: win.c.notificationsEnabled ?? true
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.notificationCards ?? true
                    onToggled: (v) => { win.c.notificationCards = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.notificationCardSeconds
                visible: (win.c.notificationsEnabled ?? true)
                         && (win.c.notificationCards ?? true)
                Controls.Slider_ {
                    from: 4; to: 40; step: 1; suffix: " s"
                    value: win.c.notificationCardSeconds ?? 12
                    onMoved: (v) => { win.c.notificationCardSeconds = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.notificationHistory
                visible: win.c.notificationsEnabled ?? true
                Controls.Slider_ {
                    from: 10; to: 200; step: 10
                    value: win.c.notificationHistory ?? 50
                    onMoved: (v) => { win.c.notificationHistory = v; Config.save(); }
                }
            }

            Item { width: 1; height: 6 }

            // ── FOCUS ───────────────────────────────────────────
            Controls.Section_ { text: I18n.t.focus }

            Controls.Row_ {
                label: I18n.t.duration
                hint: I18n.t.durationHint
                Controls.Slider_ {
                    from: 1; to: 120; step: 1; suffix: " min"
                    value: win.c.focusMinutes ?? 25
                    onMoved: (v) => { win.c.focusMinutes = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.chainBreak
                hint: I18n.t.chainBreakHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.focusChain ?? true
                    onToggled: (v) => { win.c.focusChain = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.breakSetting
                visible: win.c.focusChain ?? true
                Controls.Slider_ {
                    from: 1; to: 30; step: 1; suffix: " min"
                    value: win.c.breakMinutes ?? 5
                    onMoved: (v) => { win.c.breakMinutes = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.longBreakSetting
                visible: win.c.focusChain ?? true
                Controls.Slider_ {
                    from: 5; to: 60; step: 5; suffix: " min"
                    value: win.c.longBreakMinutes ?? 15
                    onMoved: (v) => { win.c.longBreakMinutes = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.roundsBeforeLong
                visible: win.c.focusChain ?? true
                Controls.Slider_ {
                    from: 2; to: 8; step: 1
                    value: win.c.focusRounds ?? 4
                    onMoved: (v) => { win.c.focusRounds = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.notifyOnEnd
                hint: I18n.t.notifyOnEndHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.focusNotify ?? true
                    onToggled: (v) => { win.c.focusNotify = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.silenceWhile
                hint: I18n.t.silenceWhileHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.focusInhibit ?? true
                    onToggled: (v) => { win.c.focusInhibit = v; Config.save(); }
                }
            }

            // ── WEATHER ─────────────────────────────────────────
            Controls.Section_ { text: I18n.t.secWeather }

            Controls.Row_ {
                label: I18n.t.showWeather
                hint: I18n.t.showWeatherHint
                Controls.Toggle_ {
                    anchors.right: parent.right
                    checked: win.c.weatherEnabled ?? true
                    onToggled: (v) => { win.c.weatherEnabled = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.whatShows
                visible: win.c.weatherEnabled ?? true
                Controls.Choice_ {
                    options: [{value: "both", label: I18n.t.both},
                              {value: "icon", label: I18n.t.iconOnly},
                              {value: "temp", label: I18n.t.degreesOnly}]
                    value: {
                        const i = win.c.weatherShowIcon ?? true;
                        const t = win.c.weatherShowTemp ?? true;
                        return (i && t) ? "both" : (i ? "icon" : "temp");
                    }
                    onPicked: (v) => {
                        win.c.weatherShowIcon = (v !== "temp");
                        win.c.weatherShowTemp = (v !== "icon");
                        Config.save();
                    }
                }
            }

            Controls.Row_ {
                label: I18n.t.provider
                hint: I18n.t.providerHint
                visible: win.c.weatherEnabled ?? true
                Controls.Choice_ {
                    options: [{value: "bbc", label: "BBC"},
                              {value: "openmeteo", label: "Open-Meteo"}]
                    value: win.c.weatherProvider ?? "bbc"
                    onPicked: (v) => { win.c.weatherProvider = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.source
                hint: I18n.t.sourceHint
                visible: win.c.weatherEnabled ?? true
                Controls.Choice_ {
                    options: [{value: "best_match",    label: I18n.t.autoSource},
                              {value: "ukmo_seamless", label: "Met Office"},
                              {value: "ecmwf_ifs025",  label: "ECMWF"}]
                    value: win.c.weatherModel ?? "best_match"
                    onPicked: (v) => { win.c.weatherModel = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.units
                visible: win.c.weatherEnabled ?? true
                Controls.Choice_ {
                    options: [{value: "c", label: "°C"}, {value: "f", label: "°F"}]
                    value: (win.c.weatherFahrenheit ?? false) ? "f" : "c"
                    onPicked: (v) => { win.c.weatherFahrenheit = (v === "f"); Config.save(); }
                }
            }

            Controls.Section_ {
                text: I18n.t.secLocation
                visible: win.c.weatherEnabled ?? true
            }

            PlacePicker {
                width: parent.width
                visible: win.c.weatherEnabled ?? true
                topPadding: 4
            }

            Controls.Row_ {
                label: I18n.t.inheritPlasma
                hint: I18n.t.inheritPlasmaHint
                visible: win.c.weatherEnabled ?? true
                Controls.Button_ {
                    anchors.right: parent.right
                    label: I18n.t.import
                    onTriggered: { win.c.weatherLat = 0; Weather.importFromPlasma(); }
                }
            }

            Item { width: 1; height: 6 }

            // ── LANGUAGE ────────────────────────────────────────
            Controls.Section_ { text: I18n.t.secLanguage }

            Controls.Row_ {
                label: I18n.t.language
                hint: I18n.t.languageHint
                Controls.Choice_ {
                    options: I18n.available.map(
                        l => ({ value: l.code, label: l.label }))
                    value: win.c.language ?? "auto"
                    onPicked: (v) => { win.c.language = v; Config.save(); }
                }
            }

            Item { width: 1; height: 6 }

            // ── COLOUR ──────────────────────────────────────────
            Controls.Section_ { text: I18n.t.secColour }

            Controls.Row_ {
                label: I18n.t.accent
                hint: I18n.t.accentHint
                Controls.Swatches_ {
                    anchors.right: parent.right
                    colors: ["#a78bfa", "#60a5fa", "#34d399", "#fbbf24", "#f87171", "#ffffff"]
                    value: win.c.accent ?? "#a78bfa"
                    onPicked: (v) => { win.c.accent = v; Config.save(); }
                }
            }

            Controls.Row_ {
                label: I18n.t.dockTint
                Controls.Swatches_ {
                    anchors.right: parent.right
                    colors: ["#000000", "#12121a", "#1a1410", "#101a14", "#181818"]
                    value: win.c.dockTint ?? "#000000"
                    onPicked: (v) => { win.c.dockTint = v; Config.save(); }
                }
            }

            Item { width: 1; height: 18 }

            Text {
                text: I18n.t.settingsPath + Config.path
                color: Theme.textTertiary
                font.pixelSize: 10
            }
        }
    }
}
