import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// A notification taking over the island for a few seconds.
Item {
    id: root

    property var entry: null
    signal activated()
    signal dismissed()

    readonly property bool critical: root.entry && root.entry.urgency === 2

    Item {
        id: art
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 38; height: 38

        NotificationIcon {
            anchors.fill: parent
            entry: root.entry
            radius: 10
            iconScale: 0.58
        }

        // Urgent ones get a mark rather than a different colour scheme:
        // it survives whatever accent the island is wearing.
        Rectangle {
            visible: root.critical
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: -2
            width: 10; height: 10; radius: 5
            color: Theme.urgent
            border.width: 2
            border.color: Theme.islandBg
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.entry ? root.entry.appName : ""
            color: Theme.textTertiary
            font.pixelSize: 10
            font.letterSpacing: 0.4
            elide: Text.ElideRight
            visible: text !== ""
        }

        Text {
            width: parent.width
            text: root.entry ? root.entry.summary : ""
            color: Theme.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            visible: text !== ""
        }

        Text {
            width: parent.width
            // Bodies arrive with markup that the island has no room to
            // render, so it is stripped rather than shown raw.
            text: root.entry ? root.entry.bodyText : ""
            color: Theme.textSecondary
            font.pixelSize: 11
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            visible: text !== ""
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => {
            if (e.button === Qt.MiddleButton) root.dismissed();
            else root.activated();
        }
    }
}
