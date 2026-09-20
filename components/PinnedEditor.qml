import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// The dock's app list: remove with the cross, add by searching.
Column {
    id: root
    spacing: 6

    // ── The ones already there ───────────────────────────────────
    Flow {
        width: parent.width
        spacing: 6

        Repeater {
            model: Apps.pinned

            Rectangle {
                required property string modelData
                readonly property var entry: (Apps.revision, Apps.entryFor(modelData))

                width: chip.implicitWidth + 54
                height: 28
                radius: 8
                color: "#18ffffff"
                border.width: 1
                border.color: "#1affffff"

                IconImage {
                    id: chipIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    source: (parent.entry && parent.entry.icon)
                        ? Quickshell.iconPath(parent.entry.icon, "application-x-executable") : ""
                }

                Text {
                    id: chip
                    anchors.left: chipIcon.right
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.entry ? parent.entry.name : parent.modelData
                    color: Theme.textPrimary
                    font.pixelSize: 11
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    text: "✕"
                    color: rm.containsMouse ? "#f87171" : Theme.textTertiary
                    font.pixelSize: 11

                    MouseArea {
                        id: rm
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Apps.unpin(parent.parent.modelData)
                    }
                }
            }
        }
    }

    // ── Search box to add more ───────────────────────────────────
    Rectangle {
        width: parent.width
        height: 30
        radius: 8
        color: "#14ffffff"
        border.width: 1
        border.color: search.activeFocus ? Theme.accent : "#1affffff"

        TextInput {
            id: search
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.textPrimary
            font.pixelSize: 12
            clip: true
            selectByMouse: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === "" && !search.activeFocus
                text: "Añadir una aplicación…"
                color: Theme.textTertiary
                font.pixelSize: 12
            }
        }
    }

    // ── Results ──────────────────────────────────────────────────
    Column {
        width: parent.width
        spacing: 2
        visible: search.text.length > 0

        Repeater {
            model: {
                const q = search.text.toLowerCase();
                if (!q) return [];
                const out = [];
                for (const e of DesktopEntries.applications.values) {
                    if (e.noDisplay) continue;
                    if (Apps.pinned.indexOf(e.id) !== -1) continue;
                    if (e.name.toLowerCase().indexOf(q) === -1) continue;
                    out.push(e);
                    if (out.length >= 6) break;
                }
                return out;
            }

            Rectangle {
                required property var modelData
                width: parent.width
                height: 28
                radius: 6
                color: hm.containsMouse ? "#1fffffff" : "transparent"

                IconImage {
                    id: resIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    source: modelData.icon
                        ? Quickshell.iconPath(modelData.icon, "application-x-executable") : ""
                }

                Text {
                    anchors.left: resIcon.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: Theme.textPrimary
                    font.pixelSize: 12
                }

                MouseArea {
                    id: hm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Apps.pin(modelData.id); search.text = ""; }
                }
            }
        }
    }
}
