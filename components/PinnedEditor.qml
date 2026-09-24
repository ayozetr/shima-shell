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
            model: Pinned.list

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
                        onClicked: Pinned.remove(parent.parent.modelData)
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

            onTextChanged: {
                if (text.length > 0) settle.restart();
                else { settle.stop(); root.results = []; }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === "" && !search.activeFocus
                text: I18n.t.addApp
                color: Theme.textTertiary
                font.pixelSize: 12
            }
        }
    }

    // ── Results ──────────────────────────────────────────────────
    //
    // Looked for after a pause in the typing rather than on every
    // letter. Each pass walks the whole catalogue — a name nothing
    // matches walks all of it — and each pass handed back a new array,
    // which threw away the rows and their icons and built them again
    // on every keystroke.
    property var results: []

    Timer {
        id: settle
        interval: 180
        onTriggered: root.lookUp()
    }

    // Pinning one of them takes it out of the list it was picked from.
    Connections {
        target: Pinned
        function onListChanged() { root.lookUp(); }
    }

    function lookUp() {
        const q = search.text.trim().toLowerCase();
        if (!q) { root.results = []; return; }

        const out = [];
        for (const e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue;
            if (Pinned.list.indexOf(e.id) !== -1) continue;
            if (e.name.toLowerCase().indexOf(q) === -1) continue;
            out.push(e);
            if (out.length >= 6) break;
        }

        if (out.length === root.results.length) {
            let same = true;
            for (let i = 0; i < out.length; i++)
                if (out[i].id !== root.results[i].id) { same = false; break; }
            if (same) return;
        }
        root.results = out;
    }

    Column {
        width: parent.width
        spacing: 2
        visible: root.results.length > 0

        Repeater {
            model: root.results

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
                    onClicked: { Pinned.add(modelData.id); search.text = ""; }
                }
            }
        }
    }
}
