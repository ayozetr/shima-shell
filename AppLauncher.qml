import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "services"
import "components"

PanelWindow {
    id: win

    // Covers the whole screen while open: that is what lets a click
    // anywhere dismiss it, the way KDE's menu does. Only the panel is
    // drawn; everything else is transparent.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shima-launcher"
    // It needs the keyboard so you can type the moment it opens.
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    color: "transparent"

    visible: LauncherState.open
             && Config.onScreen(Config.data.dockScreens,
                                win.screen ? win.screen.name : "")

    BackgroundEffect.blurRegion: Region { item: panel; radius: 18 }

    readonly property var apps: (Apps.revision, LauncherState.open)
        ? Apps.listApps(LauncherState.category, LauncherState.query)
        : []

    // A click outside the panel closes it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: LauncherState.hide()
    }

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        // Just above the dock, whatever size it happens to be.
        anchors.bottomMargin: Theme.dockIconSize + Theme.dockDotLane
                              + Theme.dockPadding * 2 + 26
        width: 660
        height: 440
        radius: 18
        color: Qt.rgba(0, 0, 0, 0.88)
        border.width: 1
        border.color: "#22ffffff"

        opacity: LauncherState.open ? 1 : 0
        scale: LauncherState.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Keep clicks inside from closing it.
        MouseArea { anchors.fill: parent }

        // ── Search box ───────────────────────────────────────────
        Rectangle {
            id: searchBox
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            height: 38
            radius: 10
            color: "#14ffffff"
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : "#1affffff"

            Text {
                id: magnifier
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: Theme.textTertiary
                font.pixelSize: 18
            }

            TextInput {
                id: search
                anchors.left: magnifier.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textPrimary
                font.pixelSize: 14
                clip: true
                selectByMouse: true
                focus: LauncherState.open

                onTextChanged: LauncherState.query = text

                Keys.onEscapePressed: LauncherState.hide()
                Keys.onReturnPressed: {
                    if (win.apps.length > 0) {
                        win.apps[0].execute();
                        LauncherState.hide();
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: "Buscar aplicaciones…"
                    color: Theme.textTertiary
                    font.pixelSize: 14
                }
            }
        }

        // ── Categories ───────────────────────────────────────────
        Column {
            id: cats
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.top: searchBox.bottom
            anchors.topMargin: 12
            width: 132
            spacing: 2

            Repeater {
                model: Apps.categories

                Rectangle {
                    required property var modelData
                    readonly property int count:
                        (Apps.revision, Apps.categoryCounts()[modelData.id] || 0)

                    visible: count > 0
                    width: parent.width
                    height: visible ? 28 : 0
                    radius: 8
                    color: LauncherState.category === modelData.id
                        ? Theme.accentSoft
                        : (cm.containsMouse ? "#14ffffff" : "transparent")
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: LauncherState.category === modelData.id
                            ? Theme.textPrimary
                            : Theme.textSecondary
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.count
                        color: Theme.textTertiary
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: cm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LauncherState.category = modelData.id
                    }
                }
            }
        }

        // ── Application grid ─────────────────────────────────────
        GridView {
            id: grid
            anchors.left: cats.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: searchBox.bottom
            anchors.topMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            clip: true

            cellWidth: 118
            cellHeight: 92
            model: win.apps
            boundsBehavior: Flickable.StopAtBounds

            delegate: AppTile {
                entry: modelData
                width: grid.cellWidth - 6
                height: grid.cellHeight - 6
                onLaunched: LauncherState.hide()
            }
        }

        Text {
            anchors.centerIn: grid
            visible: win.apps.length === 0
            text: "Nada que se parezca a eso"
            color: Theme.textTertiary
            font.pixelSize: 13
        }
    }
}
