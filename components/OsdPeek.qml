import QtQuick
import "../services"

// The volume (and, later, brightness) flashing across the island as you
// change it: an icon, a bar filled to the level, and the figure.
Item {
    id: root

    property var entry: null   // { kind, value, muted }
    signal dismissed()

    readonly property string kind: root.entry ? (root.entry.kind ?? "volume") : "volume"
    readonly property bool muted: root.entry ? (root.entry.muted ?? false) : false
    readonly property real value: root.entry ? root.entry.value : 0

    Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        // A speaker for volume, the sun for brightness.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18

            Glyph {
                anchors.fill: parent
                visible: root.kind === "volume"
                kind: root.muted ? "speakerOff" : "speakerOn"
                fill: root.muted ? Theme.textTertiary : Theme.textPrimary
            }
            ControlGlyph {
                anchors.fill: parent
                visible: root.kind === "brightness"
                kind: "brightness"
                fill: Theme.textPrimary
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 18 - 44 - 28
            height: 6
            radius: 3
            color: "#22ffffff"

            Rectangle {
                // No width animation: the bar should be at the level the
                // moment it appears, not fill up to it from nothing,
                // which reads as the display being slow to catch up.
                width: parent.width * Math.max(0, Math.min(1, root.value))
                height: parent.height
                radius: 3
                color: root.muted ? Theme.textTertiary : Theme.accent
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.value * 100) + "%"
            color: root.muted ? Theme.textTertiary : Theme.textSecondary
            font.pixelSize: 13
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }
}
