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

    // It needs the keyboard so you can type the moment it opens — but
    // only one of them does. See LauncherState.focusScreen.
    WlrLayershell.keyboardFocus:
        (win.visible && LauncherState.focusScreen === win.screenName)
            ? WlrKeyboardFocus.Exclusive
            : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (win.visible && LauncherState.focusScreen === "")
            LauncherState.focusScreen = win.screenName;
        else if (!win.visible && LauncherState.focusScreen === win.screenName)
            LauncherState.focusScreen = "";
    }
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

    // Worked out once in LauncherState, because there is one of these
    // windows per screen and they all show the same thing: done here,
    // every keystroke walked the catalogue once per monitor.
    readonly property var apps: LauncherState.apps
    readonly property var clips: LauncherState.clips

    Connections {
        target: LauncherState
        function onOpenChanged() { win.selected = -1; }
        function onCategoryChanged() { win.selected = -1; }
        function onQueryChanged() { win.selected = -1; }
    }

    // ── Moving without the mouse ─────────────────────────────────
    //
    // It opens on a key and it used to take a hand off the keyboard to
    // finish. Up and down move through whichever view is showing, and
    // return opens what is marked.
    //
    // Up and down and not the four arrows: left and right belong to
    // the text you are typing, and a launcher that eats them to move
    // sideways in a grid is a launcher you cannot correct a typo in.
    // In a grid, one step is the next cell along and then the row
    // below, which is the order the eye reads them in anyway.
    property int selected: -1


    readonly property int navCount: {
        if (clipView.visible) return win.clips.length;
        // The search view holds two sections, the applications and
        // then the files, and they are walked as one list.
        if (searchView.visible) return win.apps.length + Search.files.length;
        if (grid.visible) return win.apps.length;
        return 0;
    }

    function navMove(by) {
        if (win.navCount === 0) return;
        const from = win.selected < 0 ? (by > 0 ? -1 : win.navCount) : win.selected;
        win.selected = Math.max(0, Math.min(win.navCount - 1, from + by));
        if (grid.visible)
            grid.positionViewAtIndex(win.selected, GridView.Contain);
    }

    // What return does. False means nothing was marked, and the caller
    // falls back to what it did before: open the first result.
    function navActivate() {
        if (win.selected < 0 || win.selected >= win.navCount) return false;

        if (clipView.visible) Clipboard.copy(win.clips[win.selected]);
        else if (searchView.visible) {
            const i = win.selected;
            Apps.start(i < win.apps.length
                ? win.apps[i] : Search.files[i - win.apps.length]);
        }
        else if (grid.visible) Apps.start(win.apps[win.selected]);
        else return false;

        LauncherState.hide();
        return true;
    }


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
                              + Config.number(Config.data.launcherLift, 0, 0, 1000)
        width: 660
        height: 480
        radius: 18
        color: Theme.launcherBg
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
                    Search.query = text;
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
                Keys.onDownPressed: win.navMove(1)
                Keys.onUpPressed: win.navMove(-1)

                Keys.onReturnPressed: {
                    if (win.navActivate()) return;
                    if (LauncherState.category === "clipboard") {
                        if (win.clips.length > 0) {
                            Clipboard.copy(win.clips[0]);
                            LauncherState.hide();
                        }
                        return;
                    }
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
                        Apps.categoryCounts[modelData.id] || 0
                    readonly property bool current: LauncherState.category === modelData.id

                    // Favourites, frequent, places and the clipboard
                    // are not a slice of the catalogue, so they carry a
                    // mark instead of a count, and a rule below the
                    // last of them sets the four apart.
                    readonly property string mark: ({
                        favorites: "star", recent: "clock", places: "bookmark",
                        clipboard: "clipboard"
                    })[modelData.id] || ""
                    readonly property bool lastFixed: modelData.id === "clipboard"

                    // Empty ones stay out of the way, except the
                    // clipboard: what it has to say when it is empty —
                    // that the tool is missing, or that it is switched
                    // off — can only be read by opening it.
                    visible: count > 0 || modelData.id === "clipboard"
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
        // The room every view is drawn in: what is left between the
        // sidebar, the search field and the bar along the bottom. The
        // four of them each spelled out the same eight anchors, and a
        // fifth would have spelled them a fifth time.
        Item {
            id: stage
            anchors.left: cats.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            // Same as the search field above, so the rows line up with
            // it instead of running past its edge.
            anchors.rightMargin: 14
            anchors.top: searchBox.bottom
            anchors.topMargin: 12
            anchors.bottom: sessionBar.top
            anchors.bottomMargin: 6
        }

        // ── The clipboard ────────────────────────────────────────
        //
        // Shima puts Plasma's panels away, and Plasma's clipboard
        // history lives inside one of them, so it went with them. This
        // is what is in its place: the search box above filters it,
        // and it stays under the same category whether or not anything
        // has been typed, because searching your clipboard is the
        // whole point of having a list of it.
        Flickable {
            id: clipView
            anchors.fill: stage
            clip: true
            visible: LauncherState.category === "clipboard"
            contentHeight: clipColumn.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: clipColumn
                width: clipView.width
                spacing: 3

                // Only when there is a list to empty, and never as the
                // first thing under the pointer.
                Item {
                    width: parent.width
                    height: 24
                    visible: Clipboard.entries.length > 0

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t.clipboardClear
                        color: clearArea.containsMouse ? "#f87171" : Theme.textTertiary
                        font.pixelSize: 11

                        MouseArea {
                            id: clearArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Clipboard.forget()
                        }
                    }
                }

                Repeater {
                    model: win.clips

                    Rectangle {
                        id: clipRow
                        required property var modelData
                        required property int index
                        readonly property bool isImage: modelData.kind === "image"

                        width: clipColumn.width
                        height: isImage ? 52 : 34
                        radius: 8
                        readonly property bool marked: win.selected === index
                        color: (clipArea.containsMouse || marked)
                            ? "#1fffffff" : "transparent"

                        // Pictures show themselves. A thumbnail says
                        // which one it is and a filename would not,
                        // since nothing here has one.
                        Image {
                            id: thumb
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: clipRow.isImage
                            height: 36
                            width: 60
                            fillMode: Image.PreserveAspectFit
                            horizontalAlignment: Image.AlignLeft
                            asynchronous: true
                            cache: false
                            source: clipRow.isImage
                                ? "file://" + clipRow.modelData.path : ""
                        }

                        Text {
                            anchors.left: clipRow.isImage ? thumb.right : parent.left
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: clipRow.isImage
                                ? (thumb.sourceSize.width > 0
                                    ? thumb.sourceSize.width + " × "
                                      + thumb.sourceSize.height
                                    : I18n.t.clipboardImage)
                                : Clipboard.preview(clipRow.modelData)
                            color: clipRow.isImage ? Theme.textTertiary
                                                   : Theme.textPrimary
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: clipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Clipboard.copy(clipRow.modelData);
                                LauncherState.hide();
                            }
                        }
                    }
                }

                // Three things can be true here and they are not the
                // same: the tool is missing, it is switched off, or
                // nothing has been copied yet.
                Text {
                    width: parent.width
                    topPadding: 10
                    leftPadding: 6
                    visible: win.clips.length === 0
                    wrapMode: Text.WordWrap
                    text: !Clipboard.available ? I18n.t.clipboardNoTool
                        : !Clipboard.wanted ? I18n.t.clipboardOff
                        : I18n.t.clipboardEmpty
                    color: Theme.textTertiary
                    font.pixelSize: 12
                }
            }
        }

        Flickable {
            id: recentView
            anchors.fill: stage
            clip: true
            visible: LauncherState.category === "recent" && LauncherState.query === ""
                     && !clipView.visible
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

        // ── Search results: applications, then everything else ───
        Flickable {
            id: searchView
            anchors.fill: stage
            clip: true
            visible: LauncherState.query !== "" && !clipView.visible
                     && (Search.answer !== "" || Search.searching
                         || Search.files.length > 0 || Search.command !== "")
            contentHeight: searchColumn.height
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: searchColumn
                width: searchView.width
                spacing: 4

                // First, and drawn like the answer to a sum: if what you
                // typed is something that can be run, that is almost
                // certainly what you meant, and it would be lost among
                // the files otherwise.
                Rectangle {
                    width: parent.width
                    height: visible ? 40 : 0
                    visible: Search.command !== ""
                    radius: 10
                    color: cmdArea.containsMouse ? "#18ffffff" : "#0dffffff"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    ControlGlyph {
                        id: cmdIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13; height: 13
                        kind: "back"
                        rotation: 180
                        fill: Theme.textSecondary
                    }

                    Text {
                        anchors.left: cmdIcon.right
                        anchors.leftMargin: 10
                        anchors.right: hint.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: LauncherState.query
                        color: Theme.textPrimary
                        font.pixelSize: 13
                        font.family: "monospace"
                        elide: Text.ElideRight
                    }

                    Text {
                        id: hint
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t.runCommand
                        color: Theme.textTertiary
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: cmdArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Search.runCommand(); LauncherState.hide(); }
                    }
                }

                // The answer to a sum, which is what you wanted the
                // moment you typed one. Clicking it copies it.
                Rectangle {
                    width: parent.width
                    height: visible ? 46 : 0
                    visible: Search.answer !== ""
                    radius: 10
                    color: answerArea.containsMouse ? "#18ffffff" : "#0dffffff"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: "=  " + Search.answer
                        color: Theme.textPrimary
                        font.pixelSize: 17
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.t.copyResult
                        color: Theme.textTertiary
                        font.pixelSize: 10
                    }

                    MouseArea {
                        id: answerArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Search.copyAnswer(); LauncherState.hide(); }
                    }
                }

                Text {
                    text: I18n.t.recentApps
                    visible: win.apps.length > 0
                    color: Theme.textTertiary
                    font.pixelSize: 10
                    font.letterSpacing: 0.6
                    topPadding: 6
                    leftPadding: 6
                }

                Grid {
                    width: searchColumn.width
                    columns: Math.max(1, Math.floor(width / 118))
                    Repeater {
                        model: win.apps
                        AppTile {
                            required property var modelData
                            required property int index
                            entry: modelData
                            marked: win.selected === index
                            width: 112
                            height: 86
                            launcherWindow: win
                            onLaunched: LauncherState.hide()
                        }
                    }
                }

                // The files take a moment longer than the applications,
                // since they come off the disk. The section claims its
                // place as soon as the search starts and fills in when
                // the answer arrives, instead of appearing all at once
                // and shoving everything above it.
                Text {
                    text: I18n.t.recentFiles
                    visible: Search.searching || Search.files.length > 0
                    color: Theme.textTertiary
                    font.pixelSize: 10
                    font.letterSpacing: 0.6
                    topPadding: 6
                    leftPadding: 6
                }

                Item {
                    width: searchColumn.width
                    visible: Search.searching || Search.files.length > 0
                    height: Search.files.length > 0 ? fileGrid.height : 86
                    Behavior on height {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        text: I18n.t.searching
                        color: Theme.textTertiary
                        font.pixelSize: 11
                        opacity: Search.files.length === 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    Grid {
                        id: fileGrid
                        width: parent.width
                        columns: Math.max(1, Math.floor(width / 118))
                        opacity: Search.files.length > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

                        Repeater {
                            model: Search.files
                            AppTile {
                                required property var modelData
                                required property int index
                                entry: modelData
                                // After the applications above, since
                                // the two sections are walked as one.
                                marked: win.selected === win.apps.length + index
                                width: 112
                                height: 86
                                launcherWindow: win
                                onLaunched: LauncherState.hide()
                            }
                        }
                    }
                }
            }
        }

        // ── Application grid ─────────────────────────────────────
        GridView {
            id: grid
            anchors.fill: stage
            clip: true
            visible: !recentView.visible && !searchView.visible && !clipView.visible

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
                marked: win.selected === index
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
            visible: win.apps.length === 0 && !recentView.visible && !clipView.visible
                     && !searchView.visible
            text: I18n.t.noMatches
            color: Theme.textTertiary
            font.pixelSize: 13
        }

        // A click anywhere in the panel folds the session submenus
        // back — anywhere except the bar itself, which is given a
        // higher z below so its own clicks reach it. The submenus
        // carry a z of their own too, but that one counts only among
        // their siblings inside the bar: from out here the whole bar
        // is one item, and while this sat above it, the click that
        // should have swapped one submenu for the other was spent
        // closing the first.
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
            z: 45
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

