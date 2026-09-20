//@ pragma UseQApplication
// Quickshell starts without KDE's platform integration, so Qt falls
// back to the "hicolor" theme and only finds icons that live there.
// The launcher script keeps this line in sync with the real theme.
//@ pragma IconTheme Papirus
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

    // A single settings window, not one per screen.
    Settings {}
}
