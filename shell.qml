//@ pragma UseQApplication
// Quickshell starts without KDE's platform integration, so Qt falls
// back to the "hicolor" theme and only finds icons that live there.
// The launcher script keeps this line in sync with the real theme.
//@ pragma IconTheme Papirus
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
        Brightness.available;
        NightLight.available;
        // The notification server has to be up before anything is
        // sent, not when the history is first opened.
        Notifications.enabled;
        Places.entries.length;
        // The tray needs to register as a host and wait for the items
        // to answer; woken late it reports an empty tray for seconds.
        SystemTray.items.values.length;
    }

    // A single settings window, not one per screen.
    Settings {}
}
