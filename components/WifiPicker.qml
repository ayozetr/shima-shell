import QtQuick
import Quickshell.Networking
import "../services"

// The Wi-Fi networks in range, unfolded from the control centre.
//
// A tap on one you have joined before, or an open one, joins it; a
// secured one you have not opens a line to type the password into, and
// a second tap on the one you are connected to leaves it. Turning the
// radio off altogether is a press-and-hold on the tile above, not
// anything here — a list of networks is no place to lose your
// connection by a misclick.
Column {
    id: root
    spacing: 3

    // The radio, among whatever network devices there are: only Wi-Fi
    // carries a list of networks, and a machine can have more than one.
    readonly property var device: {
        const devs = Networking.devices ? Networking.devices.values : [];
        for (const d of devs)
            if (d.type === DeviceType.Wifi) return d;
        return null;
    }

    // Scanning costs power and wakes the radio, so it runs only while
    // this list is on screen — which is exactly while the picker is
    // visible, and no longer.
    Binding {
        target: root.device
        property: "scannerEnabled"
        value: root.visible
        when: root.device !== null
    }

    // The network whose password line is open, or null: only one is
    // ever open at a time, so a second tap elsewhere closes it.
    property var asking: null
    onVisibleChanged: if (!visible) root.asking = null

    // Connected first, then the ones joined before, then the rest by
    // how strong they are. Capped at six: the island cannot grow
    // without end, and the networks past the sixth are the ones nobody
    // meant to join anyway.
    readonly property var shown: {
        const nets = (root.device && root.device.networks)
            ? root.device.networks.values.slice() : [];
        nets.sort((a, b) =>
            (b.connected ? 1 : 0) - (a.connected ? 1 : 0)
            || (b.known ? 1 : 0) - (a.known ? 1 : 0)
            || (b.signalStrength - a.signalStrength));
        return nets.slice(0, 6);
    }

    // A network wants a password when it is secured and you have never
    // joined it: a known one has its key already, and an open or
    // enhanced-open one has none to give.
    function needsPassword(net) {
        return net && !net.known
            && net.security !== WifiSecurityType.Open
            && net.security !== WifiSecurityType.Owe;
    }

    function activate(net) {
        if (!net || net.stateChanging) return;
        if (net.connected) { root.asking = null; net.disconnect(); return; }
        if (root.needsPassword(net)) {
            root.asking = (root.asking === net) ? null : net;
            return;
        }
        root.asking = null;
        net.connect();
    }

    Repeater {
        model: root.shown

        // A row, and under it the password line when this is the one
        // being asked. Kept in one column so the line pushes the rows
        // below it down rather than drawing over them.
        Column {
            id: entry
            required property var modelData
            readonly property var net: entry.modelData

            width: root.width
            spacing: 3

            Rectangle {
                width: parent.width
                height: 30
                radius: 8
                color: entry.net.connected ? Theme.accentSoft
                     : (rowArea.containsMouse ? "#18ffffff" : "transparent")
                Behavior on color { ColorAnimation { duration: 120 } }

                SignalBars {
                    id: bars
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    strength: entry.net.signalStrength
                    lit: entry.net.connected ? Theme.accent : Theme.textSecondary
                }

                Text {
                    anchors.left: bars.right
                    anchors.leftMargin: 10
                    anchors.right: status.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: entry.net.name !== "" ? entry.net.name : "·"
                    color: entry.net.connected ? Theme.textPrimary : Theme.textSecondary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                // Right edge: what the network is doing, or wants. A
                // spinner while it joins, "Connected" plainly when it
                // has, a padlock when it will ask for a password.
                Item {
                    id: status
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: childrenRect.width
                    height: 14

                    Text {
                        visible: entry.net.stateChanging
                        text: I18n.t.connecting
                        color: Theme.textTertiary
                        font.pixelSize: 10
                    }

                    ControlGlyph {
                        visible: !entry.net.stateChanging
                                 && root.needsPassword(entry.net)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 11; height: 11
                        kind: "lock"
                        fill: root.asking === entry.net ? Theme.accent : Theme.textTertiary
                    }

                    Rectangle {
                        visible: !entry.net.stateChanging && entry.net.connected
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
                    onClicked: root.activate(entry.net)
                }
            }

            // ── The password line, for a secured network ──────────
            Rectangle {
                width: parent.width
                height: visible ? 30 : 0
                visible: root.asking === entry.net
                radius: 8
                color: "#14ffffff"
                border.width: field.activeFocus ? 1 : 0
                border.color: Theme.accent
                clip: true

                // Taking the focus the moment the line opens saves a
                // second click: you tapped the network to type, so the
                // caret is already where your hands are going.
                onVisibleChanged: if (visible) field.forceActiveFocus()

                TextInput {
                    id: field
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: go.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textPrimary
                    font.pixelSize: 11
                    echoMode: TextInput.Password
                    clip: true
                    selectByMouse: true
                    selectionColor: Theme.accent

                    onAccepted: {
                        if (text === "") return;
                        entry.net.connectWithPsk(text);
                        text = "";
                        root.asking = null;
                    }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: field.text === "" && !field.activeFocus
                        text: I18n.t.wifiPassword
                        color: Theme.textTertiary
                        font: field.font
                    }
                }

                // The way in for a mouse, for the same reason the field
                // takes Enter: some keyboards are further away than
                // others.
                ControlGlyph {
                    id: go
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12; height: 12
                    kind: "back"
                    // "back" points left; turned around it is a go.
                    rotation: 180
                    fill: goArea.containsMouse ? Theme.accent : Theme.textSecondary
                    Behavior on fill { ColorAnimation { duration: Theme.hoverDuration } }

                    MouseArea {
                        id: goArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (field.text === "") { field.forceActiveFocus(); return; }
                            entry.net.connectWithPsk(field.text);
                            field.text = "";
                            root.asking = null;
                        }
                    }
                }
            }
        }
    }

    // Nothing to show: the radio is off, or it is on and has found
    // nobody yet.
    Text {
        visible: root.shown.length === 0
        text: (Networking.wifiEnabled ? I18n.t.noNetworks : I18n.t.wifiOff)
        color: Theme.textTertiary
        font.pixelSize: 11
    }

    // ── Four bars, filled to the strength ────────────────────────
    component SignalBars: Item {
        property int strength: 0
        property color lit: Theme.textSecondary
        implicitWidth: 16
        implicitHeight: 11

        Repeater {
            model: 4
            Rectangle {
                required property int index
                width: 2.6
                height: 3 + index * 2.4
                radius: 1
                x: index * 4.4
                y: parent.height - height
                color: Math.ceil(parent.strength / 25) > index
                    ? parent.lit : "#30ffffff"
            }
        }
    }
}
