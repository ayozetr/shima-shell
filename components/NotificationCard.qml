import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// A notification that waits for you instead of passing by.
Rectangle {
    id: root

    property var entry: null
    signal closed()

    readonly property bool critical: root.entry && root.entry.urgency === 2
    readonly property var buttons: root.entry ? Notifications.buttonsOf(root.entry) : []
    readonly property string picture: root.entry ? (root.entry.image || "") : ""

    width: 340
    implicitHeight: body.implicitHeight + 24
    radius: 16
    color: Theme.islandBg
    border.width: 1
    border.color: root.critical ? Theme.urgent : Theme.islandBorder

    // Critical ones stay until they are dealt with. The rest give you
    // longer than the island does, because a card asks for a decision
    // and a decision takes reading.
    Timer {
        id: life
        interval: (Config.data.notificationCardSeconds ?? 12) * 1000
        running: !root.critical && !hover.hovered
        onTriggered: root.closed()
    }

    HoverHandler { id: hover }

    Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 8

        Item {
            width: parent.width
            height: 26

            Item {
                id: art
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22

                NotificationIcon {
                    anchors.fill: parent
                    entry: root.entry
                    radius: 7
                    iconScale: 0.68
                }
            }

            Text {
                anchors.left: art.right
                anchors.leftMargin: 8
                anchors.right: shut.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.entry ? root.entry.appName : ""
                color: Theme.textTertiary
                font.pixelSize: 10
                font.letterSpacing: 0.4
                elide: Text.ElideRight
            }

            Item {
                id: shut
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = shutArea.containsMouse
                            ? Theme.textPrimary : Theme.textTertiary;
                        ctx.lineWidth = 1.5;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.moveTo(width * 0.28, height * 0.28);
                        ctx.lineTo(width * 0.72, height * 0.72);
                        ctx.moveTo(width * 0.72, height * 0.28);
                        ctx.lineTo(width * 0.28, height * 0.72);
                        ctx.stroke();
                    }
                    Connections {
                        target: shutArea
                        function onContainsMouseChanged() { parent.requestPaint(); }
                    }
                }

                MouseArea {
                    id: shutArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closed()
                }
            }
        }

        Text {
            width: parent.width
            text: root.entry ? root.entry.summary : ""
            color: Theme.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            visible: text !== ""
        }

        Text {
            width: parent.width
            // A card has room for markup the island does not, so links
            // and emphasis survive; images in the body do not, and
            // would stretch the card to whatever the sender felt like.
            text: root.entry ? root.entry.body.replace(/<img[^>]*>/g, "") : ""
            color: Theme.textSecondary
            font.pixelSize: 11
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: 6
            elide: Text.ElideRight
            visible: text !== ""
            onLinkActivated: (link) => Qt.openUrlExternally(link)
        }

        Row {
            anchors.right: parent.right
            spacing: 8
            visible: root.buttons.length > 0
            topPadding: 2

            Repeater {
                model: root.buttons

                Rectangle {
                    required property var modelData

                    height: 26
                    width: Math.max(64, label.implicitWidth + 22)
                    radius: 8
                    color: press.containsMouse ? Theme.accent : "#1affffff"
                    Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.text
                        color: press.containsMouse ? Theme.accentText : Theme.textPrimary
                        font.pixelSize: 11
                    }

                    MouseArea {
                        id: press
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Notifications.invoke(root.entry.id, modelData.index);
                            root.closed();
                        }
                    }
                }
            }
        }
    }

    // A click on the card itself runs the default action, same as in
    // the island.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        z: -1
        onClicked: (e) => {
            if (e.button === Qt.MiddleButton) { root.closed(); return; }
            if (root.entry && root.entry.actionCount > root.buttons.length)
                Notifications.invoke(root.entry.id, 0);
            root.closed();
        }
    }
}
