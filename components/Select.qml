import QtQuick
import "../services"

// The dropdown, in a file of its own for the same reason as FocusRing.
// Controls.qml's SelectRow_ used it, and it uses FocusRing: two inline
// components deep is where Qt 6.8 gives way, and opening the settings
// window took the whole shell with it on Debian 13.
Item {
    id: sel
    property var options: []        // [{value, label}]
    property string value: ""
    property bool expanded: false
    property string describedAs: ""
    signal picked(string value)

    readonly property int index: {
        for (let i = 0; i < sel.options.length; i++)
            if (sel.options[i].value === sel.value) return i;
        return -1;
    }

    // Closed, up and down change the choice without opening it,
    // which is what a list does everywhere else. Open, they walk
    // it and return takes what is under the mark.
    function step(by) {
        if (!sel.options.length) return;
        const at = sel.index < 0 ? 0
            : Math.max(0, Math.min(sel.options.length - 1, sel.index + by));
        sel.picked(sel.options[at].value);
    }

    activeFocusOnTab: true
    Keys.onUpPressed: sel.step(-1)
    Keys.onDownPressed: sel.step(1)
    Keys.onSpacePressed: sel.expanded = !sel.expanded
    Keys.onReturnPressed: sel.expanded = !sel.expanded
    Keys.onEnterPressed: sel.expanded = !sel.expanded
    Keys.onEscapePressed: (e) => {
        // Only ours to swallow while the list is open; otherwise it
        // belongs to whoever wants to close the window.
        if (sel.expanded) { sel.expanded = false; e.accepted = true; }
        else e.accepted = false;
    }
    // Tabbing away from a list left open leaves it hanging over
    // the rows below, which are no longer under it.
    onActiveFocusChanged: if (!sel.activeFocus) sel.expanded = false

    Accessible.role: Accessible.ComboBox
    Accessible.name: sel.describedAs
    Accessible.description: sel.current
    Accessible.onPressAction: sel.expanded = !sel.expanded

    readonly property string current: {
        for (const o of sel.options) if (o.value === sel.value) return o.label;
        return sel.value;
    }

    width: parent ? parent.width : 200
    // Its own size, worked out from nothing above it — which is
    // what keeps the row that holds it from being a loop.
    readonly property int headHeight: 30
    readonly property int listHeight: sel.options.length * 28 + 8
    height: sel.headHeight + (sel.expanded ? sel.listHeight + 6 : 0)
    Behavior on height {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
    clip: true

    // Inside, and not around: this one clips, so a ring drawn
    // outside it would be cut by the very thing it marks.
    FocusRing {
        around: sel
        anchors.fill: undefined
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 0
        height: sel.headHeight
        radius: 9
        z: 5
    }

    Rectangle {
        id: head
        width: parent.width
        height: sel.headHeight
        radius: 9
        color: headMouse.containsMouse ? "#1f1f1f" : "#1a1a1a"
        border.width: 1
        border.color: sel.expanded ? Theme.accent : "#2a2a2a"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.right: caret.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: sel.current
            color: Theme.textPrimary
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // A chevron, drawn rather than fetched: two bars meeting at
        // the point of a V. Each is turned about its own middle and
        // placed so the whole thing sits inside this box — turned
        // about an end, as it was first written, they reached past
        // it and were cut by the corner of the row.
        Item {
            id: caret
            anchors.right: parent.right
            anchors.rightMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12
            rotation: sel.expanded ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 140 } }

            // A V ten wide and five tall, centred in the box: the
            // arms are its half-diagonals, so 5√2 long at 45°.
            readonly property real arm: 7.07
            readonly property real thick: 1.4

            Rectangle {
                x: caret.width / 2 - 2.5 - caret.arm / 2
                y: (caret.height - caret.thick) / 2
                width: caret.arm; height: caret.thick
                radius: caret.thick / 2
                color: Theme.textSecondary
                rotation: 45
            }
            Rectangle {
                x: caret.width / 2 + 2.5 - caret.arm / 2
                y: (caret.height - caret.thick) / 2
                width: caret.arm; height: caret.thick
                radius: caret.thick / 2
                color: Theme.textSecondary
                rotation: -45
            }
        }

        MouseArea {
            id: headMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sel.expanded = !sel.expanded
        }
    }

    Rectangle {
        id: list
        anchors.top: head.bottom
        anchors.topMargin: 6
        width: parent.width
        height: sel.listHeight
        radius: 9
        color: "#151515"
        border.width: 1
        border.color: "#2a2a2a"
        clip: true
        visible: opacity > 0
        opacity: sel.expanded ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Column {
            id: inner
            width: parent.width
            y: 4

            Repeater {
                model: sel.options

                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 28
                    color: modelData.value === sel.value ? "#1fffffff"
                         : (itemMouse.containsMouse ? "#14ffffff" : "transparent")

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.right: parent.right
                        anchors.rightMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label
                        color: parent.modelData.value === sel.value
                            ? Theme.textPrimary : Theme.textSecondary
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sel.picked(parent.modelData.value);
                            sel.expanded = false;
                        }
                    }
                }
            }
        }
    }
}

