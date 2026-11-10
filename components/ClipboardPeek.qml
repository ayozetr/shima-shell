import QtQuick
import "../services"

// The shelf: what you just copied, held out in the island to be
// dragged straight into an app or a folder, with a tap to open the
// whole history instead.
//
// Two ways to take it. The thumbnail on the left is the handle: press
// it and drag, and it leaves as a file or a line of text, whichever it
// is, for whatever it is dropped on to make of it. A tap anywhere else
// — or on the thumbnail without dragging — opens the history, which is
// the same list as Meta+V.
Item {
    id: root

    property var entry: null
    signal openHistory()
    signal dismissed()

    readonly property bool isImage: root.entry && root.entry.kind === "image"

    // ── The rest of the strip: a tap opens the history ───────────
    //
    // Declared first so it sits under the thumbnail, which has its own
    // handler: the drag has to win over the thumbnail, the tap
    // everywhere else.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => {
            if (e.button === Qt.LeftButton) root.openHistory();
            else root.dismissed();
        }
    }

    // ── The handle you drag out ──────────────────────────────────
    Item {
        id: handle
        width: 44; height: 44
        x: 0
        y: (root.height - height) / 2

        // The little picture that follows the cursor while dragging. It
        // is a grab of this handle, so it is thumbnail-sized — pointing
        // the drag image straight at the file dragged the whole
        // screenshot across the desktop at its full size.
        property url dragPixmap: ""

        Drag.active: dragArea.drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: root.entry ? Clipboard.dragData(root.entry) : ({})
        Drag.imageSource: handle.dragPixmap

        // Taken after the thumbnail has drawn, and again whenever what
        // is on the shelf changes. Left empty until then, so the drag
        // never falls back to the full picture.
        function grab() {
            if (!handle.visible) return;
            handle.grabToImage(function (r) { handle.dragPixmap = r.url; },
                               Qt.size(44, 44));
        }
        onVisibleChanged: if (visible) Qt.callLater(handle.grab)
        Component.onCompleted: Qt.callLater(handle.grab)
        Connections {
            target: root
            function onEntryChanged() { Qt.callLater(handle.grab); }
        }

        // A picture shows itself; anything else shows a plain card with
        // a corner turned down, so the shelf reads as "something to
        // drag" even when there is no image to put on it.
        Rectangle {
            anchors.fill: parent
            radius: 11
            clip: true
            color: root.isImage ? "#20ffffff" : Theme.accentSoft
            border.width: 1
            border.color: "#1affffff"

            Image {
                anchors.fill: parent
                visible: root.isImage
                source: root.isImage ? ("file://" + root.entry.path) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // The grab is worth nothing until the picture is in it.
                onStatusChanged: if (status === Image.Ready) Qt.callLater(handle.grab)
            }

            Text {
                anchors.fill: parent
                anchors.margins: 6
                visible: !root.isImage
                text: root.entry ? Clipboard.preview(root.entry) : ""
                color: Theme.textSecondary
                font.pixelSize: 8
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            drag.target: handle
            // A press that did not become a drag is a tap: open the
            // history, the same as the rest of the strip.
            onClicked: root.openHistory()
            // Automatic drags are handed to the compositor, so the
            // handle does not actually move; snap it home anyway, in
            // case the platform ever declines the drag.
            onReleased: {
                handle.Drag.drop();
                handle.x = 0;
                handle.y = (root.height - handle.height) / 2;
            }
        }
    }

    // ── What it is, and what to do with it ───────────────────────
    Column {
        anchors.left: handle.right
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.isImage ? I18n.t.shelfImage : I18n.t.shelfCopied
            color: Theme.textPrimary
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: I18n.t.shelfDrag
            color: Theme.textSecondary
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: I18n.t.shelfOpenHistory
            color: Theme.textTertiary
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }
}
