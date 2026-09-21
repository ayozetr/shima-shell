import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// What came in while you were looking somewhere else.
Item {
    id: root

    readonly property int preferredHeight: 186

    Item {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 18

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t.notifications
            color: Theme.textTertiary
            font.pixelSize: 10
            font.letterSpacing: 0.6
        }

        // Both on the right: silence first, then empty. Icons rather
        // than words, because two labels beside the heading read as a
        // sentence.
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            ControlGlyph {
                width: 13; height: 13
                anchors.verticalCenter: parent.verticalCenter
                kind: Notifications.quiet ? "bellOff" : "bell"
                fill: Notifications.quiet ? Theme.accent
                    : (quietArea.containsMouse ? Theme.textPrimary : Theme.textTertiary)
                Behavior on fill { ColorAnimation { duration: Theme.hoverDuration } }

                MouseArea {
                    id: quietArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.toggleQuiet()
                }

                ToolTipLabel {
                    show: quietArea.containsMouse
                    text: I18n.t.doNotDisturb
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    z: 30
                }
            }

            ControlGlyph {
                width: 13; height: 13
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifications.items.length > 0
                kind: "trash"
                fill: clearArea.containsMouse ? Theme.textPrimary : Theme.textTertiary
                Behavior on fill { ColorAnimation { duration: Theme.hoverDuration } }

                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.clear()
                }

                ToolTipLabel {
                    show: clearArea.containsMouse
                    text: I18n.t.clearAll
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    z: 30
                }
            }
        }
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 6
        anchors.bottom: parent.bottom
        clip: true
        spacing: 2
        model: Notifications.items
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            required property var modelData
            required property int index

            width: list.width
            height: 54
            radius: 10
            color: rowArea.containsMouse ? "#14ffffff" : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

            Item {
                id: art
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 28; height: 28

                NotificationIcon {
                    anchors.fill: parent
                    entry: modelData
                    radius: 8
                }

                Rectangle {
                    visible: modelData.urgency === 2
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: -1
                    width: 8; height: 8; radius: 4
                    color: Theme.urgent
                    border.width: 2
                    border.color: Theme.islandBg
                }
            }

            Column {
                anchors.left: art.right
                anchors.leftMargin: 10
                anchors.right: drop.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: modelData.appName + " · " + Notifications.ago(modelData.time)
                    color: Theme.textTertiary
                    font.pixelSize: 9
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: modelData.summary
                    color: Theme.textPrimary
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    visible: text !== ""
                }

                Text {
                    width: parent.width
                    text: modelData.body.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim()
                    color: Theme.textSecondary
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }

            // Only there under the pointer: a row of crosses down the
            // side turns a list you glance at into a form you read.
            Item {
                id: drop
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                opacity: rowArea.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.hoverDuration } }

                Canvas {
                    anchors.fill: parent
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = dropArea.containsMouse
                            ? Theme.textPrimary : Theme.textTertiary;
                        ctx.lineWidth = 1.5;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.moveTo(width * 0.30, height * 0.30);
                        ctx.lineTo(width * 0.70, height * 0.70);
                        ctx.moveTo(width * 0.70, height * 0.30);
                        ctx.lineTo(width * 0.30, height * 0.70);
                        ctx.stroke();
                    }
                    Connections {
                        target: dropArea
                        function onContainsMouseChanged() { parent.requestPaint(); }
                    }
                }

                MouseArea {
                    id: dropArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.remove(modelData.key)
                }
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                z: -1
                onClicked: (e) => {
                    if (e.button === Qt.MiddleButton) {
                        Notifications.remove(modelData.key);
                    } else if (modelData.actionCount > 0) {
                        Notifications.invoke(modelData.id, 0);
                        Notifications.remove(modelData.key);
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: list
        visible: Notifications.items.length === 0
        text: I18n.t.noNotifications
        color: Theme.textTertiary
        font.pixelSize: 11
    }
}
