import QtQuick
import "../services"

// The plumbing behind the dock's two panels: the menu for an
// application and the list of its windows.
//
// They are the same object with different contents — a panel over the
// dock that belongs to one icon, opened by a click on it, closed by
// clicking it again, and which puts the other one away when it opens.
// It was written out twice, which meant every fix to the way they
// behave had to be made in both places, and the second one was where
// it got forgotten.
QtObject {
    id: root

    // Whose panel this is, and where its icon sits in the window.
    property string appId: ""
    property string appName: ""
    property real at: 0

    // Asked for. Whether anything is actually shown is `open`.
    property bool shown: false

    // The other one, put away when this opens.
    property var other: null

    // Whether there is anything to show yet. Asking for the windows of
    // an application is not the same as having them: the answer comes
    // after the click, and without kdotool — or when the query comes
    // back empty — it never comes. What opened then was a heading with
    // nothing under it, over a window that went on swallowing clicks
    // meant for the desktop.
    property bool ready: true
    readonly property bool open: root.shown && root.ready

    // For whoever has to go and fetch the contents.
    signal opened(string id)

    function show(id, name, where) {
        // Clicking the same icon again puts it away, rather than
        // opening the same panel on top of itself.
        if (root.shown && root.appId === id) { root.hide(); return; }
        cleanup.stop();
        root.shown = true;
        // Opening one closes the launcher: leaving both up at once is
        // confusing and has to be dismissed twice.
        LauncherState.hide();
        if (root.other) root.other.hide();
        root.appId = id;
        root.appName = name;
        root.at = where;
        root.opened(id);
    }

    // The contents outlive the fade: clearing the id right away empties
    // the panel and changes its height mid-animation, which reads as
    // the fade being cut short.
    function hide() {
        root.shown = false;
        cleanup.restart();
    }

    property Timer cleanup: Timer {
        interval: 200
        onTriggered: root.appId = ""
    }
}
