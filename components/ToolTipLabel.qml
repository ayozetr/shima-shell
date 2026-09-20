import QtQuick
import "../services"

// Floating label with the app's name.
Rectangle {
    id: root
    property string text: ""

    width: label.implicitWidth + 16
    height: label.implicitHeight + 8
    radius: 8
    color: "#f0000000"
    border.width: 1
    border.color: Theme.islandBorder

    // Appearing and disappearing animate through opacity; binding
    // visible straight to the hover would skip the transition.
    property bool show: false
    visible: opacity > 0
    opacity: show ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.hoverDuration } }

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.textPrimary
        font.pixelSize: 11
    }
}
