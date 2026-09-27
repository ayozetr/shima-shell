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

    SearchField {
        id: search
        describedAs: I18n.t.searchPlace
        // The place you already have belongs here rather than a
        // prompt: it is an answer, so it is shown as one.
        placeholder: Weather.place || I18n.t.searchPlace
        placeholderMuted: Weather.place !== ""
        // Three letters, because a town search on one or two answers
        // with the world.
        minLength: 3
        count: root.shown.length
        // The mark lives in the field, because the arrows that move it
        // are in the field. This only mirrors it out for the rows to
        // draw and for return to act on -- binding it both ways would
        // be a loop whose first half dies the moment an arrow is
        // pressed, which is a worse kind of working.
        onPickChanged: root.pick = pick

        onSettled: (text) => Weather.lookup(text)
        onCleared: Weather.clearSearch()
        // Return takes the marked one, and asks again only when there
        // is nothing to take — which is what you want after typing a
        // name the search has not answered for yet.
        onTaken: {
            if (root.shown.length) root.choose(root.shown[root.pick]);
            else Weather.lookup(search.text);
        }
    }

    // The towns on offer, and which of them return would take.
    readonly property var shown: Weather.searchResults.slice(0, 5)
    property int pick: 0

    function choose(place) {
        if (!place) return;
        Weather.setPlace(place);
        Weather.clearSearch();
        search.clear();
        search.input.focus = false;
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
                    index === root.pick && search.input.activeFocus

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
