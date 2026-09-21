import QtQuick
import "../services"

// The chevron that folds the tray away, the way Plasma's own arrow
// does. It turns to point the other way once the tray is out.
Item {
    id: root
    property bool expanded: false
    signal toggled()

    readonly property int side: Math.round(Theme.dockIconSize * 0.62)

    width: Math.round(side * 0.62)
    height: Theme.dockIconSize + Theme.dockDotLane

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round((Theme.dockIconSize - root.side) / 2)
        width: root.side * 0.7
        height: root.side
        radius: Math.round(root.side * 0.3)
        color: ma.containsMouse ? "#1affffff" : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Canvas {
            id: chevron
            anchors.centerIn: parent
            width: 11; height: 11

            // Pointing left means "there is more this way"; once open it
            // points right, towards where things would fold back into.
            rotation: root.expanded ? 180 : 0
            Behavior on rotation {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            property color stroke: ma.containsMouse
                ? Theme.textPrimary : Theme.textSecondary
            onStrokeChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = chevron.stroke;
                ctx.lineWidth = 1.6;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();
                ctx.moveTo(width * 0.66, height * 0.18);
                ctx.lineTo(width * 0.34, height * 0.5);
                ctx.lineTo(width * 0.66, height * 0.82);
                ctx.stroke();
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
