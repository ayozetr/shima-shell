import QtQuick
import "../services"

// Transport button: the icon gives a little on press.
Item {
    id: root
    property string kind: "play"
    property int size: 22
    // Not called `enabled`, which every Item already has: a property
    // of that name here hides the one underneath, so a button set as
    // disabled went on taking clicks and Qt said so at every start.
    // What it means is whether there is anything to run.
    property bool available: true
    signal clicked()

    implicitWidth: size
    implicitHeight: size

    Glyph {
        id: glyph
        anchors.centerIn: parent
        width: root.size
        height: root.size
        fill: Theme.textPrimary
        opacity: root.available ? (mouse.containsMouse ? 1 : 0.9) : 0.3
        scale: mouse.pressed ? 0.86 : 1
        kind: root.kind

        Behavior on opacity { NumberAnimation { duration: Theme.hoverDuration } }
        Behavior on scale   { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: root.available ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.available) root.clicked()
    }
}
