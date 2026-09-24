import QtQuick
import "../services"

// Location search for the weather. Type a town, pick it from the list.
Column {
    id: root
    spacing: 6

    readonly property bool hasPlace: (Config.data.weatherLat ?? 0) !== 0

    // Without a location there is no weather, and nothing on screen
    // would explain why. The Plasma widget is only a shortcut for
    // filling this in: the data itself never comes from it.
    Rectangle {
        width: parent.width
        height: notice.implicitHeight + 16
        radius: 8
        color: "#18ffffff"
        border.width: 1
        border.color: "#1affffff"
        visible: !root.hasPlace

        Text {
            id: notice
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.t.pickPlace
            color: Theme.textSecondary
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }

    Rectangle {
        width: parent.width
        height: 30
        radius: 8
        color: "#14ffffff"
        border.width: 1
        border.color: search.activeFocus ? Theme.accent : "#1affffff"

        TextInput {
            id: search
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
            Accessible.name: I18n.t.searchPlace

            // Deleting back down to two letters used to leave the
            // timer running, and a moment later a search went out for
            // the text that had just been erased.
            onTextChanged: {
                root.pick = 0;
                if (text.length >= 3) debounce.restart();
                else { debounce.stop(); Weather.clearSearch(); }
            }

            // The arrows walk the towns found without leaving the box.
            // Return takes the marked one, and asks again only when
            // there is nothing to take — which is what it did before,
            // and is still what you want after typing a name the
            // search has not answered for yet.
            Keys.onDownPressed:
                root.pick = Math.min(root.shown.length - 1, root.pick + 1)
            Keys.onUpPressed: root.pick = Math.max(0, root.pick - 1)
            Keys.onReturnPressed: {
                if (root.shown.length) root.choose(root.shown[root.pick]);
                else Weather.lookup(text);
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === "" && !search.activeFocus
                text: Weather.place || I18n.t.searchPlace
                color: Weather.place ? Theme.textSecondary : Theme.textTertiary
                font.pixelSize: 12
            }
        }
    }

    // The towns on offer, and which of them return would take.
    readonly property var shown: Weather.searchResults.slice(0, 5)
    property int pick: 0

    function choose(place) {
        if (!place) return;
        Weather.setPlace(place);
        Weather.clearSearch();
        search.text = "";
        search.focus = false;
    }

    // Don't fire a request on every keystroke.
    Timer {
        id: debounce
        interval: 450
        onTriggered: Weather.lookup(search.text)
    }

    Column {
        width: parent.width
        spacing: 2
        visible: search.text.length >= 3 && Weather.searchResults.length > 0

        Repeater {
            model: root.shown

            Rectangle {
                required property var modelData
                required property int index
                readonly property bool marked:
                    index === root.pick && search.activeFocus

                width: parent.width
                height: 28
                radius: 6
                color: marked ? "#2affffff"
                     : (hm.containsMouse ? "#1fffffff" : "transparent")

                Accessible.role: Accessible.ListItem
                Accessible.name: modelData.name

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                        + (modelData.admin1 ? ", " + modelData.admin1 : "")
                        + " (" + modelData.country_code + ")"
                    color: Theme.textPrimary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    width: parent.width - 20
                }

                MouseArea {
                    id: hm
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.choose(parent.modelData)
                }
            }
        }
    }
}
