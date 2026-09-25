import QtQuick
import "../services"

// The settings window controls. They share one file because they are
// only used there and splitting them up would gain nothing.
Item {
    id: lib

    // ── Where the keyboard is ────────────────────────────────────
    //
    // Everything below can be reached with the tab key, and something
    // has to say which one is in hand. Drawn outside the control
    // rather than as a border on it: several of these already use
    // their border for something, and a ring that moves the thing it
    // marks is a ring that makes the window twitch as you tab.
    // ── Row with a label on the left and a control on the right ──
    component Row_: Item {
        id: row
        property string label: ""
        property string hint: ""
        default property alias content: holder.data

        // Measured from the whole column and not from the label
        // alone. The hint underneath wraps, and with two lines it sat
        // flush against the row below; with three it was drawn over
        // it. There are hints that already take two lines in English
        // and German.
        implicitHeight: Math.max(44, labels.implicitHeight + 16)
        width: parent ? parent.width : 0

        Column {
            id: labels
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

        // The label belongs to the control as much as to the row: a
        // reader that says "checkbox" and stops has said nothing. The
        // controls carry a `describedAs` for it and this fills it in,
        // so no page has to repeat the label it already wrote.
        Component.onCompleted: {
            for (const c of holder.children) {
                if (c.describedAs !== undefined) c.describedAs = row.label;
            }
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
        property string describedAs: ""
        signal moved(real value)

        // A step per press, ten with a page key. Held down, the key
        // repeats and so does this.
        function nudge(by) {
            const v = Math.max(sl.from, Math.min(sl.to, sl.value + by * sl.step));
            if (v !== sl.value) sl.moved(v);
        }

        activeFocusOnTab: true
        Keys.onLeftPressed: sl.nudge(-1)
        Keys.onRightPressed: sl.nudge(1)
        Keys.onDownPressed: sl.nudge(-1)
        Keys.onUpPressed: sl.nudge(1)
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Home) { sl.moved(sl.from); e.accepted = true; }
            else if (e.key === Qt.Key_End) { sl.moved(sl.to); e.accepted = true; }
            else if (e.key === Qt.Key_PageDown) { sl.nudge(-10); e.accepted = true; }
            else if (e.key === Qt.Key_PageUp) { sl.nudge(10); e.accepted = true; }
        }

        Accessible.role: Accessible.Slider
        Accessible.name: sl.describedAs
        // Qt's attached accessibility here carries no value, minimum
        // or maximum, so the reading goes where there is room for it.
        Accessible.description: (sl.step >= 1 ? Math.round(sl.value)
                                              : sl.value.toFixed(2)) + sl.suffix
        Accessible.onIncreaseAction: sl.nudge(1)
        Accessible.onDecreaseAction: sl.nudge(-1)

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: parent ? parent.width : 200
        height: 20

        // Around the track alone: the number beside it is not part of
        // what you are pointing at.
        FocusRing {
            around: sl
            anchors.fill: undefined
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 52 + 8
            height: 14
            radius: 7
        }

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
        property string describedAs: ""
        signal toggled(bool value)

        activeFocusOnTab: true
        Keys.onSpacePressed: tg.toggled(!tg.checked)
        Keys.onReturnPressed: tg.toggled(!tg.checked)
        Keys.onEnterPressed: tg.toggled(!tg.checked)

        Accessible.role: Accessible.CheckBox
        Accessible.name: tg.describedAs
        Accessible.checked: tg.checked
        Accessible.onToggleAction: tg.toggled(!tg.checked)
        Accessible.onPressAction: tg.toggled(!tg.checked)

        FocusRing { around: tg }

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
        property string describedAs: ""
        signal picked(string value)

        readonly property int index: {
            for (let i = 0; i < ch.options.length; i++)
                if (ch.options[i].value === ch.value) return i;
            return -1;
        }

        function step(by) {
            if (!ch.options.length) return;
            const at = ch.index < 0 ? 0
                : Math.max(0, Math.min(ch.options.length - 1, ch.index + by));
            ch.picked(ch.options[at].value);
        }

        activeFocusOnTab: true
        Keys.onLeftPressed: ch.step(-1)
        Keys.onRightPressed: ch.step(1)

        Accessible.role: Accessible.ComboBox
        Accessible.name: ch.describedAs
        Accessible.description: ch.index >= 0 ? ch.options[ch.index].label : ""

        FocusRing { around: ch }

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
    // An Item around the Row, and not a Row: a positioner lays out
    // everything you put in it, so the focus ring below became one
    // more thing in the line — and since it anchors to fill, Qt threw
    // the whole layout away and the colours vanished. What is laid out
    // and what is drawn over the top have to be kept apart.
    component Swatches_: Item {
        id: sw
        property var colors: []
        property string value: ""
        property string describedAs: ""
        signal picked(string value)

        function step(by) {
            if (!sw.colors.length) return;
            const i = sw.colors.indexOf(sw.value);
            const at = i < 0 ? 0
                : Math.max(0, Math.min(sw.colors.length - 1, i + by));
            sw.picked(sw.colors[at]);
        }

        activeFocusOnTab: true
        Keys.onLeftPressed: sw.step(-1)
        Keys.onRightPressed: sw.step(1)

        Accessible.role: Accessible.ComboBox
        Accessible.name: sw.describedAs
        Accessible.description: sw.value

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: row.width
        height: row.height

        FocusRing { around: sw; radius: 17 }

        Row {
            id: row
            // Four, not eight: each swatch carries its own margin, in
            // the box below.
            spacing: 4

            Repeater {
                model: sw.colors

                // The box is bigger than the circle on purpose. The
                // chosen one grows, and the growing goes past the
                // circle — at the end of the row that was past the
                // window as well, and the last colour came out with a
                // slice missing.
                Item {
                    id: slot
                    required property var modelData
                    width: 26; height: 26

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22; height: 22; radius: 11
                        color: slot.modelData
                        border.width: slot.modelData === sw.value ? 2 : 0
                        border.color: "#ffffff"
                        scale: slot.modelData === sw.value ? 1.1 : 1
                        Behavior on scale {
                            NumberAnimation { duration: 140; easing.type: Easing.OutBack }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sw.picked(slot.modelData)
                        }
                    }
                }
            }
        }
    }

    // ── Button ───────────────────────────────────────────────────
    component Button_: Rectangle {
        id: btn
        property string label: ""
        signal triggered()

        activeFocusOnTab: true
        Keys.onSpacePressed: btn.triggered()
        Keys.onReturnPressed: btn.triggered()
        Keys.onEnterPressed: btn.triggered()

        Accessible.role: Accessible.Button
        Accessible.name: btn.label
        Accessible.onPressAction: btn.triggered()

        FocusRing { around: btn }

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
        property string describedAs: ""
        // Which of ours this one sets, so it is not reported as being
        // in the way of itself: "launcher" or "clipboard".
        property string role: ""
        // Who held the key that was just taken, if anybody, and
        // whether that somebody was us — which is the case worth
        // colouring, because one of ours was left without a key.
        property string tookFrom: ""
        property bool tookFromOurs: false

        // It has been read by then, and a warning that stays for ever
        // stops being one: the red would still be there tomorrow,
        // about something settled a minute after it was said.
        onTookFromChanged: if (cap.tookFrom !== "") forget.restart(); else forget.stop()

        property Timer forget: Timer {
            interval: 7000
            onTriggered: {
                cap.tookFrom = "";
                cap.tookFromOurs = false;
            }
        }
        // A modifier held down, waiting to find out whether it is the
        // answer or only the start of one.
        property int pending: 0

        // While this is listening, the shell ignores its own global
        // shortcuts: otherwise pressing the combination you are trying
        // to set also does what it is already set to do.
        //
        // And for a moment afterwards, which is the part that is not
        // obvious. The key that ends the capture is the same key KDE
        // has registered, and KDE's turn comes after ours: the capture
        // was already finished and the flag already down by the time
        // the shortcut arrived — through D-Bus, through a process of
        // its own — so the launcher opened anyway. The flag stays up
        // long enough for that to land and be ignored.
        onListeningChanged: {
            if (cap.listening) {
                grace.stop();
                SettingsWindow.capturing = true;
            } else {
                grace.restart();
            }
        }

        property Timer grace: Timer {
            interval: 800
            onTriggered: SettingsWindow.capturing = false
        }
        // Closed with it still listening — the window shut, the page
        // changed — and nothing would ever put that back.
        Component.onDestruction: SettingsWindow.capturing = false
        signal captured(int key, string label)

        activeFocusOnTab: true
        // Space and return start it listening, the same as a click.
        // Not while it is listening, or the shortcut you meant to set
        // would be the key that started the setting of it.
        Keys.onSpacePressed: (e) => {
            if (!cap.listening) { cap.listening = true; e.accepted = true; }
        }
        Keys.onReturnPressed: (e) => {
            if (!cap.listening) { cap.listening = true; e.accepted = true; }
        }
        // Tabbing away with it still listening leaves a control that
        // eats every key in the window.
        onActiveFocusChanged: if (!cap.activeFocus) {
            cap.listening = false;
            cap.pending = 0;
        }

        Accessible.role: Accessible.Button
        Accessible.name: cap.describedAs
        Accessible.description: cap.listening ? I18n.t.pressAKey : (cap.label || "—")
        Accessible.onPressAction: cap.listening = true

        FocusRing { around: cap }

        readonly property var modifierNames: ({
            16777248: "Shift", 16777249: "Ctrl",
            16777250: "Meta",  16777251: "Alt"
        })

        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        width: Math.max(96, capText.implicitWidth + 22)
        height: 26
        radius: 8
        color: {
            if (cap.listening) return Theme.accentSoft;
            if (cap.tookFromOurs) return "#33f87171";
            return capMouse.containsMouse ? "#25ffffff" : "#15ffffff";
        }
        border.width: 1
        border.color: {
            if (cap.listening) return Theme.accent;
            if (cap.tookFromOurs) return "#f87171";
            return "#1affffff";
        }
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
                cap.tookFrom = "";
                cap.tookFromOurs = false;
                // Read afresh: somebody may have changed their
                // shortcuts since this window was opened.
                Shortcuts.refresh();
                cap.listening = true;
                cap.forceActiveFocus();
            }
            // A click anywhere else stops it listening, which used to
            // need the escape key.
        }

        Keys.onPressed: (event) => {
            if (!cap.listening) return;
            event.accepted = true;

            if (event.isAutoRepeat) return;
            if (event.key === Qt.Key_Escape) {
                cap.listening = false;
                cap.pending = 0;
                return;
            }

            // A modifier on its own is a valid answer — the Meta key
            // alone is the usual one here — but it cannot be taken the
            // moment it goes down, because that is also how every
            // combination starts. Taken there, Meta+V was impossible
            // to type: the Meta was accepted and the V never got a
            // turn. So it waits to see what follows, and is answered
            // for when it is let go.
            if (cap.modifierNames[event.key] !== undefined) {
                cap.pending = event.key;
                return;
            }

            cap.pending = 0;
            const parts = [];
            if (event.modifiers & Qt.MetaModifier) parts.push("Meta");
            if (event.modifiers & Qt.ControlModifier) parts.push("Ctrl");
            if (event.modifiers & Qt.AltModifier) parts.push("Alt");
            if (event.modifiers & Qt.ShiftModifier) parts.push("Shift");
            parts.push(cap.nameOf(event.key, event.text));

            cap.listening = false;
            const label = parts.join("+");
            cap.captured(event.key | event.modifiers, label);
            const took = Shortcuts.claim(cap.role, label);
            cap.tookFrom = took.who;
            cap.tookFromOurs = took.ours;
        }

        // Let go without anything after it: the modifier was the whole
        // answer.
        Keys.onReleased: (event) => {
            if (!cap.listening || event.isAutoRepeat) return;
            if (event.key !== cap.pending) return;
            event.accepted = true;
            const key = cap.pending;
            cap.pending = 0;
            cap.listening = false;
            cap.captured(key, cap.modifierNames[key]);
            const took = Shortcuts.claim(cap.role, cap.modifierNames[key]);
            cap.tookFrom = took.who;
            cap.tookFromOurs = took.ours;
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

    // ── A list too long to be a row of buttons ───────────────────
    //
    // Choice_ gives every option an equal share of the row, which is
    // right for two or three short words and wrong for nine languages:
    // at the width a settings row has, each one had some thirty pixels
    // and "Português (Brasil)" was drawn across its neighbours.
    //
    // The list opens downwards and the row grows with it. Floating it
    // over what is below was the first try and it looked right, but a
    // click only finds what is inside the box it was aimed at: the
    // part of the list that hung past the row took the mouse from
    // nobody, and half the languages could not be chosen. It is worth
    // writing down, because it is invisible until somebody tries the
    // ninth item: **what is drawn outside a parent is drawn, not
    // clickable.**
    // ── A row whose control is a list ────────────────────────────
    //
    // Row_ gives its control a box the height of the row, which is
    // right for a switch and wrong for something that opens. This is
    // the same row with the height worked out from the list as well,
    // so what is below moves along instead of being covered by
    // something it cannot be clicked through.
    component SelectRow_: Item {
        id: srow
        property string label: ""
        property string hint: ""
        property var options: []
        property string value: ""
        signal picked(string value)

        width: parent ? parent.width : 0
        // Every term here is measured from the thing itself and never
        // from this row, which is what keeps it from being a loop.
        implicitHeight: Math.max(44, labels.implicitHeight + 16, sel.height + 14)
        height: implicitHeight

        Column {
            id: labels
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 12
            width: parent.width * 0.44
            spacing: 2
            Text {
                text: srow.label
                color: Theme.textPrimary
                font.pixelSize: 13
            }
            Text {
                text: srow.hint
                visible: srow.hint !== ""
                color: Theme.textTertiary
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                width: parent.width
            }
        }

        Select {
            id: sel
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 7
            width: parent.width * 0.52
            options: srow.options
            value: srow.value
            describedAs: srow.label
            onPicked: (v) => srow.picked(v)
        }
    }

    // ── Somewhere to type something ──────────────────────────────
    //
    // For the values a list cannot cover: the id of an application
    // nobody thought to put on ours. Written down as you type, since
    // a settings window with a save button would be the only one here.
    component Field_: Rectangle {
        id: field
        property string value: ""
        property string placeholder: ""
        property string describedAs: ""
        signal edited(string value)

        width: parent ? parent.width : 200
        height: 30
        radius: 9
        color: "#1a1a1a"
        border.width: 1
        border.color: input.activeFocus ? Theme.accent : "#2a2a2a"

        // The text is set from outside only while you are not in it:
        // writing into a box under somebody's hands moves the cursor
        // to the end on every keystroke.
        onValueChanged: if (!input.activeFocus) input.text = field.value

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 11
            anchors.rightMargin: 11
            verticalAlignment: TextInput.AlignVCenter
            color: Theme.textPrimary
            font.pixelSize: 11
            clip: true
            selectByMouse: true
            activeFocusOnTab: true
            text: field.value

            Accessible.role: Accessible.EditableText
            Accessible.name: field.describedAs
            Accessible.description: input.text

            onTextChanged: if (activeFocus) field.edited(text)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: field.placeholder
                color: Theme.textTertiary
                font.pixelSize: 11
            }
        }
    }

    // ── A line that says something went sideways ─────────────────
    component Notice_: Text {
        // Red for something lost, quiet grey for something merely
        // worth knowing.
        property bool grave: true
        width: parent ? parent.width : 0
        visible: text !== ""
        color: grave ? "#f87171" : Theme.textTertiary
        font.pixelSize: 11
        wrapMode: Text.WordWrap
        topPadding: 2
        bottomPadding: 6
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
