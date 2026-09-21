import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// The face of a notification, in order of preference: the picture it
// carried, the sending application's icon, or its initial.
//
// The last one matters more than it sounds. A name like "KDE" is not
// an application and resolves to nothing, and iconPath hands back a
// URL either way — so without a fallback the square is simply empty.
Item {
    id: root

    property var entry: null
    property int radius: 8
    property real iconScale: 0.6

    readonly property string picture: root.entry ? (root.entry.image || "") : ""
    readonly property string iconName: root.entry ? (root.entry.icon || "") : ""
    readonly property string initial: {
        const name = root.entry ? (root.entry.appName || root.entry.summary || "") : "";
        return name.length > 0 ? name.charAt(0).toUpperCase() : "";
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "#1affffff"

        Image {
            id: shot
            anchors.fill: parent
            source: root.picture
            visible: root.picture !== "" && status === Image.Ready
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        IconImage {
            id: glyph
            anchors.centerIn: parent
            width: Math.round(root.width * root.iconScale)
            height: width
            source: (!shot.visible && root.iconName !== "")
                ? Quickshell.iconPath(root.iconName) : ""
            visible: root.iconName !== "" && !shot.visible && status === Image.Ready
            asynchronous: true
        }

        Text {
            anchors.centerIn: parent
            visible: !shot.visible && !glyph.visible
            text: root.initial
            color: Theme.textSecondary
            font.pixelSize: Math.round(root.height * 0.46)
            font.weight: Font.DemiBold
        }
    }
}
