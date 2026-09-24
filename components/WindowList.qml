import QtQuick
import "../services"

// The windows of an application, offered by title. Opened with a
// middle click on its dock icon, for when stepping through them one by
// one is slower than just picking the one you want.
Rectangle {
    id: root
    property string appId: ""
    property string appName: ""
    property bool open: false
    signal closeRequested()

    readonly property var windows: Windows.forAppId === root.appId ? Windows.list : []

    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    z: 100

    width: 280
    height: col.height + 10
    radius: 10
    color: "#fa121212"
    border.width: 1
    border.color: "#2a2a2a"

    Behavior on opacity { NumberAnimation { duration: 130 } }
    Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    Column {
        id: col
        y: 5
        width: parent.width
        spacing: 1

        Text {
            x: 10
            width: parent.width - 20
            height: 22
            verticalAlignment: Text.AlignVCenter
            text: root.appName
            color: Theme.textTertiary
            font.pixelSize: 10
            font.bold: true
            elide: Text.ElideRight
        }

        Repeater {
            model: root.windows

            Rectangle {
                required property var modelData
                x: 4
                width: root.width - 8
                height: 28
                radius: 6
                color: ma.containsMouse ? "#1fffffff" : "transparent"

                Rectangle {
                    id: bullet
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5
                    color: "#55ffffff"
                }

                Text {
                    anchors.left: bullet.right
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.title || I18n.t.untitled
                    color: Theme.textPrimary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Windows.activate(modelData.id);
                        root.closeRequested();
                    }
                }
            }
        }

        Text {
            x: 10
            height: 26
            verticalAlignment: Text.AlignVCenter
            visible: root.windows.length === 0
            text: I18n.t.searchingWindows
            color: Theme.textTertiary
            font.pixelSize: 11
        }
    }
}
