//@ pragma UseQApplication
// Quickshell starts without KDE's platform integration, so Qt falls
// back to the "hicolor" theme and only finds icons that live there.
// The real theme has to come in through this pragma, which is static
// text, so it cannot simply be read at startup.
//
// This file is the development entry point: `qs -p shell.qml` from a
// checkout. It names a fixed theme, because rewriting it would mean
// writing to the program's own source — which is read-only once the
// thing is installed, and was how the shell used to fail to start at
// all. The `shima` launcher instead generates this same wrapper under
// the user's cache directory with the theme filled in, and points
// Quickshell at that.
//@ pragma IconTheme breeze
import "."

Shima {}
