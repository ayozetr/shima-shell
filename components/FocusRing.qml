import QtQuick
import "../services"

// The ring that marks what the keyboard is on.
//
// A file of its own, and not an inline component inside Controls.qml
// as it used to be. An inline component that uses another inline
// component from the same file is fine on Qt 6.10 and 6.11, and on
// Qt 6.8 — Debian 13 — Qt segfaults while building it and takes the
// shell down. Here it is an ordinary type and that nesting is gone.
Rectangle {
    property Item around: null
    anchors.fill: parent
    anchors.margins: -4
    radius: (parent && parent.radius !== undefined ? parent.radius : 6) + 4
    color: "transparent"
    border.width: 2
    border.color: Theme.accent
    visible: opacity > 0
    opacity: (around && around.activeFocus) ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 110 } }
}
