import QtQuick
import "../services"

// The five bars reacting to the audio.
Row {
    id: root
    property int barCount: 5
    property real barWidth: 3
    property real maxHeight: 18
    property color barColor: Theme.textPrimary

    spacing: 2.5
    height: maxHeight

    Repeater {
        model: root.barCount
        Rectangle {
            width: root.barWidth
            radius: root.barWidth / 2
            color: root.barColor
            // Never completely flat: a bar at zero looks broken.
            height: Math.max(3, (Cava.levels[index] ?? 0) * root.maxHeight)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
        }
    }
}
