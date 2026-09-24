// The shell itself. It carries no pragmas, because those only take
// effect on the file Quickshell is pointed at, and that file is
// generated per user — see the `shima` launcher script. Everything
// else lives here so that there is one copy of it.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "services"

ShellRoot {
    // Created on every screen, and each one decides whether to show
    // itself. Filtering the Variants model does not work: recomputing
    // it destroys the old windows but never creates the new ones.
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            required property var modelData
            // The screen name is handed down rather than read back
            // from the window: reading window.screen inside `visible`
            // is a binding loop, because hiding a window clears it.
            Island      { screen: modelData; screenName: modelData.name }
            Dock        { screen: modelData; screenName: modelData.name }
            AppLauncher { screen: modelData; screenName: modelData.name }
            NotificationCards { screen: modelData; screenName: modelData.name }
        }
    }

    // QML singletons are lazy: they are born on first use. Left alone,
    // Audio would only wake up when the island is expanded, by which
    // point PipeWire has not resolved the default sink yet and the
    // volume slider does nothing. Weather and Apps are woken here for
    // the same reason: their first fetch should start with the shell,
    // not with the first glance at them.
    Component.onCompleted: {
        Audio.ready;
        Weather.ready;
        Apps.revision;
        // The window sweep and the dock's own row. Both used to live
        // inside Apps and were woken by the line above; now that they
        // are their own, nothing would touch them until something
        // drew a dock icon — and the sweep is what says which icons
        // there are, so that is a shell that starts by watching
        // nothing at all.
        Windows.probeDone;
        Pinned.items.length;
        // Reading KDE's menu takes some 45 ms, and the launcher's
        // sidebar is built out of it: done on the first open, the
        // categories arrive after the window does.
        Menu.hasMenu;
        Brightness.available;
        NightLight.available;
        // The notification server has to be up before anything is
        // sent, not when the history is first opened.
        Notifications.enabled;
        Places.entries.length;
        Power.available;
        // Its can* properties are answered by logind asynchronously,
        // so a menu opened before that lands would hide entries that
        // do work.
        Session.canShutdown;
        // Nothing watches the clipboard until this singleton exists,
        // so left alone it only started recording when something first
        // read it — opening the launcher, usually, minutes in. What
        // you copied before that was gone.
        Clipboard.available;
        // The tray needs to register as a host and wait for the items
        // to answer; woken late it reports an empty tray for seconds.
        SystemTray.items.values.length;
    }

    // A single settings window, not one per screen.
    Settings {}
}
