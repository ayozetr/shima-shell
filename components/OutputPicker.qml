import QtQuick
import "../services"

// The list of audio outputs, unfolded from the control centre.
Column {
    id: root
    spacing: 3

    Repeater {
        model: Audio.outputs

        Rectangle {
            required property var modelData
            readonly property bool current: Audio.sink && modelData.id === Audio.sink.id

            width: root.width
            height: 30
            radius: 8
            color: current ? Theme.accentSoft
                           : (ma.containsMouse ? "#18ffffff" : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }

            // A dot marks the one in use, so the list reads at a glance.
            Rectangle {
                id: bullet
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                color: parent.current ? Theme.accent : "#33ffffff"
            }

            Text {
                anchors.left: bullet.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.labelFor(modelData)
                color: parent.current ? Theme.textPrimary : Theme.textSecondary
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.setOutput(modelData)
            }
        }
    }

    Text {
        visible: Audio.outputs.length === 0
        text: I18n.t.noOutputs
        color: Theme.textTertiary
        font.pixelSize: 11
    }
}
