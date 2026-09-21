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

            onTextChanged: if (text.length >= 3) debounce.restart()
            Keys.onReturnPressed: Weather.lookup(text)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === "" && !search.activeFocus
                text: Weather.place || "Buscar una localidad…"
                color: Weather.place ? Theme.textSecondary : Theme.textTertiary
                font.pixelSize: 12
            }
        }
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
            model: Weather.searchResults.slice(0, 5)

            Rectangle {
                required property var modelData
                width: parent.width
                height: 28
                radius: 6
                color: hm.containsMouse ? "#1fffffff" : "transparent"

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
                    onClicked: {
                        Weather.setPlace(modelData);
                        search.text = "";
                        search.focus = false;
                    }
                }
            }
        }
    }
}
