//@ pragma UseQApplication
// Quickshell starts without KDE's platform integration, so Qt falls
// back to the "hicolor" theme and only finds icons that live there.
// The launcher script keeps this line in sync with the real theme.
//@ pragma IconTheme Papirus
import QtQuick
import Quickshell
import "services"

ShellRoot {
    // Created on every screen, and each one decides whether to show
    // itself. Filtering the Variants model does not work: recomputing
    // it destroys the old windows but never creates the new ones.
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            required property var modelData
            Island      { screen: modelData }
            Dock        { screen: modelData }
            AppLauncher { screen: modelData }
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
    }

    // A single settings window, not one per screen.
    Settings {}
}
