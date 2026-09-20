import QtQuick
import "../services"

// Transport button: the icon gives a little on press.
Item {
    id: root
    property string kind: "play"
    property int size: 22
    property bool enabled: true
    signal clicked()

    implicitWidth: size
    implicitHeight: size

    Glyph {
        id: glyph
        anchors.centerIn: parent
        width: root.size
        height: root.size
        fill: Theme.textPrimary
        opacity: root.enabled ? (mouse.containsMouse ? 1 : 0.9) : 0.3
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
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
