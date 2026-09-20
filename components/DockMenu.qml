import QtQuick
import "../services"

// Menu for a dock icon. It lives inside the dock's window, so it
// draws over the pill without needing a window of its own.
Rectangle {
    id: root
    property string appId: ""
    property string appName: ""
    property bool open: false
    property bool pinned: true
    signal closeRequested()

    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    z: 100

    width: 152
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
            model: root.pinned
                ? [{ label: "Abrir",            danger: false },
                   { label: "Quitar del dock",  danger: true  }]
                : [{ label: "Abrir",            danger: false },
                   { label: "Anclar al dock",   danger: false }]

            Rectangle {
                required property var modelData
                required property int index

                x: 4
                width: root.width - 8
                height: 26
                radius: 6
                color: ma.containsMouse
                    ? (modelData.danger ? "#33f87171" : "#1fffffff")
                    : "transparent"

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: modelData.danger ? "#f87171" : Theme.textPrimary
                    font.pixelSize: 12
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (index === 0)         Apps.launch(root.appId);
                        else if (root.pinned)    Apps.unpin(root.appId);
                        else                     Apps.pin(root.appId);
                        root.closeRequested();
                    }
                }
            }
        }
    }
}
