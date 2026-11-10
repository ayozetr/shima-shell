import QtQuick
import Quickshell.Bluetooth
import "../services"

// The Bluetooth devices around you, unfolded from the control centre.
//
// A tap connects one you have paired before, pairs one you have not,
// and a second tap on a connected one lets it go. Turning the adapter
// off is a press-and-hold on the tile above, the same as Wi-Fi.
Column {
    id: root
    spacing: 3

    readonly property var adapter: Bluetooth.defaultAdapter

    // Looking for new devices spends the radio, so it only runs while
    // the list is up. The ones already paired are there without it.
    Binding {
        target: root.adapter
        property: "discovering"
        value: root.visible
        when: root.adapter !== null
    }

    // Connected first, then paired, then whatever discovery has turned
    // up, by name. Capped like the Wi-Fi list: a room full of other
    // people's earbuds is not a list to scroll.
    readonly property var shown: {
        const devs = Bluetooth.devices ? Bluetooth.devices.values.slice() : [];
        devs.sort((a, b) =>
            (b.connected ? 1 : 0) - (a.connected ? 1 : 0)
            || (b.paired ? 1 : 0) - (a.paired ? 1 : 0)
            || String(a.name || a.deviceName || "")
                 .localeCompare(String(b.name || b.deviceName || "")));
        return devs.slice(0, 6);
    }

    function label(dev) {
        return (dev.name && dev.name !== "") ? dev.name
             : (dev.deviceName && dev.deviceName !== "") ? dev.deviceName
             : dev.address;
    }

    function activate(dev) {
        if (!dev || dev.pairing) return;
        if (dev.connected) { dev.disconnect(); return; }
        if (dev.paired || dev.bonded) dev.connect();
        else dev.pair();
    }

    Repeater {
        model: root.shown

        Rectangle {
            id: row
            required property var modelData
            readonly property var dev: row.modelData

            width: root.width
            height: 30
            radius: 8
            color: row.dev.connected ? Theme.accentSoft
                 : (rowArea.containsMouse ? "#18ffffff" : "transparent")
            Behavior on color { ColorAnimation { duration: 120 } }

            ControlGlyph {
                id: mark
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 12; height: 12
                kind: "bt"
                fill: row.dev.connected ? Theme.accent
                    : (row.dev.paired ? Theme.textSecondary : Theme.textTertiary)
            }

            Text {
                anchors.left: mark.right
                anchors.leftMargin: 10
                anchors.right: status.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.label(row.dev)
                color: row.dev.connected ? Theme.textPrimary : Theme.textSecondary
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            // Battery when the device reports it, a spinner while it
            // pairs, and the dot when it is connected.
            Row {
                id: status
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    visible: row.dev.batteryAvailable && !row.dev.pairing
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(row.dev.battery * 100) + "%"
                    color: Theme.textTertiary
                    font.pixelSize: 10
                }

                Text {
                    visible: row.dev.pairing
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.t.connecting
                    color: Theme.textTertiary
                    font.pixelSize: 10
                }

                Rectangle {
                    visible: row.dev.connected && !row.dev.pairing
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: Theme.accent
                }
            }

            MouseArea {
                id: rowArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.activate(row.dev)
            }
        }
    }

    Text {
        visible: root.shown.length === 0
        text: ((root.adapter && root.adapter.enabled)
               ? I18n.t.noDevices : I18n.t.bluetoothOff)
        color: Theme.textTertiary
        font.pixelSize: 11
    }
}
