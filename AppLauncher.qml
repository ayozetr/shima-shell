import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "services"
import "components"

PanelWindow {
    id: win

    // Covers the whole screen while open: that is what lets a click
    // anywhere dismiss it, the way KDE's menu does. Only the panel is
    // drawn; everything else is transparent.
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shima-launcher"

    // It needs the keyboard so you can type the moment it opens.
    WlrLayershell.keyboardFocus: win.visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
    color: "transparent"

    property string screenName: ""
    visible: LauncherState.open
             && Config.onScreen(Config.data.dockScreens, win.screenName)

    BackgroundEffect.blurRegion: Region { item: panel; radius: 18 }

    // The window still covers the screen, so the panel stays where it
    // was and a click anywhere closes it — but the dock's strip is cut
    // out of what takes the mouse, or it would swallow every click
    // meant for the dock underneath. Shrinking the window instead
    // moves the panel up with it.
    mask: Region {
        width: win.width
        height: win.height

        Region {
            intersection: Intersection.Subtract
            width: win.width
            height: DockState.reserved
            y: DockState.position === "bottom" ? win.height - DockState.reserved : 0
        }
    }

    readonly property var apps: (Apps.revision, LauncherState.open)
        ? Apps.listApps(LauncherState.category, LauncherState.query)
        : []

    // ── The per-application menu ───────────────────────────────
    //
    // It lives here rather than in the tile: a tile sits inside a
    // clipped grid, so a menu drawn from there would be cut off at the
    // cell edge.
    property string menuAppId: ""
    property string menuAppName: ""
    property bool menuPinned: false
    property bool menuShown: false
    property real menuX: 0
    property real menuY: 0

    function openMenu(id, name, x, y) {
        win.menuAppId = id;
        win.menuAppName = name;
        win.menuPinned = Apps.pinned.indexOf(id) !== -1;
        win.menuX = x;
        win.menuY = y;
        win.menuShown = true;
    }

    function closeMenu() { win.menuShown = false; }

    // A click outside the panel closes it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: LauncherState.hide()
    }

    Rectangle {
        id: panel

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        // Just above the dock, whatever size it happens to be, plus
        // however much higher you asked for.
        anchors.bottomMargin: Theme.dockIconSize + Theme.dockDotLane
                              + Theme.dockPadding * 2 + 26
                              + (Config.data.launcherLift ?? 0)
        width: 660
        height: 480
        radius: 18
        color: Qt.rgba(0, 0, 0, 0.88)
        border.width: 1
        border.color: "#22ffffff"

        opacity: LauncherState.open ? 1 : 0
        scale: LauncherState.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Keep clicks inside from closing it.
        MouseArea { anchors.fill: parent }

        // ── Search box ───────────────────────────────────────────
        Rectangle {
            id: searchBox
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            height: 38
            radius: 10
            color: "#14ffffff"
            border.width: 1
            border.color: search.activeFocus ? Theme.accent : "#1affffff"

            Text {
                id: magnifier
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "⌕"
                color: Theme.textTertiary
                font.pixelSize: 18
            }

            TextInput {
                id: search
                anchors.left: magnifier.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.textPrimary
                font.pixelSize: 14
                clip: true
                selectByMouse: true
                focus: LauncherState.open

                onTextChanged: {
                    LauncherState.query = text;
                    // Typing searches everything: looking for something
                    // inside Favourites and being told it isn't there
                    // would be true and useless.
                    if (text !== "") LauncherState.category = "all";
                }

                Keys.onEscapePressed: {
                // Escape folds the submenu first, and only closes the
                // launcher once there is nothing left unfolded.
                if (win.menuShown) win.closeMenu();
                else if (sessionBar.openMenu !== "") sessionBar.openMenu = "";
                else LauncherState.hide();
            }
                Keys.onReturnPressed: {
                    if (win.apps.length > 0) {
                        Apps.start(win.apps[0]);
                        LauncherState.hide();
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: I18n.t.searchApps
                    color: Theme.textTertiary
                    font.pixelSize: 14
                }
            }
        }

        // ── Categories ───────────────────────────────────────────
        // KDE's menu brings however many categories it has, which here
        // is fifteen: enough to run past the bottom of the panel and
        // under the session bar. So it scrolls.
        Flickable {
            id: cats
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.top: searchBox.bottom
            anchors.topMargin: 12
            anchors.bottom: sessionBar.top
            anchors.bottomMargin: 8
            width: 132
            clip: true
            contentHeight: catList.height
            boundsBehavior: Flickable.StopAtBounds

        Column {
            id: catList
            width: parent.width
            spacing: 2

            Repeater {
                model: Apps.categories

                Item {
                    required property var modelData
                    readonly property int count:
                        (Apps.revision, Apps.categoryCounts()[modelData.id] || 0)
                    readonly property bool current: LauncherState.category === modelData.id

                    // Favourites, frequent and places are always there
                    // and are not a slice of the catalogue, so they
                    // carry a mark instead of a count, and a rule below
                    // the last of them sets the three apart.
                    readonly property string mark: ({
                        favorites: "star", recent: "clock", places: "bookmark"
                    })[modelData.id] || ""
                    readonly property bool lastFixed: modelData.id === "places"

                    visible: count > 0
                    width: parent.width
                    // The rule lives in the row's extra height, outside
                    // the highlight, which stays the size of a row.
                    height: visible ? (lastFixed ? 37 : 28) : 0

                    Rectangle {
                        id: pill
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 28
                        radius: 8
                        color: parent.current
                            ? Theme.accentSoft
                            : (cm.containsMouse ? "#14ffffff" : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: current ? Theme.textPrimary : Theme.textSecondary
                            font.pixelSize: 12
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: count
                            color: Theme.textTertiary
                            font.pixelSize: 10
                            visible: mark === ""
                        }

                        CategoryGlyph {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11; height: 11
                            visible: mark !== ""
                            kind: mark === "" ? "star" : mark
                            fill: current ? Theme.accent : Theme.textTertiary
                        }

                        MouseArea {
                            id: cm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LauncherState.category = modelData.id
                        }
                    }

                    Rectangle {
                        visible: lastFixed
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 2
                        anchors.rightMargin: 2
                        anchors.bottomMargin: 4
                        height: 1
                        color: "#18ffffff"
                    }
                }
            }
        }
        }

        // ── Recently used: two sections, not one list ────────────
        //
        // Applications and files are different kinds of thing and mix
        // badly in one grid, so each gets its own heading. A GridView
        // cannot do sections — only a ListView can — so this is a
        // column of two plain grids.
        Flickable {
            id: recentView
            anchors.left: cats.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: searchBox.bottom
            anchors.topMargin: 12
            anchors.bottom: sessionBar.top
            anchors.bottomMargin: 6
            clip: true
            visible: LauncherState.category === "recent" && LauncherState.query === ""
            contentHeight: recentColumn.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: recentColumn
                width: recentView.width
                spacing: 4

                component Heading: Text {
                    color: Theme.textTertiary
                    font.pixelSize: 10
                    font.letterSpacing: 0.6
                    topPadding: 6
                    leftPadding: 6
                }

                component Tiles: Grid {
                    property var model: []
                    width: recentColumn.width
                    columns: Math.max(1, Math.floor(width / 118))
                    Repeater {
                        model: parent.model
                        AppTile {
                            required property var modelData
                            entry: modelData
                            width: 112
                            height: 86
                            launcherWindow: win
                            onLaunched: LauncherState.hide()
                        }
                    }
                }

                Heading {
                    text: I18n.t.recentApps
                    visible: Apps.recentApps.length > 0
                }
                Tiles { model: Apps.recentApps }

                Heading {
                    text: I18n.t.recentFiles
                    visible: Apps.recentFiles.length > 0
                }
                Tiles { model: Apps.recentFiles }
            }
        }

        // ── Application grid ─────────────────────────────────────
        GridView {
            id: grid
            anchors.left: cats.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: searchBox.bottom
            anchors.topMargin: 12
            anchors.bottom: sessionBar.top
            anchors.bottomMargin: 6
            clip: true
            visible: !recentView.visible

            cellWidth: 118
            cellHeight: 92
            model: win.apps
            boundsBehavior: Flickable.StopAtBounds

            delegate: AppTile {
                required property int index
                required property var modelData

                entry: modelData
                width: grid.cellWidth - 6
                height: grid.cellHeight - 6
                launcherWindow: win
                itemIndex: index
                gridView: grid
                // Only the favourites are a list of yours to arrange;
                // everywhere else the order is not ours to change.
                reorderable: LauncherState.category === "favorites"
                             && LauncherState.query === ""
                onLaunched: LauncherState.hide()
                onReordered: (from, to) => Apps.moveFavorite(from, to)
            }
        }

        Text {
            anchors.centerIn: grid
            visible: win.apps.length === 0 && !recentView.visible
            text: I18n.t.noMatches
            color: Theme.textTertiary
            font.pixelSize: 13
        }

        // A click anywhere in the panel folds the session submenus
        // back. It sits above the grid but below the submenus
        // themselves, which carry a higher z.
        MouseArea {
            anchors.fill: parent
            enabled: sessionBar.openMenu !== "" || win.menuShown
            z: 40
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: {
                sessionBar.openMenu = "";
                win.closeMenu();
            }
        }

        AppMenu {
            appId: win.menuAppId
            appName: win.menuAppName
            pinned: win.menuPinned
            context: "launcher"
            open: win.menuShown
            onCloseRequested: win.closeMenu()
            z: 60

            // Under the pointer, kept inside the panel: a menu that
            // runs off the edge is a menu you cannot reach.
            x: Math.max(8, Math.min(panel.width - width - 8, win.menuX - panel.x - 6))
            y: Math.min(panel.height - height - 8, win.menuY - panel.y - 4)
        }

        // ── Bottom bar: power, session and settings ──────────────
        SessionBar {
            id: sessionBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.bottomMargin: 8
            onDismissed: LauncherState.hide()
        }

        // A hairline above it, to set it apart from the grid.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: sessionBar.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.bottomMargin: 2
            height: 1
            color: "#18ffffff"
        }
    }
}
