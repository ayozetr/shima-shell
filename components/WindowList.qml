import QtQuick
import "../services"

// The windows of an application, offered by title. Opened with a
// middle click on its dock icon, for when stepping through them one by
// one is slower than just picking the one you want.
Rectangle {
    id: root
    property string appId: ""
    property string appName: ""
    property bool open: false
    signal closeRequested()

    readonly property var windows: Windows.forAppId === root.appId ? Windows.list : []

    visible: opacity > 0
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    z: 100

    width: 280
    height: col.height + 10
    // The panel follows its contents, and a row leaving makes the
    // contents shorter by its whole height in one frame. Closing a
    // window of four then snapped the panel up under the pointer.
    Behavior on height {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
    radius: 10
    color: "#fa121212"
    border.width: 1
    border.color: "#2a2a2a"

    Behavior on opacity { NumberAnimation { duration: 130 } }
    Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    // The rows are kept here and brought into line with what the
    // service reports, rather than being the service's list itself.
    //
    // That list is replaced whole every time the windows are read
    // again, and a Repeater handed a new array throws away every row
    // and builds them all afresh. Closing one window of four therefore
    // rebuilt the other three as well: they blinked, took a frame to
    // find their places, and settled — on a list that had not changed.
    // Matching by window id instead, the only row that goes is the one
    // whose window went, and the rest are never touched.
    ListModel { id: rows }

    function sync() {
        const src = root.windows;

        // Gone first, so the indices below are the ones that remain.
        for (let i = rows.count - 1; i >= 0; i--) {
            let still = false;
            for (const w of src) if (w.id === rows.get(i).winId) { still = true; break; }
            if (!still) rows.remove(i);
        }

        for (let j = 0; j < src.length; j++) {
            const w = src[j];
            const title = w.title || "";
            let at = -1;
            for (let i = 0; i < rows.count; i++)
                if (rows.get(i).winId === w.id) { at = i; break; }

            if (at === -1) { rows.insert(j, { winId: w.id, title: title }); continue; }
            // A window that was renamed keeps its row: setting the
            // text is not the same as replacing the row that holds it.
            if (rows.get(at).title !== title) rows.setProperty(at, "title", title);
            if (at !== j) rows.move(at, j, 1);
        }
    }

    onWindowsChanged: root.sync()
    Component.onCompleted: root.sync()

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
            model: rows

            Rectangle {
                id: rowItem
                required property string winId
                required property string title

                // Set when its own cross is pressed, and nothing else
                // sets it. The list is read again rather than edited,
                // which is right -- an application asked to close may
                // stop and ask you whether to save, and a row that
                // vanished on the asking would be a lie. But the
                // reading lands a third of a second later and replaces
                // every row at once, so there is nothing left to
                // animate: the row you clicked disappears and the ones
                // under it jump up to fill the gap.
                //
                // So the row you clicked folds itself away first. By
                // the time the new list arrives the shape it brings is
                // the shape already on screen, and the replacement is
                // not seen. If the close is called off, the second
                // reading a second later brings the row back.
                property bool closing: false

                x: 4
                width: root.width - 8
                height: rowItem.closing ? 0 : 28
                opacity: rowItem.closing ? 0 : 1
                clip: true
                Behavior on height {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
                Behavior on opacity { NumberAnimation { duration: 110 } }
                radius: 6
                color: ma.containsMouse ? "#1fffffff" : "transparent"

                Rectangle {
                    id: bullet
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5; height: 5; radius: 2.5
                    color: "#55ffffff"
                }

                Text {
                    anchors.left: bullet.right
                    anchors.leftMargin: 9
                    anchors.right: parent.right
                    // Room for the cross is kept whether it is showing
                    // or not. Taken only while hovering, every title
                    // would shift sideways as the pointer went down
                    // the list, and a line of text that moves while
                    // you are reading it is worse than one that sits
                    // a little short of the edge.
                    anchors.rightMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.title !== "" ? rowItem.title : I18n.t.untitled
                    color: Theme.textPrimary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Windows.activate(rowItem.winId);
                        root.closeRequested();
                    }
                }

                // Only while the row is under the pointer: a column of
                // crosses sitting there all the time reads as a list
                // of things to delete rather than a list of windows to
                // go to, and going to one is what this is for.
                //
                // After the MouseArea above, so it takes the click
                // instead of it. Closing a window and raising it are
                // not a mistake you want to be one pixel away from.
                Item {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18
                    height: 18
                    opacity: (ma.containsMouse || closeMa.containsMouse) ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 90 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 5
                        color: closeMa.containsMouse ? "#33ffffff" : "transparent"
                    }

                    Repeater {
                        model: [45, -45]
                        Rectangle {
                            required property int modelData
                            anchors.centerIn: parent
                            width: 9
                            height: 1.5
                            radius: 0.75
                            rotation: modelData
                            color: closeMa.containsMouse
                                   ? Theme.textPrimary : Theme.textTertiary
                        }
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            rowItem.closing = true;
                            Windows.closeWindow(rowItem.winId);
                        }
                    }
                }
            }
        }

        Text {
            x: 10
            height: 26
            verticalAlignment: Text.AlignVCenter
            visible: root.windows.length === 0
            text: I18n.t.searchingWindows
            color: Theme.textTertiary
            font.pixelSize: 11
        }
    }
}
