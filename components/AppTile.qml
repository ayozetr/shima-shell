import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// One application in the launcher grid.
Item {
    id: root
    property var entry: null
    signal launched()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 12
        color: ma.containsMouse ? "#1affffff" : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        IconImage {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10
            width: 40; height: 40
            source: (root.entry && root.entry.icon)
                ? Quickshell.iconPath(root.entry.icon, "application-x-executable")
                : ""
            asynchronous: true
            scale: ma.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.top: icon.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            horizontalAlignment: Text.AlignHCenter
            text: root.entry ? root.entry.name : ""
            color: Theme.textSecondary
            font.pixelSize: 11
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (e) => {
            if (!root.entry) return;
            if (e.button === Qt.RightButton) {
                // Pinning to the dock is the most common thing asked
                // for from here.
                Apps.pin(root.entry.id);
                return;
            }
            root.entry.execute();
            root.launched();
        }
    }

    ToolTipLabel {
        show: ma.containsMouse && root.entry && root.entry.comment
        text: root.entry ? root.entry.comment : ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 2
        z: 20
    }
}
