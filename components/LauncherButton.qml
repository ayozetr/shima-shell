import QtQuick
import "../services"

// The launcher button, on the left of the dock.
Item {
    id: root
    property var dockWindow: null

    width: Theme.dockIconSize
    height: Theme.dockIconSize + Theme.dockDotLane

    Rectangle {
        id: tile
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Theme.dockIconSize
        height: Theme.dockIconSize
        radius: Theme.dockIconRadius

        gradient: Gradient {
            GradientStop {
                position: 0.0
                color: LauncherState.open ? Theme.accentSoft : Theme.iconTop
            }
            GradientStop { position: 1.0; color: Theme.iconBottom }
        }
        border.width: 1
        border.color: LauncherState.open ? Theme.accent : Theme.iconBorder
        Behavior on border.color { ColorAnimation { duration: Theme.hoverDuration } }

        scale: ma.pressed ? 0.92 : 1
        transformOrigin: Item.Bottom
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // Four squares: the "all applications" symbol without
        // depending on any icon theme.
        Grid {
            anchors.centerIn: parent
            columns: 2
            spacing: 4
            Repeater {
                model: 4
                Rectangle {
                    width: 8; height: 8; radius: 2.5
                    color: Theme.textPrimary
                    opacity: LauncherState.open ? 1 : 0.85
                }
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // Any open icon menu goes away with it.
            if (root.dockWindow) root.dockWindow.menu.hide();
            LauncherState.toggle();
        }
    }

    ToolTipLabel {
        show: ma.containsMouse && !LauncherState.open
              && (Config.data.showAppNames ?? true)
              && !(root.dockWindow && root.dockWindow.popupOpen)
        text: I18n.t.applications
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 10
    }
}
