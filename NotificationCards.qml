import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"
import "components"

// Where cards stack up, out of the island's way.
PanelWindow {
    id: win

    property string screenName: ""

    anchors.top: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "shima-notifications"
    color: "transparent"

    // Only on the screens the island is on: the cards belong to it.
    visible: (Config.data.notificationsEnabled ?? true)
             && (Config.data.notificationCards ?? true)
             && Config.onScreen(Config.data.islandScreens, win.screenName)

    // Fixed and roomy, with the mask deciding what takes the mouse.
    // Resizing a layer-shell surface as cards come and go stutters.
    implicitWidth: 380
    implicitHeight: 700

    mask: Region { item: stack }

    Column {
        id: stack
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.top: parent.top
        // Clear of the island, which lives at the top centre.
        anchors.topMargin: 14
        width: 340
        spacing: 10

        Repeater {
            model: Notifications.cards

            NotificationCard {
                required property var modelData
                required property int index

                entry: modelData
                onClosed: Notifications.closeCard(modelData.key)

                // In from the edge they are pinned to.
                opacity: 0
                x: 40
                Component.onCompleted: { opacity = 1; x = 0; }
                Behavior on opacity { NumberAnimation { duration: 220 } }
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
        }
    }
}
