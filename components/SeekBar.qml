import QtQuick
import "../services"

// Where you are in what is playing.
//
// It takes seconds and gives back seconds; whether the player will
// listen is the caller's business, and `interactive` is how it says
// so. A bar that can be dragged and does nothing is worse than one
// that plainly cannot.
Item {
    id: root
    property real position: 0
    property real length: 0
    property bool interactive: false
    signal sought(real seconds)

    implicitHeight: 14

    readonly property real ratio:
        root.length > 0 ? Math.max(0, Math.min(1, root.position / root.length)) : 0

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: (root.interactive && (mouse.containsMouse || mouse.pressed)) ? 6 : 4
        radius: height / 2
        color: Theme.trackBg
        Behavior on height {
            NumberAnimation { duration: Theme.hoverDuration; easing.type: Easing.OutCubic }
        }

        Rectangle {
            width: root.ratio * parent.width
            height: parent.height
            radius: parent.radius
            color: Theme.trackFill
        }

        // Only where you can do something with it: a handle on a bar
        // that does not move is a promise nobody keeps.
        Rectangle {
            visible: root.interactive
            x: root.ratio * parent.width - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 10; height: 10; radius: 5
            color: "#ffffff"
            opacity: mouse.containsMouse || mouse.pressed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.hoverDuration } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.interactive && root.length > 0
        hoverEnabled: enabled
        cursorShape: Qt.PointingHandCursor
        // No wheel handling on purpose: the wheel over the island
        // changes what the island is showing, and a bar that ate it
        // would make the panel a place the wheel dies in.
        function scrub(x) {
            root.sought(Math.max(0, Math.min(1, x / width)) * root.length);
        }
        onPressed: (e) => scrub(e.x)
        onPositionChanged: (e) => { if (pressed) scrub(e.x); }
    }
}
