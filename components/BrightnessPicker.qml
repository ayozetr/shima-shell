import QtQuick
import "../services"

// One bar per screen, unfolded from the brightness row.
Column {
    id: root
    spacing: 6

    signal closed()

    // The row that opened this list is hidden while it is up, so the
    // way back has to live here.
    Item {
        width: root.width
        height: 20

        ControlGlyph {
            id: back
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 11; height: 11
            kind: "back"
            fill: head.containsMouse ? Theme.textPrimary : Theme.textTertiary
            Behavior on fill { ColorAnimation { duration: Theme.hoverDuration } }
        }

        Text {
            anchors.left: back.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t.screens
            color: head.containsMouse ? Theme.textPrimary : Theme.textTertiary
            font.pixelSize: 10
            font.letterSpacing: 0.6
            Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
        }

        MouseArea {
            id: head
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closed()
        }
    }

    Repeater {
        model: Brightness.displays

        Item {
            required property var modelData
            required property int index

            width: root.width
            height: 34

            Text {
                id: name
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 104
                text: Brightness.labelFor(modelData)
                color: Theme.textSecondary
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            LevelSlider {
                anchors.left: name.right
                anchors.leftMargin: 10
                anchors.right: value.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                value: Brightness.levelFor(modelData.path)
                onMoved: (v) => Brightness.setRatioFor(modelData.path, Math.max(0.05, v))
            }

            Text {
                id: value
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 34
                horizontalAlignment: Text.AlignRight
                text: Math.round(Brightness.levelFor(modelData.path) * 100) + "%"
                color: Theme.textSecondary
                font.pixelSize: 11
            }
        }
    }
}
