import QtQuick
import "../services"

// One dot per mode; the active one stretches rather than just
// lighting up.
Row {
    id: root
    property int count: 4
    property int current: 0
    signal picked(int index)

    spacing: 4

    Repeater {
        model: root.count

        // Every dot is clickable: the wheel is fine but you have to
        // guess it's there, whereas a dot looks pressable.
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
                    : (hover.hovered ? Theme.textSecondary : Theme.textTertiary)

                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation  { duration: Theme.fadeDuration } }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.picked(index)
            }
        }
    }
}
