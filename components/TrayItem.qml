import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../services"

// One icon from the system tray.
//
// These come from the applications themselves over StatusNotifierItem,
// so Discord, Steam or Ubisoft Connect appear here with the very menu
// they would show in Plasma's panel. Nothing to reimplement per app.
Item {
    id: root
    property SystemTrayItem item: null
    property var dockWindow: null

    readonly property int side: Math.round(Theme.dockIconSize * 0.62)

    width: side
    height: Theme.dockIconSize + Theme.dockDotLane

    Rectangle {
        id: tile
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round((Theme.dockIconSize - root.side) / 2)
        width: root.side
        height: root.side
        radius: Math.round(root.side * 0.333)
        color: ma.containsMouse ? "#1affffff" : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        scale: ma.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

        // A plain Image, not IconImage: the tray hands over a ready
        // URL (image://qspixmap/… for icons the app embeds, or
        // image://icon/… for themed ones), not a bare icon name.
        Image {
            anchors.centerIn: parent
            width: Math.round(root.side * 0.62)
            height: width
            source: root.item ? root.item.icon : ""
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: (e) => {
            if (!root.item) return;

            // Some items only offer a menu and ignore activation, which
            // is what onlyMenu tells us: clicking them should open it
            // rather than appear to do nothing.
            if (e.button === Qt.RightButton
                || (e.button === Qt.LeftButton && root.item.onlyMenu)) {
                root.showMenu();
                return;
            }

            if (e.button === Qt.LeftButton) root.item.activate();
            else if (e.button === Qt.MiddleButton) root.item.secondaryActivate();
        }

        onWheel: (e) => {
            if (!root.item) return;
            root.item.scroll(e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x,
                             e.angleDelta.y === 0);
        }
    }

    // The application's own menu, shown natively: rebuilding it here
    // would mean reimplementing every app's entries and their state.
    //
    // Two kinds of icon, and only one of them hands us a menu. An
    // application can publish one over DBusMenu, which is what most
    // native programs do and what `display` shows. Or it can publish
    // none and expect to be asked through its own `ContextMenu`
    // method, drawing the menu itself — which is how every Windows
    // program under Wine arrives, its icon owned by Wine's explorer
    // and bridged into the tray by xembedsniproxy.
    //
    // This used to give up on the second kind without a word: right
    // clicking Ubisoft Connect did nothing at all, with nothing to
    // suggest why. Quickshell does not expose `ContextMenu`, so the
    // asking is done by a helper — `gi` is already required for the
    // shortcuts and Gio speaks D-Bus.
    //
    // Where the menu appears is then the application's own business.
    // Wine puts it where it likes, which is not necessarily beside the
    // dock, and there is nothing to be done about that from here.
    function showMenu() {
        if (!root.item) return;

        if (root.item.hasMenu) {
            if (!root.dockWindow) return;
            const p = root.mapToItem(null, root.width / 2, 0);
            root.item.display(root.dockWindow, p.x, p.y);
            return;
        }

        if (root.helper === "" || !root.item.id) return;
        const g = root.mapToGlobal(root.width / 2, 0);
        Quickshell.execDetached([root.helper, root.item.id,
                                 String(Math.round(g.x)),
                                 String(Math.round(g.y))]);
    }

    // Detached and not watched, because there is nothing to wait for
    // and nothing it could tell us that we would act on: the helper is
    // silent by design and the menu, if it comes, is drawn by somebody
    // else's process.
    readonly property string helper:
        Paths.dataDir !== "" ? Paths.dataDir + "/helper/shima-tray-menu" : ""

    ToolTipLabel {
        show: ma.containsMouse && (Config.data.showAppNames ?? true)
              && !(root.dockWindow && root.dockWindow.popupOpen)
              && root.item && (root.item.tooltipTitle || root.item.title) !== ""
        text: root.item ? (root.item.tooltipTitle || root.item.title) : ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 10
    }
}
