import QtQuick
import "../services"

// A box you type into, with the answers walked by the arrows.
//
// Written twice in the same week, to the pixel: the pinned editor and
// the weather's town picker. Same box, same border that lights on
// focus, same pause before searching, same arrows moving a mark
// without leaving the box, same return taking what is marked.
//
// Not the launcher's, which looks like a cousin and is not one. That
// one searches as you type rather than after a pause, folds submenus
// on escape, switches category, and walks a grid of sections where
// what is marked is held by what it is and not by where it sits.
// Folding it in would mean parameterising all of that away and would
// leave both worse than they are apart.
Rectangle {
    id: root

    // What to show when it is empty, and whether to show it quietly:
    // the town picker puts the place you already have here, which is
    // a value and not a prompt.
    property string placeholder: ""
    property bool placeholderMuted: false
    property string describedAs: ""

    // How much has to be typed before it is worth asking, and how long
    // to wait after the last key. Below the length, asking is called
    // off rather than merely postponed — deleting back down to two
    // letters used to leave the timer running, and a moment later a
    // search went out for the text that had just been erased.
    property int minLength: 1
    property int settleMs: 450

    // How many answers there are, and which of them return would take.
    // Held here so the arrows can stay inside the box.
    property int count: 0
    property int pick: 0

    property alias text: input.text
    property alias input: input

    signal settled(string text)
    signal cleared()
    signal taken()

    width: parent ? parent.width : 200
    height: 30
    radius: 8
    color: "#14ffffff"
    border.width: 1
    border.color: input.activeFocus ? Theme.accent : "#1affffff"

    function clear() {
        settle.stop();
        input.text = "";
        root.pick = 0;
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.textPrimary
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        activeFocusOnTab: true

        Accessible.role: Accessible.EditableText
        Accessible.name: root.describedAs

        onTextChanged: {
            root.pick = 0;
            if (text.length >= root.minLength) settle.restart();
            else { settle.stop(); root.cleared(); }
        }

        // Claimed before the window's Escape shortcut can have it. Qt
        // hands shortcuts out ahead of key events, so without this the
        // whole settings window closed and the handler below never
        // ran. This works where the same idea failed for the dropdown,
        // and the difference is the focus: a box being typed into has
        // it, a list opened with the mouse did not.
        Keys.onShortcutOverride: (e) => {
            if (e.key === Qt.Key_Escape) e.accepted = true;
        }

        // Escape backs out of the box rather than out of the window:
        // it empties what was typed, drops the answers with it, and
        // hands the focus back -- which is what brings the placeholder
        // into view again, and in the weather picker the placeholder
        // is the place you already had set. A second press, with the
        // box no longer holding the focus, belongs to the window.
        Keys.onEscapePressed: (e) => {
            root.clear();
            // Onto the box itself rather than nowhere. Dropping the
            // focus altogether hands it to whatever comes first in the
            // window, which is at the top of the page -- and the page
            // scrolls to follow the focus, so escaping out of a search
            // box threw you to the top of the settings. Held here, the
            // placeholder comes back (it only hides for the text
            // cursor), nothing moves, and a second escape belongs to
            // the window, which is what it should do by then.
            root.forceActiveFocus();
            e.accepted = true;
        }

        Keys.onDownPressed: root.pick = Math.min(root.count - 1, root.pick + 1)
        Keys.onUpPressed: root.pick = Math.max(0, root.pick - 1)
        Keys.onReturnPressed: root.taken()
        Keys.onEnterPressed: root.taken()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === "" && !input.activeFocus
            text: root.placeholder
            color: root.placeholderMuted ? Theme.textSecondary : Theme.textTertiary
            font.pixelSize: 12
        }
    }

    Timer {
        id: settle
        interval: root.settleMs
        onTriggered: root.settled(input.text)
    }
}
