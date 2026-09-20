import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"
import "components"

PanelWindow {
    id: win

    // One menu for the whole dock rather than one per icon: this way
    // the window doesn't clip it and the input mask doesn't leave it
    // out.
    property bool hovering: false
    property string menuAppId: ""
    property string menuAppName: ""
    property bool   menuPinned: true
    property real   menuX: 0
    readonly property bool menuOpen: menuAppId !== ""

    function openMenu(id, name, pinned, xInWindow) {
        // Opening a menu closes the launcher: leaving both open at
        // once is confusing and forces you to dismiss them separately.
        LauncherState.hide();
        menuAppId = id;
        menuAppName = name;
        menuPinned = pinned;
        menuX = xInWindow;
    }
    function closeMenu() { menuAppId = ""; }

    readonly property bool autoHide: Config.data.dockAutoHide ?? false
    // It won't hide while a menu is open or you're dragging.
    readonly property bool revealed: !autoHide || hovering || menuOpen || row.dragIndex >= 0

    readonly property bool atTop: Config.data.dockPosition === "top"
    readonly property bool floating: Config.data.dockFloating ?? false
    readonly property int edgeMargin: floating ? (Config.data.dockMargin ?? 10) : -1

    anchors.top: atTop
    anchors.bottom: !atTop
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "shima-dock"
    color: "transparent"
    // screen can briefly be null while KWin removes a monitor, so we
    // don't take it for granted.
    visible: Config.onScreen(Config.data.dockScreens,
                             win.screen ? win.screen.name : "")

    // The window is deliberately roomy: a magnified icon grows upwards
    // and its name floats above it, and anything outside the window is
    // clipped. Input stays confined to the pill by the mask, so the
    // spare room bothers nobody.
    implicitWidth: pill.width + 260
    // Fixed height, with room for the menu whether it is open or not.
    // If it grew on opening, the pill would be repositioned relative to
    // the window and the auto-hide animation would make a very visible
    // round trip.
    implicitHeight: pill.height + 150 + Math.max(0, win.edgeMargin)

    // While hidden the mouse is only needed on a strip at the edge;
    // that is what keeps the rest of the screen belonging to the
    // desktop instead of swallowing its clicks.
    mask: win.menuOpen ? null : (win.revealed ? pillRegion : edgeRegion)

    Region {
        id: edgeRegion
        item: edgeStrip
    }

    Item {
        id: edgeStrip
        width: parent.width
        height: 3
        y: win.atTop ? 0 : parent.height - height

        HoverHandler {
            onHoveredChanged: if (hovered) win.hovering = true
        }
    }
    Region {
        id: pillRegion
        item: pill
        topLeftRadius:     Theme.dockRadius
        topRightRadius:    Theme.dockRadius
        bottomLeftRadius:  (win.floating || win.atTop) ? Theme.dockRadius : 0
        bottomRightRadius: (win.floating || win.atTop) ? Theme.dockRadius : 0
    }

    // Real blur behind the dock, served by
    // ext_background_effect_manager_v1.
    BackgroundEffect.blurRegion: (Config.data.dockBlur ?? true) ? blurRegion : null
    Region {
        id: blurRegion
        item: pill
        topLeftRadius:     Theme.dockRadius
        topRightRadius:    Theme.dockRadius
        bottomLeftRadius:  (win.floating || win.atTop) ? Theme.dockRadius : 0
        bottomRightRadius: (win.floating || win.atTop) ? Theme.dockRadius : 0
    }

    // A click anywhere else dismisses the menu.
    MouseArea {
        anchors.fill: parent
        enabled: win.menuOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: win.closeMenu()
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter

        // Vertical position goes through `y` rather than anchors: when
        // switching top/bottom, QML doesn't always release the previous
        // anchor and the pill ended up stretched between both edges.
        // One pixel past the edge so that border stroke isn't drawn and
        // the dock grows out of the screen.
        // Measured against the window and not parent: contentItem isn't
        // always the same size as the window, and the dock was left
        // half hidden.
        y: {
            if (!win.revealed)
                return win.atTop ? -height - 4 : win.height + 4;
            return win.atTop
                ? win.edgeMargin
                : (win.height - height - win.edgeMargin);
        }
        // Only animates when hiding and peeking out; any other
        // recalculation of the position must be instant.
        Behavior on y {
            enabled: win.autoHide
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        width: row.width + Theme.dockPadding * 2
        height: row.height + Theme.dockPadding * 2 + (win.floating ? 0 : 1)

        topLeftRadius:     (win.floating || !win.atTop) ? Theme.dockRadius : 0
        topRightRadius:    (win.floating || !win.atTop) ? Theme.dockRadius : 0
        bottomLeftRadius:  (win.floating || win.atTop)  ? Theme.dockRadius : 0
        bottomRightRadius: (win.floating || win.atTop)  ? Theme.dockRadius : 0

        color: Theme.dockBg
        border.width: 1
        border.color: Theme.dockBorder

        Behavior on width  { NumberAnimation { duration: Theme.springDuration; easing.type: Easing.OutCubic } }
        Behavior on color  { ColorAnimation  { duration: Theme.fadeDuration } }

        // The cursor position is tracked with a HoverHandler and not a
        // MouseArea: each icon's MouseArea sits above it and stole the
        // hover, so magnification only responded in the gaps. A handler
        // coexists with them instead of competing.
        HoverHandler {
            id: dockHover
            onHoveredChanged: {
                if (hovered) { hideTimer.stop(); win.hovering = true; }
                else if (win.autoHide) hideTimer.restart();
            }
        }

        // Only picks up right clicks landing on the empty part of the
        // pill; declared before the icons so it stays beneath them.
        MouseArea {
            id: dockMouse
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: { LauncherState.hide(); SettingsWindow.toggle(); }
        }

        // Positioned by hand instead of using a Row: needed so the
        // icons can step aside while you drag one.
        Item {
            id: row
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.dockPadding

            readonly property bool hasLauncher: Config.data.showLauncher ?? true
            readonly property int step: Theme.dockIconSize + Theme.dockIconSpacing
            // The launcher button takes its own slot ahead of everything.
            readonly property int lead: hasLauncher ? step : 0
            readonly property int count: Apps.dockItems.length
            readonly property int pinnedCount: Apps.pinned.length
            width: Math.max(0, lead + count * step - Theme.dockIconSpacing)
            height: Theme.dockIconSize + Theme.dockDotLane

            // Which one is being dragged and where it would land now.
            property int dragIndex: -1
            property int dropIndex: -1

            // Where each icon is drawn, accounting for the gap left by
            // the one you're holding.
            function slotOf(i) {
                if (dragIndex < 0 || i === dragIndex) return i;
                if (dragIndex < dropIndex && i > dragIndex && i <= dropIndex) return i - 1;
                if (dragIndex > dropIndex && i >= dropIndex && i < dragIndex) return i + 1;
                return i;
            }

            // Thin divider between what you pinned and what is merely
            // open right now.
            Rectangle {
                visible: row.pinnedCount > 0 && row.count > row.pinnedCount
                x: row.lead + row.pinnedCount * row.step
                   - Theme.dockIconSpacing / 2 - width / 2
                y: 4
                width: 1
                height: Theme.dockIconSize - 8
                color: "#20ffffff"
            }

            function commitDrag() {
                if (dragIndex >= 0 && dropIndex >= 0 && dragIndex !== dropIndex)
                    Apps.move(dragIndex, dropIndex);
                dragIndex = -1;
                dropIndex = -1;
            }

            LauncherButton {
                visible: row.hasLauncher
                dockWindow: win
                x: 0
                y: 0
            }

            // Divider after the launcher button.
            Rectangle {
                visible: row.hasLauncher && row.count > 0
                x: row.step - Theme.dockIconSpacing / 2 - width / 2
                y: 4
                width: 1
                height: Theme.dockIconSize - 8
                color: "#20ffffff"
            }

            Repeater {
                model: Apps.dockItems
                DockItem {
                    appId: modelData
                    itemIndex: index
                    dock: row
                    dockWindow: win
                    cursorX: dockHover.hovered
                        ? dockHover.point.position.x - x - row.x
                        : -9999
                }
            }
        }

    }

    DockMenu {
        appId: win.menuAppId
        appName: win.menuAppName
        pinned: win.menuPinned
        open: win.menuOpen
        onCloseRequested: win.closeMenu()

        // Centred over its icon, without running off the window.
        x: Math.max(6, Math.min(win.width - width - 6, win.menuX - width / 2))
        y: pill.y - height - 10
    }

    Timer {
        id: hideTimer
        interval: Config.data.dockHideDelay ?? 700
        onTriggered: win.hovering = false
    }
}
