import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// Menu for a dock icon. It lives inside the dock's window, so it draws
// over the pill without needing a window of its own.
//
// Besides open and pin, it lists the actions the application declares
// in its .desktop file ("New window", "New private window"...), which
// is where Plasma's own task manager gets them too, already translated
// by the system.
Rectangle {
    id: root
    property string appId: ""
    property string appName: ""
    property bool open: false
    property bool pinned: true
    signal closeRequested()

    readonly property var entry: (Apps.revision, Apps.entryFor(root.appId))
    readonly property var actions: root.entry ? (root.entry.actions || []) : []

    readonly property bool running: (Apps.revision, Apps.isRunning(root.appId))

    readonly property var items: {
        const out = [{ label: "Abrir", icon: "", kind: "open", danger: false, sep: false }];

        // Whatever the application declares in its .desktop.
        for (const a of root.actions)
            out.push({ label: a.name, icon: a.icon || "", kind: "action",
                       danger: false, sep: false, action: a });

        // Apps that declare nothing still deserve a way to open a
        // second instance, which is the action almost all of them would
        // have declared anyway.
        if (root.actions.length === 0)
            out.push({ label: "Nueva ventana", icon: "window-new", kind: "new",
                       danger: false, sep: false });

        // Closing needs a window to act on. Minimising is not here on
        // purpose: clicking the icon already does it.
        if (root.running && Apps.hasKdotool)
            out.push({ label: "Cerrar", icon: "window-close", kind: "close",
                       danger: false, sep: true });

        out.push({ label: root.pinned ? "Quitar del dock" : "Anclar al dock",
                   icon: root.pinned ? "list-remove" : "pin",
                   kind: "pin", danger: root.pinned, sep: true });
        return out;
    }

    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    z: 100

    width: 186
    height: col.height + 10
    radius: 10
    color: "#fa121212"
    border.width: 1
    border.color: "#2a2a2a"

    Behavior on opacity { NumberAnimation { duration: 130 } }
    Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    Column {
        id: col
        y: 5
        width: parent.width
        spacing: 1

        Text {
            x: 10
            width: parent.width - 20
            height: 22
            verticalAlignment: Text.AlignVCenter
            text: root.appName
            color: Theme.textTertiary
            font.pixelSize: 10
            font.bold: true
            elide: Text.ElideRight
        }

        Repeater {
            model: root.items

            Item {
                required property var modelData
                required property int index

                width: root.width
                height: modelData.sep ? 33 : 26

                // A hairline before the dock's own entries, so the
                // application's actions read as a separate group.
                Rectangle {
                    visible: modelData.sep && index > 0
                    x: 8
                    width: parent.width - 16
                    height: 1
                    color: "#22ffffff"
                }

                Rectangle {
                    x: 4
                    y: modelData.sep ? 7 : 0
                    width: root.width - 8
                    height: 26
                    radius: 6
                    color: ma.containsMouse
                        ? (modelData.danger ? "#33f87171" : "#1fffffff")
                        : "transparent"

                    IconImage {
                        id: actionIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13; height: 13
                        visible: modelData.icon !== ""
                        source: modelData.icon
                            ? Quickshell.iconPath(modelData.icon, "") : ""
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: modelData.icon !== "" ? 27 : 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: modelData.danger ? "#f87171" : Theme.textPrimary
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            switch (modelData.kind) {
                                case "open":     Apps.launch(root.appId); break;
                                case "action":   modelData.action.execute(); break;
                                case "new":      Apps.launchNew(root.appId); break;
                                case "close":    Apps.closeWindow(root.appId); break;
                                case "pin":
                                    if (root.pinned) Apps.unpin(root.appId);
                                    else             Apps.pin(root.appId);
                                    break;
                            }
                            root.closeRequested();
                        }
                    }
                }
            }
        }
    }
}
