import QtQuick
import Quickshell.Widgets
import "../services"

// Album art with rounded corners and a placeholder when there's none.
ClippingRectangle {
    id: root
    property string source: ""
    color: "#1c1c1c"

    Image {
        anchors.fill: parent
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: root.source === "" || parent.children[0].status !== Image.Ready
        text: "♪"
        color: Theme.textTertiary
        font.pixelSize: Math.max(10, root.height * 0.35)
    }
}
