import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// The dock's app list: remove with the cross, add by searching.
Column {
    id: root
    spacing: 6

    // ── The ones already there ───────────────────────────────────
    //
    // One tab stop for the whole row of them and the arrows to walk
    // it, rather than a stop per application: a dock with a dozen
    // things pinned would otherwise be a dozen presses on the way to
    // the box below.
    property int mark: 0

    FocusScope {
        width: parent.width
        height: chips.height
        // A stop worth having only while there is something to walk,
        // and `|| activeFocus` is what keeps that from being a trap.
        // Deleting the last pinned application with Del happens while
        // this very scope holds the focus, so the condition would turn
        // false under Qt's feet -- and Qt refuses to take the tab stop
        // away from the item that has the focus, which is the warning
        // the sidebar already taught us. Holding the focus keeps the
        // stop until the focus leaves, and then it goes quietly.
        activeFocusOnTab: Pinned.list.length > 0 || activeFocus

        Accessible.role: Accessible.List
        Accessible.name: I18n.t.secDockApps

        Keys.onLeftPressed: root.mark = Math.max(0, root.mark - 1)
        Keys.onRightPressed:
            root.mark = Math.min(Pinned.list.length - 1, root.mark + 1)
        Keys.onPressed: (e) => {
            if (e.key !== Qt.Key_Delete && e.key !== Qt.Key_Backspace) return;
            if (root.mark < 0 || root.mark >= Pinned.list.length) return;
            e.accepted = true;
            const id = Pinned.list[root.mark];
            // Step back first: taking the last one out would leave the
            // mark past the end of a list that no longer has it.
            if (root.mark >= Pinned.list.length - 1)
                root.mark = Math.max(0, root.mark - 1);
            Pinned.remove(id);
        }

    Flow {
        id: chips
        width: parent.width
        spacing: 6

        Repeater {
            model: Pinned.list

            Rectangle {
                id: chipTile
                required property string modelData
                required property int index
                readonly property var entry: (Apps.revision, Apps.entryFor(modelData))
                readonly property bool marked:
                    index === root.mark && chipTile.parent.parent.activeFocus

                width: chip.implicitWidth + 54
                height: 28
                radius: 8
                color: "#18ffffff"
                border.width: 1
                border.color: chipTile.marked ? Theme.accent : "#1affffff"

                Accessible.role: Accessible.ListItem
                Accessible.name: chipTile.entry
                    ? chipTile.entry.name : chipTile.modelData

                IconImage {
                    id: chipIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    source: (parent.entry && parent.entry.iconUrl)
                        ? parent.entry.iconUrl
                        : (parent.entry && parent.entry.icon)
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
    }

    // ── Search box to add more ───────────────────────────────────
    // The first answer is marked as you type, so finding something and
    // pressing return pins it. The arrows walk the rest without
    // leaving the box, which is where your hands already are.
    SearchField {
        id: search
        describedAs: I18n.t.addApp
        placeholder: I18n.t.addApp
        // Shorter than the town search next door on purpose: this one
        // walks a catalogue already in memory and answers at once,
        // while that one goes out to the network.
        settleMs: 180
        count: root.results.length
        // The mark lives in the field, because the arrows that move it
        // are in the field. This only mirrors it out for the rows to
        // draw and for return to act on -- binding it both ways would
        // be a loop whose first half dies the moment an arrow is
        // pressed, which is a worse kind of working.
        onPickChanged: root.pick = pick

        onSettled: root.lookUp()
        onCleared: root.results = []
        onTaken: root.add()
    }

    // ── Results ──────────────────────────────────────────────────
    //
    // Looked for after a pause in the typing rather than on every
    // letter. Each pass walks the whole catalogue — a name nothing
    // matches walks all of it — and each pass handed back a new array,
    // which threw away the rows and their icons and built them again
    // on every keystroke.
    property var results: []
    // Which answer return would take.
    property int pick: 0

    function add() {
        if (!root.results.length) return;
        const at = Math.max(0, Math.min(root.results.length - 1, root.pick));
        Pinned.add(root.results[at].id);
        search.clear();
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
                required property int index
                readonly property bool marked:
                    index === root.pick && search.input.activeFocus

                width: parent.width
                height: 28
                radius: 6
                color: marked ? "#2affffff"
                     : (hm.containsMouse ? "#1fffffff" : "transparent")

                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.name

                IconImage {
                    id: resIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16; height: 16
                    source: modelData.iconUrl
                        ? modelData.iconUrl
                        : modelData.icon
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
                    onClicked: { Pinned.add(parent.modelData.id); search.text = ""; }
                }
            }
        }
    }
}
