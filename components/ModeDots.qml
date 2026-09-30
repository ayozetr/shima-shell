import QtQuick
import "../services"

// One dot per mode; the active one stretches rather than just
// lighting up.
//
// The whole row takes the click, not each dot. A dot is four pixels
// wide with four more to the next one, which is a target you have to
// aim at — and the two obvious answers both failed when they were
// tried: giving each dot the full step left them ten pixels apart and
// looked worse than the thing it fixed, and closing the gap to zero
// was no better. The target and the spacing are the same measurement,
// so nothing that widens one leaves the other alone.
//
// So the drawing is left exactly as it was and the aiming is dropped
// instead: a press anywhere along the row — on a dot, in a gap, above
// or below — takes the nearest dot. The target goes from four pixels
// to the whole strip without moving anything by one.
Row {
    id: root
    property int count: 4
    property int current: 0
    signal picked(int index)

    spacing: 4

    // Which dot is nearest a point along the row. Worked out from the
    // dots themselves rather than from the arithmetic, because they
    // are not evenly spaced: the active one is ten wide and the rest
    // are four, so the middles move as the mode changes.
    function nearest(x) {
        let best = 0;
        let closest = Infinity;
        for (let i = 0; i < root.count; i++) {
            const it = dots.itemAt(i);
            if (!it) continue;
            const away = Math.abs(it.x + it.width / 2 - x);
            if (away < closest) { closest = away; best = i; }
        }
        return best;
    }

    // What the pointer is over, by the same reckoning as the press, so
    // what lights up is what a click would take. -1 is nothing.
    property int hovered: -1

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
        onPointChanged: root.hovered = hover.hovered
            ? root.nearest(hover.point.position.x) : -1
        onHoveredChanged: if (!hover.hovered) root.hovered = -1
    }

    TapHandler {
        onTapped: (point) => root.picked(root.nearest(point.position.x))
    }

    Repeater {
        id: dots
        model: root.count

        Item {
            width: dot.width
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: dot
                anchors.centerIn: parent
                width: index === root.current ? 10 : 4
                height: 4
                radius: 2
                color: index === root.current
                    ? Theme.textSecondary
                    : (index === root.hovered ? Theme.textSecondary
                                              : Theme.textTertiary)

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: Theme.fadeDuration } }
            }
        }
    }
}
