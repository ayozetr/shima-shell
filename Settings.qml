import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Widgets
import "services"
import "components"

FloatingWindow {
    id: win

    // Through a Binding and not a plain one, and the two are not the
    // same thing here. Closing the window with its own button writes
    // visible from outside, which throws a plain binding away for
    // good: the singleton stayed saying it was open, nothing could put
    // it back on screen, and Settings was gone until the shell was
    // restarted. A Binding object survives that and applies again the
    // next time it is asked for.
    Binding {
        target: win
        property: "visible"
        value: SettingsWindow.open
    }

    // And the other direction, so closing it by hand is the same as
    // closing it from the dock.
    onVisibleChanged: if (!win.visible) SettingsWindow.hide()

    // Wider than it is tall, which is the other way round from how it
    // started. Everything used to be one column: sixty-odd rows and
    // eleven headings, some five screens of scrolling to reach the
    // language, and a window narrow enough that a control with nine
    // options in it had twenty-four pixels for each. Down the side
    // now, and each page is short enough to read without scrolling.
    implicitWidth: 760
    implicitHeight: 620
    title: I18n.t.settingsWindowTitle
    color: "#0e0e0e"

    readonly property var pages: [
        { id: "general",  label: I18n.t.pageGeneral,  icon: "preferences-desktop" },
        { id: "dock",     label: I18n.t.pageDock,     icon: "computer" },
        { id: "launcher", label: I18n.t.pageLauncher, icon: "view-grid" },
        { id: "island",   label: I18n.t.pageIsland,   icon: "view-media-visualization" },
        { id: "notifications", label: I18n.t.pageNotifications, icon: "preferences-desktop-notification" },
        { id: "weather",  label: I18n.t.pageWeather,  icon: "weather-clear" },
        { id: "about",    label: I18n.t.pageAbout,    icon: "help-about" }
    ]
    property string page: "general"
    onPageChanged: flick.contentY = 0

    // Closing with the keyboard, from wherever the focus is. The list
    // that opens inside the general page swallows this while it is
    // open, so the first press closes the list and the second the
    // window — which is the order anyone expects.
    Shortcut {
        sequences: ["Escape"]
        onActivated: SettingsWindow.hide()
    }

    // Walking the pages. The whole sidebar answers to the arrows, so
    // the keys work from whichever page button has the focus.
    function stepPage(by) {
        let at = 0;
        for (let i = 0; i < win.pages.length; i++)
            if (win.pages[i].id === win.page) at = i;
        at = Math.max(0, Math.min(win.pages.length - 1, at + by));
        win.page = win.pages[at].id;
    }

    Rectangle {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 188
        color: "#141414"

        // One stop for the whole sidebar, not one per page. The tab
        // key reaches it, the arrows walk the pages inside it, and the
        // next tab goes into the page itself — six stops before the
        // first setting would be five too many. It is also what keeps
        // Qt from being asked to take the tab stop away from a button
        // that has the focus in its hands, which it refuses to do.
        FocusScope {
            id: sideFocus
            anchors.fill: parent
            activeFocusOnTab: true
            focus: true

            Keys.onUpPressed: win.stepPage(-1)
            Keys.onDownPressed: win.stepPage(1)
            Keys.onPressed: (e) => {
                if (e.key === Qt.Key_Home) {
                    win.page = win.pages[0].id;
                    e.accepted = true;
                } else if (e.key === Qt.Key_End) {
                    win.page = win.pages[win.pages.length - 1].id;
                    e.accepted = true;
                }
            }

            Accessible.role: Accessible.PageTabList
            Accessible.name: I18n.t.settingsTitle

        Column {
            anchors.fill: parent
            anchors.margins: 14
            anchors.topMargin: 20
            spacing: 2

            Text {
                text: I18n.t.settingsTitle
                color: Theme.textPrimary
                font.pixelSize: 16
                font.weight: Font.DemiBold
                leftPadding: 10
                bottomPadding: 2
            }
            Text {
                text: I18n.t.settingsSubtitle
                color: Theme.textTertiary
                font.pixelSize: 10
                leftPadding: 10
                bottomPadding: 12
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Repeater {
                model: win.pages

                Rectangle {
                    id: pageButton
                    required property var modelData
                    readonly property bool current: win.page === modelData.id

                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.label
                    Accessible.checked: current
                    Accessible.onPressAction: win.page = modelData.id

                    // The ring marks the page in hand, and only while
                    // the keyboard is in the sidebar at all.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        radius: 12
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.accent
                        visible: pageButton.current && sideFocus.activeFocus
                    }

                    width: parent.width
                    height: 34
                    radius: 9
                    color: current ? Theme.accent
                                   : (tab.containsMouse ? "#14ffffff" : "transparent")
                    Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

                    IconImage {
                        id: tabIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: Quickshell.iconPath(parent.modelData.icon, true)
                        opacity: parent.current ? 1 : 0.7
                    }

                    Text {
                        anchors.left: tabIcon.right
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label
                        color: parent.current ? Theme.accentText : Theme.textSecondary
                        font.pixelSize: 12
                        font.weight: parent.current ? Font.DemiBold : Font.Normal
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: tab
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            win.page = parent.modelData.id;
                            sideFocus.forceActiveFocus();
                        }
                    }
                }
            }
        }
        }
    }

    // The page itself. Each one is a Column of rows in its own file;
    // this only decides which and gives it somewhere to scroll.
    Flickable {
        id: flick
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // Room for the focus ring, which is drawn four pixels outside
        // whatever it marks. The controls sit against the right edge
        // of the page, so without this the ring was cut in half by the
        // very thing that scrolls them — and the same at the top, for
        // the first control on the page.
        anchors.margins: 17
        contentHeight: pageLoader.height + 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // The height changes for two very different reasons, and this
        // used to treat them alike. Changing page should start at the
        // top — arriving halfway down a page you have not seen reads
        // as something being missing — but a setting that shows or
        // hides the row below it changes the height as well, and
        // being thrown back to the top for ticking a box is the
        // window losing your place. So the page change is handled
        // where it happens, and this only keeps the view from ending
        // up past the end of a page that just got shorter.
        onContentHeightChanged: {
            flick.returnToBounds();
            // Something appeared or went away. If it appeared under
            // the control you are working with, it is worth showing:
            // a message nobody scrolls down to find is a message that
            // was not given.
            flick.follow(flick.focused, 48);
        }

        // Asked of the window through the attached property rather
        // than of the window object: what Quickshell hands out here is
        // a proxy, and the real window is underneath it.
        readonly property Item focused: Window.activeFocusItem
        onFocusedChanged: flick.follow(flick.focused)

        // Tabbing to something below the fold has to bring it into
        // view, or the keyboard walks off the bottom of the window and
        // nothing appears to happen.
        // `extra` is room to leave underneath: something that appeared
        // below what you were using and would otherwise be off the
        // bottom of the window — the line that says which shortcut you
        // just took a key from, for one, which is written under the
        // last row on its page.
        function follow(item, extra) {
            if (!item || item === flick || !flick.contentItem) return;
            const p = item.mapToItem(flick.contentItem, 0, 0);
            // Anything to the left of us is the sidebar, not a setting.
            if (p.x < 0) return;
            const top = p.y - 14;
            const bottom = p.y + item.height + 14 + (extra || 0);
            if (top < flick.contentY)
                flick.contentY = Math.max(0, top);
            else if (bottom > flick.contentY + flick.height)
                flick.contentY = Math.min(
                    Math.max(0, flick.contentHeight - flick.height),
                    bottom - flick.height);
        }

        Loader {
            id: pageLoader
            x: 5
            y: 5
            width: parent.width - 10
            sourceComponent: {
                switch (win.page) {
                    case "dock":          return dockPage;
                    case "launcher":      return launcherPage;
                    case "island":        return islandPage;
                    case "notifications": return notificationsPage;
                    case "weather":       return weatherPage;
                    case "about":         return aboutPage;
                    default:              return generalPage;
                }
            }
        }
    }

    Component { id: generalPage;       SettingsGeneral {} }
    Component { id: dockPage;          SettingsDock {} }
    Component { id: launcherPage;      SettingsLauncher {} }
    Component { id: islandPage;        SettingsIsland {} }
    Component { id: notificationsPage; SettingsNotifications {} }
    Component { id: weatherPage;       SettingsWeather {} }
    Component { id: aboutPage;         SettingsAbout {} }
}
