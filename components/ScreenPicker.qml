import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

// One row per connected monitor, with a toggle for the island and
// another for the dock.
Column {
    id: root
    spacing: 6

    readonly property var allNames: Quickshell.screens.map(s => s.name)

    // Quickshell reports the resolution in logical pixels, already
    // divided by the scale, and its devicePixelRatio says 2 because on
    // Wayland rendering happens at integer scale and the compositor
    // resizes afterwards. Only KWin knows the real scale.
    property var scales: ({})

    // Asked again every time the picker is shown, not once when it is
    // built: change a monitor's scale and the old code went on showing
    // the resolution it had at startup until the shell was restarted.
    // Given how much trouble scaling has caused here, stale numbers in
    // this particular list are worse than none.
    Process {
        running: root.visible
        command: ["sh", "-c",
            "kscreen-doctor -o 2>/dev/null | sed -e 's/\x1b\[[0-9;]*m//g' "
            + "| awk '/^Output:/ { name=$3 } /Scale:/ { print name, $2 }'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const p = line.trim().split(/\s+/);
                    if (p.length === 2) out[p[0]] = parseFloat(p[1]);
                }
                root.scales = out;
            }
        }
    }

    Repeater {
        model: Quickshell.screens

        Rectangle {
            required property var modelData
            width: root.width
            height: 46
            radius: 10
            color: "#12ffffff"
            border.width: 1
            border.color: "#16ffffff"

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                // The model as the monitor states it — "ASUS VG32VQR"
                // — with the connector underneath. A screen that does
                // not state one gets a description built by the
                // compositor out of the connector and a translated
                // word for unknown: the virtual output of a VM comes
                // through as "Virtual-1-desconocida". If the model
                // starts with the connector it is that description and
                // not a name, so the connector alone reads better.
                readonly property bool named:
                    modelData.model && modelData.model !== modelData.name
                    && modelData.model.indexOf(modelData.name) !== 0

                Text {
                    text: parent.named ? modelData.model : modelData.name
                    color: Theme.textPrimary
                    font.pixelSize: 12
                }
                Text {
                    // width and height come as logical pixels, already
                    // divided by the scale. Showing the panel's real
                    // resolution means undoing that division.
                    text: {
                        const k = root.scales[modelData.name] || 1;
                        // Rounded to tens: 2227 x 1.15 gives 2561 and
                        // the monitor is a 2560.
                        const w = Math.round(modelData.width * k / 10) * 10;
                        const h = Math.round(modelData.height * k / 10) * 10;
                        // The connector goes here only when it is
                        // not already the line above.
                        let t = parent.named ? modelData.name + " · " : "";
                        t += w + "×" + h;
                        if (Math.abs(k - 1) > 0.01)
                            t += "  ·  " + Math.round(k * 100) + "%";
                        return t;
                    }
                    color: Theme.textTertiary
                    font.pixelSize: 10
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Column {
                    spacing: 3
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t.island
                        color: Theme.textTertiary
                        font.pixelSize: 9
                    }
                    MiniToggle {
                        describedAs: I18n.t.island + " — " + modelData.name
                        on: Config.onScreen(Config.data.islandScreens, modelData.name)
                        onToggled: (v) => Config.toggleScreen(
                            "islandScreens", modelData.name, v, root.allNames)
                    }
                }

                Column {
                    spacing: 3
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.t.dock
                        color: Theme.textTertiary
                        font.pixelSize: 9
                    }
                    MiniToggle {
                        describedAs: I18n.t.dock + " — " + modelData.name
                        on: Config.onScreen(Config.data.dockScreens, modelData.name)
                        onToggled: (v) => Config.toggleScreen(
                            "dockScreens", modelData.name, v, root.allNames)
                    }
                }
            }
        }
    }

    component MiniToggle: Rectangle {
        id: tg
        property bool on: false
        property string describedAs: ""
        signal toggled(bool value)

        activeFocusOnTab: true
        Keys.onSpacePressed: tg.toggled(!tg.on)
        Keys.onReturnPressed: tg.toggled(!tg.on)
        Keys.onEnterPressed: tg.toggled(!tg.on)

        Accessible.role: Accessible.CheckBox
        Accessible.name: tg.describedAs
        Accessible.checked: tg.on
        Accessible.onToggleAction: tg.toggled(!tg.on)
        Accessible.onPressAction: tg.toggled(!tg.on)

        // Its own ring rather than the one in Controls: this file does
        // not import that library, and one rectangle is cheaper than
        // the dependency.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 4
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            visible: tg.activeFocus
        }

        width: 34; height: 19; radius: 9.5
        color: tg.on ? Theme.accent : "#3a3a3a"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Rectangle {
            x: tg.on ? parent.width - width - 2.5 : 2.5
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: tg.on ? Theme.accentText : "#ffffff"
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tg.toggled(!tg.on)
        }
    }
}
