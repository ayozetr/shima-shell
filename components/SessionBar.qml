import QtQuick
import "../services"

// The launcher's bottom bar: power, session and settings, the way
// Plasma's own menu keeps them within reach.
Item {
    id: root
    signal dismissed()

    // Which submenu is unfolded, if any.
    property string openMenu: ""

    // Reopening the launcher should not find a submenu still unfolded
    // from last time.
    Connections {
        target: LauncherState
        function onOpenChanged() { if (!LauncherState.open) root.openMenu = ""; }
    }

    implicitHeight: 34

    Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Button_ { kind: "power";    menu: "power"    }
        Button_ { kind: "user";     menu: "user"     }
        Button_ {
            kind: "settings"
            menu: ""
            onPlainClick: { SettingsWindow.show(); root.dismissed(); }
        }
    }

    // ── Submenus, unfolded above their button ────────────────────
    Popup_ {
        id: powerMenu
        x: 0
        visible: root.openMenu === "power"
        entries: [
            { label: I18n.t.suspend, act: () => Session.suspend() },
            { label: I18n.t.reboot, act: () => Session.reboot() },
            { label: I18n.t.shutdown,    act: () => Session.shutdown(), danger: true }
        ]
    }

    Popup_ {
        id: userMenu
        x: 36
        visible: root.openMenu === "user"
        entries: [
            { label: I18n.t.lockSession, act: () => Session.lock() },
            { label: I18n.t.switchUser, act: () => Session.switchUser() },
            { label: I18n.t.logout,   act: () => Session.logout(), danger: true }
        ]
    }

    component Button_: Rectangle {
        id: btn
        property string kind: ""
        property string menu: ""
        signal plainClick()

        width: 32; height: 32; radius: 9
        color: (root.openMenu !== "" && root.openMenu === btn.menu)
            ? Theme.accentSoft
            : (bm.containsMouse ? "#1affffff" : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }

        SessionGlyph {
            anchors.centerIn: parent
            width: 16; height: 16
            kind: btn.kind
            fill: bm.containsMouse ? Theme.textPrimary : Theme.textSecondary
        }

        MouseArea {
            id: bm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (btn.menu === "") { btn.plainClick(); return; }
                root.openMenu = (root.openMenu === btn.menu) ? "" : btn.menu;
            }
        }
    }

    component Popup_: Rectangle {
        id: pop
        property var entries: []

        y: -height - 6
        width: 188
        height: col.height + 8
        radius: 10
        color: "#fa121212"
        border.width: 1
        border.color: "#2a2a2a"
        z: 50

        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Column {
            id: col
            y: 4
            width: parent.width
            spacing: 1

            Repeater {
                model: pop.entries

                Rectangle {
                    required property var modelData
                    x: 4
                    width: pop.width - 8
                    height: 28
                    radius: 6
                    color: em.containsMouse
                        ? (modelData.danger ? "#33f87171" : "#1fffffff")
                        : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.danger ? "#f87171" : Theme.textPrimary
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: em
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            modelData.act();
                            root.openMenu = "";
                            root.dismissed();
                        }
                    }
                }
            }
        }
    }
}
