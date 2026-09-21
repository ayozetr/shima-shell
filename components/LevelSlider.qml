import QtQuick
import "../services"

// A bar that thickens when the mouse hovers over it. Used for volume
// and for brightness: neither needs a handle, and the fill alone reads
// better at this size.
Item {
    id: root
    property real value: 0
    // Dimmed keeps the bar where it is but stops it looking lit. For
    // volume that means muted, which reads better than dropping to zero
    // and losing where the level actually was.
    property bool dimmed: false
    signal moved(real value)

    implicitHeight: 14

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: mouse.containsMouse || mouse.pressed ? 6 : 4
        radius: height / 2
        color: Theme.trackBg

        Behavior on height { NumberAnimation { duration: Theme.hoverDuration; easing.type: Easing.OutCubic } }

        Rectangle {
            width: Math.max(0, Math.min(1, root.value)) * parent.width
            height: parent.height
            radius: parent.radius
            color: root.dimmed ? Theme.trackMuted : Theme.trackFill
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (e) => root.moved(Math.max(0, Math.min(1, e.x / width)))
        onPositionChanged: (e) => { if (pressed) root.moved(Math.max(0, Math.min(1, e.x / width))); }
        onWheel: (e) => {
            const step = e.angleDelta.y > 0 ? 0.03 : -0.03;
            root.moved(Math.max(0, Math.min(1, root.value + step)));
        }
    }
}
