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

    Process {
        running: true
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

                Text {
                    text: modelData.model || modelData.name
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
                        let t = modelData.name + " · " + w + "×" + h;
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
        signal toggled(bool value)

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
