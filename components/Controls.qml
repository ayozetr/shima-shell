import QtQuick
import "../services"

// The settings window controls. They share one file because they are
// only used there and splitting them up would gain nothing.
Item {
    id: lib

    // ── Row with a label on the left and a control on the right ──
    component Row_: Item {
        id: row
        property string label: ""
        property string hint: ""
        default property alias content: holder.data

        implicitHeight: Math.max(44, text.implicitHeight + 20)
        width: parent ? parent.width : 0

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.44
            spacing: 2
            Text {
                id: text
                text: row.label
                color: Theme.textPrimary
                font.pixelSize: 13
            }
            Text {
                text: row.hint
                visible: row.hint !== ""
                color: Theme.textTertiary
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }

        Item {
            id: holder
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.52
            height: parent.height
        }
    }

    // ── Slider ───────────────────────────────────────────────────
    component Slider_: Item {
        id: sl
        property real value: 0
        property real from: 0
        property real to: 1
        property real step: 0.01
        property string suffix: ""
        signal moved(real value)

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: parent ? parent.width : 200
        height: 20

        readonly property real ratio: (sl.value - sl.from) / (sl.to - sl.from)

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: parent.width - 52
            height: ma.containsMouse || ma.pressed ? 6 : 4
            radius: height / 2
            color: Theme.trackBg
            Behavior on height { NumberAnimation { duration: Theme.hoverDuration } }

            Rectangle {
                width: Math.max(0, Math.min(1, sl.ratio)) * parent.width
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }

            Rectangle {
                x: Math.max(0, Math.min(1, sl.ratio)) * parent.width - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12; radius: 6
                color: "#ffffff"
                scale: ma.pressed ? 1.2 : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: (sl.step >= 1 ? Math.round(sl.value) : sl.value.toFixed(2)) + sl.suffix
            color: Theme.textSecondary
            font.pixelSize: 11
        }

        MouseArea {
            id: ma
            anchors.left: parent.left
            width: track.width
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function apply(mx) {
                const r = Math.max(0, Math.min(1, mx / width));
                let v = sl.from + r * (sl.to - sl.from);
                v = Math.round(v / sl.step) * sl.step;
                sl.moved(v);
            }
            onPressed: (e) => apply(e.x)
            onPositionChanged: (e) => { if (pressed) apply(e.x); }
        }
    }

    // ── Toggle ───────────────────────────────────────────────────
    component Toggle_: Rectangle {
        id: tg
        property bool checked: false
        signal toggled(bool value)

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: 42; height: 24; radius: 12
        color: tg.checked ? Theme.accent : "#3a3a3a"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Rectangle {
            x: tg.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 9
            color: tg.checked ? Theme.accentText : "#ffffff"
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tg.toggled(!tg.checked)
        }
    }

    // ── Option picker ────────────────────────────────────────────
    component Choice_: Rectangle {
        id: ch
        property var options: []        // [{value, label}]
        property string value: ""
        signal picked(string value)

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: parent ? parent.width : 200
        height: 30
        radius: 9
        color: "#1a1a1a"
        border.width: 1
        border.color: "#2a2a2a"

        Row {
            anchors.fill: parent
            anchors.margins: 3
            spacing: 3

            Repeater {
                model: ch.options
                Rectangle {
                    width: (ch.width - 6 - (ch.options.length - 1) * 3) / ch.options.length
                    height: parent.height
                    radius: 7
                    color: modelData.value === ch.value ? Theme.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: modelData.value === ch.value ? Theme.accentText : Theme.textSecondary
                        font.pixelSize: 11
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ch.picked(modelData.value)
                    }
                }
            }
        }
    }

    // ── Colour swatches ──────────────────────────────────────────
    component Swatches_: Row {
        id: sw
        property var colors: []
        property string value: ""
        signal picked(string value)

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        spacing: 8

        Repeater {
            model: sw.colors
            Rectangle {
                width: 22; height: 22; radius: 11
                color: modelData
                border.width: modelData === sw.value ? 2 : 0
                border.color: "#ffffff"
                scale: modelData === sw.value ? 1.1 : 1
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sw.picked(modelData)
                }
            }
        }
    }

    // ── Button ───────────────────────────────────────────────────
    component Button_: Rectangle {
        id: btn
        property string label: ""
        signal triggered()

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: txt.implicitWidth + 22
        height: 26
        radius: 8
        color: bm.containsMouse ? "#25ffffff" : "#15ffffff"
        border.width: 1
        border.color: "#1affffff"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Text {
            id: txt
            anchors.centerIn: parent
            text: btn.label
            color: Theme.textPrimary
            font.pixelSize: 11
        }

        MouseArea {
            id: bm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }

    // ── Key capture ──────────────────────────────────────────────
    //
    // Click it, press the combination you want, and it reports the Qt
    // key code with its modifiers, which is exactly what KDE wants to
    // be told. A bare modifier counts: the Meta key on its own is the
    // usual answer here, and KWin has a separate road for it.
    component KeyCapture_: Rectangle {
        id: cap
        property int value: 0
        property string label: ""
        property bool listening: false
        signal captured(int key, string label)

        readonly property var modifierNames: ({
            16777248: "Shift", 16777249: "Ctrl",
            16777250: "Meta",  16777251: "Alt"
        })

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: Math.max(96, capText.implicitWidth + 22)
        height: 26
        radius: 8
        color: cap.listening ? Theme.accentSoft
                             : (capMouse.containsMouse ? "#25ffffff" : "#15ffffff")
        border.width: 1
        border.color: cap.listening ? Theme.accent : "#1affffff"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Text {
            id: capText
            anchors.centerIn: parent
            text: cap.listening ? I18n.t.pressAKey : (cap.label || "—")
            color: cap.listening ? Theme.accent : Theme.textPrimary
            font.pixelSize: 11
        }

        MouseArea {
            id: capMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                cap.listening = true;
                cap.forceActiveFocus();
            }
        }

        focus: cap.listening
        Keys.onPressed: (event) => {
            if (!cap.listening) return;
            event.accepted = true;

            if (event.key === Qt.Key_Escape) { cap.listening = false; return; }

            // A modifier pressed alone is a valid answer, but only once
            // it arrives without any other modifier held down.
            const isModifier = cap.modifierNames[event.key] !== undefined;
            if (isModifier) {
                const others = event.modifiers & ~Qt.KeypadModifier;
                const own = { 16777248: Qt.ShiftModifier, 16777249: Qt.ControlModifier,
                              16777250: Qt.MetaModifier, 16777251: Qt.AltModifier }[event.key];
                if ((others & ~own) !== 0) return;   // still building a combination
                cap.listening = false;
                cap.captured(event.key, cap.modifierNames[event.key]);
                return;
            }

            const parts = [];
            if (event.modifiers & Qt.MetaModifier) parts.push("Meta");
            if (event.modifiers & Qt.ControlModifier) parts.push("Ctrl");
            if (event.modifiers & Qt.AltModifier) parts.push("Alt");
            if (event.modifiers & Qt.ShiftModifier) parts.push("Shift");
            parts.push(cap.nameOf(event.key, event.text));

            cap.listening = false;
            cap.captured(event.key | event.modifiers, parts.join("+"));
        }

        function nameOf(key, text) {
            if (key >= Qt.Key_F1 && key <= Qt.Key_F35)
                return "F" + (key - Qt.Key_F1 + 1);
            switch (key) {
                case Qt.Key_Space:  return "Space";
                case Qt.Key_Return:
                case Qt.Key_Enter:  return "Enter";
                case Qt.Key_Tab:    return "Tab";
                case Qt.Key_Backspace: return "Backspace";
                case Qt.Key_Delete: return "Delete";
                case Qt.Key_Home:   return "Home";
                case Qt.Key_End:    return "End";
                case Qt.Key_Up:     return "Up";
                case Qt.Key_Down:   return "Down";
                case Qt.Key_Left:   return "Left";
                case Qt.Key_Right:  return "Right";
            }
            if (key >= 0x20 && key <= 0x7e) return String.fromCharCode(key).toUpperCase();
            return text ? text.toUpperCase() : "?";
        }
    }

    // ── Section heading ──────────────────────────────────────────
    component Section_: Text {
        color: Theme.textTertiary
        font.pixelSize: 10
        font.bold: true
        font.letterSpacing: 1.2
        topPadding: 14
        bottomPadding: 2
    }
}
