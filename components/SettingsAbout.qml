import QtQuick
import Quickshell
import Quickshell.Widgets
import "../services"

// Settings: what this is, where it comes from and how to say thanks.
Column {
    id: root
    width: parent ? parent.width : 0
    spacing: 2

    // Two rows that are the same shape: a mark, a name, a line of
    // explanation, and an address that opens outside. Written once
    // here because writing it twice is how the second one goes stale.
    component Link_: Rectangle {
        id: link
        property string mark: ""
        property string label: ""
        property string hint: ""
        property string url: ""

        function open() { Quickshell.execDetached(["xdg-open", link.url]); }

        activeFocusOnTab: true
        Keys.onSpacePressed: link.open()
        Keys.onReturnPressed: link.open()
        Keys.onEnterPressed: link.open()

        Accessible.role: Accessible.Link
        Accessible.name: link.label
        Accessible.description: link.hint
        Accessible.onPressAction: link.open()

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 16
            color: "transparent"
            border.width: 2
            border.color: Theme.accent
            visible: link.activeFocus
        }

        width: parent ? parent.width : 0
        height: 62
        radius: 12
        color: mouse.containsMouse ? "#14ffffff" : "#0affffff"
        border.width: 1
        border.color: "#14ffffff"
        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Image {
            id: glyph
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            source: "file://" + Paths.programDir + "/assets/vendor/"
                    + link.mark + ".svg"
            sourceSize.width: 26
            sourceSize.height: 26
            width: 26
            height: 26
            // The marks are white; on hover the whole row lifts
            // instead, so nothing has to be recoloured.
            opacity: mouse.containsMouse ? 1 : 0.85
            Behavior on opacity { NumberAnimation { duration: Theme.hoverDuration } }
        }

        Column {
            anchors.left: glyph.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: link.label
                color: Theme.textPrimary
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Text {
                text: link.hint
                color: Theme.textTertiary
                font.pixelSize: 11
                width: parent.width
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // Through xdg-open rather than Qt.openUrlExternally: the
            // rest of the shell opens things that way, and it is the
            // one that honours what KDE has set as the browser.
            onClicked: link.open()
        }
    }

    Item { width: 1; height: 6 }

    // The mark and the name beside it, rather than the logotype that
    // has both drawn into one file. That one carries its second line
    // at a thirteenth of its height: at any size this row can afford,
    // "KDE Plasma shell" comes out around five pixels tall and is not
    // read so much as guessed. Set as text it is sharp at any scale
    // and wears the same typeface as everything else here.
    Row {
        spacing: 14

        Image {
            source: "file://" + Paths.programDir + "/assets/logo-white.svg"
            sourceSize.width: 96
            sourceSize.height: 96
            width: 48
            height: 48
            smooth: true
            anchors.verticalCenter: parent.verticalCenter
        }

        // Name and number on one line, sitting on the same baseline.
        // Anchored rather than left to the row, which lines its items
        // up by the top: the version is smaller, so that left it
        // floating above the name instead of beside it.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Text {
                id: nameText
                text: I18n.t.settingsTitle
                color: Theme.textPrimary
                font.pixelSize: 21
                font.weight: Font.DemiBold
            }
            Text {
                anchors.baseline: nameText.baseline
                text: Paths.version !== ""
                    ? I18n.t.aboutVersion + " " + Paths.version
                    : I18n.t.aboutVersionUnknown
                color: Theme.textSecondary
                font.pixelSize: 11
            }
        }
    }

    Item { width: 1; height: 10 }

    Text {
        text: I18n.t.aboutLine
        color: Theme.textTertiary
        font.pixelSize: 11
        width: parent.width
        wrapMode: Text.WordWrap
        bottomPadding: 10
    }

    // Asked for, never on its own. Pressing it is the only thing that
    // makes Shima talk to the network about itself.
    Row {
        spacing: 10

        Rectangle {
            id: checkBtn
            width: checkLabel.implicitWidth + 26
            height: 28
            radius: 8
            color: checkMouse.containsMouse ? "#1fffffff" : "#12ffffff"
            border.width: 1
            border.color: "#1affffff"
            opacity: Updates.busy ? 0.6 : 1
            Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

            activeFocusOnTab: true
            Keys.onSpacePressed: Updates.check()
            Keys.onReturnPressed: Updates.check()
            Keys.onEnterPressed: Updates.check()
            Accessible.role: Accessible.Button
            Accessible.name: checkLabel.text
            Accessible.onPressAction: Updates.check()

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: 12
                color: "transparent"
                border.width: 2
                border.color: Theme.accent
                visible: checkBtn.activeFocus
            }

            Text {
                id: checkLabel
                anchors.centerIn: parent
                text: Updates.busy ? I18n.t.updateChecking : I18n.t.updateCheck
                color: Theme.textPrimary
                font.pixelSize: 11
            }

            MouseArea {
                id: checkMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !Updates.busy
                onClicked: Updates.check()
            }
        }

        // The answer, and where there is somewhere to go, a way to go
        // there. Nothing downloads itself: what Shima knows is the
        // number, and how it was installed is not its business.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: root.width - checkBtn.width - 10
            elide: Text.ElideRight
            color: Updates.state === "newer" ? Theme.accent : Theme.textTertiary
            font.pixelSize: 11
            visible: text !== ""
            text: {
                switch (Updates.state) {
                case "current": return I18n.t.updateCurrent;
                case "newer":   return I18n.t.updateNewer.replace("%1", Updates.latest);
                case "offline": return I18n.t.updateOffline;
                case "failed":  return I18n.t.updateFailed;
                default:        return "";
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: Updates.state === "newer"
                cursorShape: Qt.PointingHandCursor
                onClicked: Updates.open()
            }
        }
    }

    Item { width: 1; height: 12 }

    Link_ {
        mark: "github"
        label: I18n.t.aboutSource
        hint: "github.com/ayozetr/shima-shell"
        url: "https://github.com/ayozetr/shima-shell"
    }

    Item { width: 1; height: 8 }

    Link_ {
        mark: "kofi"
        label: I18n.t.aboutSupport
        hint: "ko-fi.com/ayozetr"
        url: "https://ko-fi.com/ayozetr"
    }

    Item { width: 1; height: 18 }

    Text {
        text: I18n.t.settingsPath + Config.path
        color: Theme.textTertiary
        font.pixelSize: 10
        width: parent.width
        elide: Text.ElideMiddle
    }
}
