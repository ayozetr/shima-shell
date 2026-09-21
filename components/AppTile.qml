import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// One application in the launcher grid.
Item {
    id: root
    property var entry: null
    // The window that draws the menu, since the grid clips its cells.
    property var launcherWindow: null

    // Favourites are a list you arranged, so they can be rearranged.
    property bool reorderable: false
    property var gridView: null
    property int itemIndex: -1
    property bool dragging: false
    property real dragX: 0
    property real dragY: 0

    // The tile is lifted with a transform rather than by moving it:
    // the grid owns its position, and fighting the layout over it
    // makes the icon snap back mid-drag.
    transform: Translate { x: root.dragX; y: root.dragY }
    z: root.dragging ? 20 : 0

    signal launched()
    signal reordered(int from, int to)

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 12
        color: ma.containsMouse ? "#1affffff" : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }

        IconImage {
            id: icon
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 10
            width: 40; height: 40
            source: (root.entry && root.entry.icon)
                ? Quickshell.iconPath(root.entry.icon, "application-x-executable")
                : ""
            asynchronous: true
            scale: ma.pressed ? 0.9 : 1
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        Text {
            anchors.top: icon.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 6
            horizontalAlignment: Text.AlignHCenter
            text: root.entry ? root.entry.name : ""
            color: Theme.textSecondary
            font.pixelSize: 11
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.WordWrap
        }
    }

    // A gaming mouse reports around 800 times a second and the screen
    // draws 165, so moving the icon on every event asked for five
    // repaints that nobody would ever see — which is what made the
    // drag feel heavy. The position is applied once per frame instead.
    FrameAnimation {
        running: root.dragging
        onTriggered: {
            root.dragX = ma.wantX;
            root.dragY = ma.wantY;
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // The grid is a Flickable, and a Flickable steals a drag that
        // starts inside it: it reads the gesture as scrolling and
        // takes the mouse away mid-drag, which looks like the icon
        // stuttering. Only while rearranging, so the grid still
        // scrolls normally everywhere else.
        preventStealing: root.reorderable

        // The press point, in the grid's coordinates rather than the
        // tile's own. The tile carries a transform while it is being
        // dragged, so its local coordinates move with it: measuring a
        // delta there means measuring against an origin that is
        // running away, and the icon oscillates instead of following
        // the pointer. Mapping to the grid cancels the transform out.
        property real pressX: 0
        property real pressY: 0
        // Where the pointer is right now. Read by the frame tick
        // below and by nothing else, so moving it costs nothing.
        property real wantX: 0
        property real wantY: 0
        // A click is a click even if the hand shook: dragging only
        // starts past a threshold, and only then does releasing
        // rearrange instead of launching.
        property bool moved: false

        onPressed: (e) => {
            const g = root.gridView;
            const p = g ? root.mapToItem(g, e.x, e.y) : Qt.point(e.x, e.y);
            pressX = p.x; pressY = p.y; moved = false;
        }

        onPositionChanged: (e) => {
            if (!root.reorderable || !pressed || !root.gridView) return;
            const p = root.mapToItem(root.gridView, e.x, e.y);
            const dx = p.x - pressX;
            const dy = p.y - pressY;
            if (!root.dragging && Math.abs(dx) + Math.abs(dy) < 12) return;
            root.dragging = true;
            moved = true;
            wantX = dx;
            wantY = dy;
        }

        onReleased: (e) => {
            if (!root.dragging) return;

            // Measured before the transform is cleared: putting the
            // icon back first moves the coordinate system with it, and
            // the drop lands wherever the icon started.
            const g = root.gridView;
            const p = root.mapToItem(g, e.x, e.y);

            root.dragging = false;
            root.dragX = 0;
            root.dragY = 0;
            const cols = Math.max(1, Math.floor(g.width / g.cellWidth));
            const col = Math.max(0, Math.min(cols - 1,
                Math.floor(p.x / g.cellWidth)));
            const row = Math.max(0, Math.floor((p.y + g.contentY) / g.cellHeight));
            // Dropping past the last icon means "put it last", not
            // "put it in a slot that isn't there".
            const last = Math.max(0, g.count - 1);
            root.reordered(root.itemIndex, Math.min(row * cols + col, last));
        }

        onCanceled: {
            root.dragging = false;
            root.dragX = 0;
            root.dragY = 0;
        }

        onClicked: (e) => {
            if (!root.entry || ma.moved) return;
            if (e.button === Qt.RightButton) {
                if (!root.launcherWindow) return;
                const p = root.mapToItem(null, e.x, e.y);
                root.launcherWindow.openMenu(root.entry.id, root.entry.name, p.x, p.y);
                return;
            }
            Apps.start(root.entry);
            root.launched();
        }
    }

    ToolTipLabel {
        show: ma.containsMouse && root.entry && root.entry.comment
        text: root.entry ? root.entry.comment : ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 2
        z: 20
    }
}
