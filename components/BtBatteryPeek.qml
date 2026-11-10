import QtQuick
import "../services"

// What an opened earbud case holds out on the island: the name of the
// device and the battery of the left bud, the right bud and the case,
// for a few seconds. A tap sends it away early.
Item {
    id: root

    property var entry: null   // { name, left, right, caseLevel }
    signal dismissed()

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Text {
            width: parent.width
            text: root.entry ? root.entry.name : ""
            color: Theme.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Row {
            width: parent.width
            spacing: 10

            // The case in the middle, between the two buds, the way
            // they sit in it.
            Cell {
                width: (parent.width - 20) / 3
                label: I18n.t.fpLeft
                level: root.entry ? root.entry.left : -1
            }
            Cell {
                width: (parent.width - 20) / 3
                label: I18n.t.fpCase
                level: root.entry ? root.entry.caseLevel : -1
            }
            Cell {
                width: (parent.width - 20) / 3
                label: I18n.t.fpRight
                level: root.entry ? root.entry.right : -1
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dismissed()
    }

    // One reading: a word, a bar filled to the charge, and the figure.
    // A side with nothing in it reports -1 and is drawn empty with a
    // dash, rather than guessed at.
    component Cell: Column {
        property string label: ""
        property int level: -1
        readonly property bool known: level >= 0
        spacing: 3

        Text {
            text: parent.label
            color: Theme.textTertiary
            font.pixelSize: 10
            font.letterSpacing: 0.4
        }

        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: "#22ffffff"

            Rectangle {
                width: parent.width * (parent.parent.known
                    ? Math.max(0, Math.min(100, parent.parent.level)) / 100 : 0)
                height: parent.height
                radius: 3
                // Red near empty, so a case about to die reads at a
                // glance; the accent otherwise.
                color: parent.parent.level <= 20 ? Theme.urgent : Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.fadeDuration } }
            }
        }

        Text {
            text: parent.known ? parent.level + "%" : "–"
            color: parent.known ? Theme.textSecondary : Theme.textTertiary
            font.pixelSize: 11
        }
    }
}
