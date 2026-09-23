import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// A dock icon: rounded square with a gradient, the accent dot while
// the app is running, and draggable to reorder.
Item {
    id: root
    property string appId: ""
    property int itemIndex: 0
    property var dock: null
    property var dockWindow: null
    property real cursorX: -9999

    // The comma ties this binding to revision: without it, it never
    // re-evaluates once DesktopEntries finishes scanning.
    readonly property var entry: (Apps.revision, Apps.entryFor(root.appId))
    readonly property bool running: (Apps.revision, Apps.isRunning(root.appId))
    // Ones that are merely open sit behind and don't reorder.
    readonly property bool isPinned: Apps.pinned.indexOf(root.appId) !== -1

    readonly property bool dragging: dock && dock.dragIndex === itemIndex
    property real dragX: 0

    width: Theme.dockIconSize
    height: Theme.dockIconSize + Theme.dockDotLane
    z: dragging ? 10 : 0

    // While dragging you're in charge; the rest of the time, the slot
    // the ordering gives you.
    x: dragging
        ? dragX
        : (dock ? dock.lead + dock.slotOf(itemIndex) * dock.step : itemIndex * width)
    Behavior on x {
        enabled: !root.dragging
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    readonly property real distance: Math.abs(cursorX - width / 2)
    readonly property real magnify: {
        if (!(Config.data.dockMagnify ?? true)) return 1;
        if (root.dragging) return 1.12;
        const reach = Theme.dockIconSize * 2.2;
        if (distance > reach) return 1;
        return 1 + 0.30 * Math.pow(1 - distance / reach, 2);
    }

    Rectangle {
        id: tile
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: Theme.dockIconSize
        height: Theme.dockIconSize
        radius: Theme.dockIconRadius

        // The design gradient runs at 135 degrees; QML only does
        // vertical, and at this size the difference doesn't show.
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.iconTop }
            GradientStop { position: 1.0; color: Theme.iconBottom }
        }
        border.width: 1
        border.color: Theme.iconBorder

        scale: root.magnify * (mouse.pressed && !root.dragging ? 0.92 : 1)
        opacity: root.dragging ? 0.85 : 1
        transformOrigin: Item.Bottom
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        IconImage {
            anchors.centerIn: parent
            width: Theme.dockIconSize * Theme.dockIconArt
            height: width
            // A made-up entry can carry a file rather than a name in
            // the theme: Shima's own icon only reaches the theme once
            // Shima has been installed, and it has to draw itself in
            // the dock either way.
            //
            // Given an empty icon, iconPath returns the generic cog.
            // Better to draw nothing until the real one arrives.
            source: (root.entry && root.entry.iconUrl)
                ? root.entry.iconUrl
                : (root.entry && root.entry.icon)
                ? Quickshell.iconPath(root.entry.icon, "application-x-executable")
                : ""
            asynchronous: true
        }
    }

    // Running dot: 4 px of accent with a soft halo behind it.
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: tile.bottom
        anchors.topMargin: 4
        width: 12; height: 12
        opacity: root.running ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

        Rectangle {
            anchors.centerIn: parent
            width: 10; height: 10; radius: 5
            color: Theme.accent
            opacity: 0.35
        }
        Rectangle {
            anchors.centerIn: parent
            width: 4; height: 4; radius: 2
            color: Theme.accent
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        property real pressX: 0
        property real originX: 0
        property bool moved: false

        // The cursor, in dock coordinates. It has to be measured this
        // way: e.x is relative to the icon, and since dragging moves
        // the icon, using it feeds back on itself and the drag stutters.
        function cursorInDock(e) {
            return root.dock ? root.mapToItem(root.dock, e.x, 0).x : e.x;
        }

        onPressed: (e) => {
            if (e.button !== Qt.LeftButton) return;
            pressX = cursorInDock(e);
            originX = root.x;
            moved = false;
        }

        onPositionChanged: (e) => {
            if (!root.dock || !root.isPinned) return;
            if (!(pressedButtons & Qt.LeftButton)) return;
            const delta = cursorInDock(e) - pressX;
            // A small threshold so an ordinary click's wobble doesn't
            // reorder anything.
            if (!moved && Math.abs(delta) < 6) return;

            if (!moved) {
                moved = true;
                root.dragX = originX;
                root.dock.dragIndex = root.itemIndex;
                root.dock.dropIndex = root.itemIndex;
            }

            root.dragX = originX + delta;
            const slot = Math.round((root.dragX - root.dock.lead) / root.dock.step);
            root.dock.dropIndex = Math.max(0, Math.min(root.dock.count - 1, slot));
        }

        onReleased: (e) => {
            // Whatever happens, never leave a drag half-finished.
            if (moved) { root.dock.commitDrag(); moved = false; return; }

            if (e.button === Qt.MiddleButton) {
                // Middle click offers the windows by title instead of
                // stepping through them one click at a time.
                if (root.dockWindow && root.dock) {
                    // Relative to the icon row: the window resizes when
                    // a popup opens, so window coordinates taken now
                    // would point somewhere else by the time it shows.
                    const c = root.mapToItem(root.dock, root.width / 2, 0);
                    root.dockWindow.openWindowList(root.appId,
                        root.entry ? root.entry.name : root.appId, c.x);
                }
                return;
            }

            if (e.button === Qt.RightButton) {
                // The menu lives in the dock's window; we hand it the
                // icon's centre in those coordinates.
                if (root.dockWindow && root.dock) {
                    const c = root.mapToItem(root.dock, root.width / 2, 0);
                    root.dockWindow.openMenu(root.appId,
                        root.entry ? root.entry.name : root.appId,
                        root.isPinned, c.x);
                }
                return;
            }
            if (e.button === Qt.LeftButton) {
                // Launching from the dock puts the launcher away, the
                // same as launching from inside it does.
                LauncherState.hide();
                Apps.launch(root.appId);
            }
        }

        onCanceled: { if (root.dock) root.dock.commitDrag(); moved = false; }
    }

    ToolTipLabel {
        // Hidden while a popup is open: the name would float over the
        // menu that just took its place.
        show: mouse.containsMouse && !root.dragging
              && (Config.data.showAppNames ?? true)
              && !(root.dockWindow && root.dockWindow.popupOpen)
        text: root.entry ? root.entry.name : root.appId
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 10
    }
}
