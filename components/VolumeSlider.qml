import QtQuick
import "../services"

// Volume bar: thickens when the mouse hovers over it.
Item {
    id: root
    property real value: 0
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
            color: Theme.trackFill
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
