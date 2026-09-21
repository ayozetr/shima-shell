import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
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
    // Any popup is open: used for the input mask and for the click
    // that dismisses them. Each popup has its own condition, or opening
    // one would open the other along with it.
    readonly property bool popupOpen: menuShown || listShown
    property bool menuShown: false
    readonly property bool menuOpen: menuShown

    function openMenu(id, name, pinned, xInWindow) {
        // Clicking the same icon again closes it, rather than
        // reopening the same menu on top of itself.
        if (menuShown && menuAppId === id) { closeMenu(); return; }
        menuCleanup.stop();
        menuShown = true;
        // Opening a menu closes the launcher: leaving both open at
        // once is confusing and forces you to dismiss them separately.
        LauncherState.hide();
        closeWindowList();
        menuAppId = id;
        menuAppName = name;
        menuPinned = pinned;
        menuX = xInWindow;
    }
    // The contents outlive the fade: clearing the id right away empties
    // the menu and changes its height mid-animation, which reads as the
    // fade being cut short.
    function closeMenu() {
        menuShown = false;
        menuCleanup.restart();
    }

    Timer {
        id: menuCleanup
        interval: 200
        onTriggered: win.menuAppId = ""
    }

    // The window list, opened with a middle click. It shares the menu's
    // plumbing: same window, same mask, closed by the same click.
    property string listAppId: ""
    property string listAppName: ""
    property real   listX: 0
    property bool listShown: false
    readonly property bool listOpen: listShown

    function openWindowList(id, name, xInWindow) {
        if (listShown && listAppId === id) { closeWindowList(); return; }
        listCleanup.stop();
        listShown = true;
        LauncherState.hide();
        closeMenu();
        listAppId = id;
        listAppName = name;
        listX = xInWindow;
        Apps.loadWindows(id);
    }
    function closeWindowList() {
        listShown = false;
        listCleanup.restart();
    }

    Timer {
        id: listCleanup
        interval: 200
        onTriggered: win.listAppId = ""
    }

    readonly property bool autoHide: Config.data.dockAutoHide ?? false
    // It won't hide while a menu is open or you're dragging.
    readonly property bool revealed: !autoHide || hovering || popupOpen || row.dragIndex >= 0

    readonly property bool atTop: Config.data.dockPosition === "top"
    readonly property bool floating: Config.data.dockFloating ?? false
    readonly property int edgeMargin: floating ? (Config.data.dockMargin ?? 10) : -1

    // The window always covers the screen, so a click anywhere can
    // dismiss a popup. What keeps it from stealing the desktop's clicks
    // is the mask, not the window size: resizing it on open and close
    // made the dock visibly jump as it was laid out again.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "shima-dock"
    color: "transparent"
    // Handed down by the shell, not read from window.screen: doing
    // the latter inside `visible` loops, since hiding clears it.
    property string screenName: ""
    visible: Config.onScreen(Config.data.dockScreens, win.screenName)

    // While hidden the mouse is only needed on a strip at the edge;
    // that is what keeps the rest of the screen belonging to the
    // desktop instead of swallowing its clicks.
    mask: win.popupOpen ? null : (win.revealed ? pillRegion : edgeRegion)

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
        enabled: win.popupOpen
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: { win.closeMenu(); win.closeWindowList(); }
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
        // recalculation of the position must be instant, including the
        // window growing to fit a menu.
        Behavior on y {
            enabled: win.autoHide && !win.popupOpen
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

        // No animation on the width here: it comes from the icon row,
        // which animates it already. Animating it twice made the pill
        // lag behind its own contents, leaving tray icons outside the
        // edge while it caught up.
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

            // The tray sits at the end, smaller than the app icons and
            // behind its own divider: they are indicators, not launchers.
            readonly property bool hasTray: (Config.data.showTray ?? true)
                                            && trayModel.length > 0
            readonly property var trayModel: {
                const out = [];
                for (const i of SystemTray.items.values)
                    if (i.status !== SystemTrayItem.Passive) out.push(i);
                return out;
            }
            readonly property int trayStep: Math.round(Theme.dockIconSize * 0.62)
                                            + Math.round(Theme.dockIconSpacing * 0.55)

            // Folded, only the chevron shows; unfolded, the icons follow
            // it. Set to stay out, there is no chevron at all.
            readonly property bool trayFolds: Config.data.trayCollapsible ?? true
            property bool trayOut: false
            readonly property bool trayShown: hasTray && (!trayFolds || trayOut)
            readonly property int toggleStep: (trayFolds && hasTray)
                ? Math.round(Theme.dockIconSize * 0.62 * 0.62)
                  + Math.round(Theme.dockIconSpacing * 0.55)
                : 0

            readonly property int trayLead: lead + count * step
                                            + (hasTray ? Theme.dockIconSpacing : 0)
            readonly property int trayIconsLead: trayLead + toggleStep
            readonly property int count: Apps.dockItems.length
            readonly property int pinnedCount: Apps.pinned.length
            width: Math.max(0, !hasTray
                ? lead + count * step - Theme.dockIconSpacing
                : trayIconsLead
                  + (trayShown ? trayModel.length * trayStep : 0)
                  - (trayShown ? Math.round(Theme.dockIconSpacing * 0.55)
                               : Math.round(Theme.dockIconSpacing * 0.55)))
            // The pill has to finish widening before the icons finish
            // appearing, or they sit outside it for a moment. Folding
            // is the other way round: they leave first.
            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
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

            // Divider before the tray.
            Rectangle {
                visible: row.hasTray && row.count > 0
                x: row.trayLead - Theme.dockIconSpacing / 2 - width / 2
                y: 4
                width: 1
                height: Theme.dockIconSize - 8
                color: "#20ffffff"
            }

            TrayToggle {
                visible: row.hasTray && row.trayFolds
                expanded: row.trayOut
                x: row.trayLead
                y: 0
                onToggled: row.trayOut = !row.trayOut
            }

            Repeater {
                model: row.trayModel
                TrayItem {
                    // Both have to be declared: asking for modelData
                    // makes the delegate required-only, and index stops
                    // being injected.
                    required property var modelData
                    required property int index
                    item: modelData
                    dockWindow: win
                    // Folded, they sit on top of the chevron and slide
                    // out from behind it. Animating only the opacity
                    // left them at their final position from the first
                    // frame, outside the pill until it finished
                    // widening. Same duration and curve as the width,
                    // so icon and edge travel together.
                    x: row.trayShown
                        ? row.trayIconsLead + index * row.trayStep
                        : row.trayLead
                    y: 0
                    Behavior on x {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    visible: opacity > 0
                    opacity: row.trayShown ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: 170 }
                    }
                }
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
        id: dockMenu
        appId: win.menuAppId
        appName: win.menuAppName
        pinned: win.menuPinned
        open: win.menuOpen
        onCloseRequested: win.closeMenu()

        // Centred over its icon, without running off the window. The
        // stored position is relative to the icon row, so the pill's
        // own position is added here, when it is already laid out.
        x: Math.max(6, Math.min(win.width - width - 6,
                                pill.x + row.x + win.menuX - width / 2))
        y: pill.y - height - 10
    }

    Timer {
        id: hideTimer
        interval: Config.data.dockHideDelay ?? 700
        onTriggered: win.hovering = false
    }

    WindowList {
        id: windowList
        appId: win.listAppId
        appName: win.listAppName
        open: win.listOpen
        onCloseRequested: win.closeWindowList()

        x: Math.max(6, Math.min(win.width - width - 6,
                                pill.x + row.x + win.listX - width / 2))
        y: pill.y - height - 10
    }
}
