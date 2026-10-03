import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import "../services"

// How the machine is doing: CPU, memory, network, and battery if any.
Item {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery && battery.isLaptopBattery

    // Quickshell documents percentage as energy over capacity, so a
    // ratio and not a number out of a hundred. Working out which one
    // it was by looking at the value got it right everywhere except
    // the one place where being right matters: at exactly 1 there is
    // no telling 1 % from 100 %, and it read the last of the battery
    // as a full one. The two numbers it is made of say it outright, so
    // they are used when the device reports them.
    readonly property int batteryPercent: {
        if (!root.hasBattery) return 0;
        const d = root.battery;
        if (d.energyCapacity > 0)
            return Math.round(d.energy / d.energyCapacity * 100);
        return Math.round(d.percentage * 100);
    }

    readonly property int batteryState: root.hasBattery
        ? root.battery.state : UPowerDeviceState.Unknown
    readonly property bool charging: root.batteryState === UPowerDeviceState.Charging
                                     || root.batteryState === UPowerDeviceState.PendingCharge

    // Seconds, and zero when UPower has not got an estimate yet: a
    // machine that just woke, or a rate that has not settled. Nothing
    // is invented in that case — the column says what the battery is
    // doing instead of inventing a time that would then jump about.
    readonly property real secondsLeft: {
        if (!root.hasBattery) return 0;
        return root.charging ? root.battery.timeToFull : root.battery.timeToEmpty;
    }

    // The label carries the meaning and the figure stays a figure,
    // which is how the two rows above already read: a heading in small
    // caps and a number under it.
    readonly property string etaLabel: root.secondsLeft > 0
        ? (root.charging ? I18n.t.batteryToFull : I18n.t.batteryRemaining)
        : I18n.t.batteryStatus
    readonly property string etaText: {
        if (root.secondsLeft > 0) return root.formatSpan(root.secondsLeft);
        switch (root.batteryState) {
        // "Charged" beside a number that is not 100 reads as a
        // contradiction, and the machine is not lying: a laptop that
        // is plugged in at 99 % will not start a charge cycle for one
        // point, so it reports itself fully charged and sits there.
        // What is true in that moment is that it is plugged in.
        case UPowerDeviceState.FullyCharged:
            return root.batteryPercent >= 100 ? I18n.t.batteryFull : I18n.t.batteryPlugged;
        case UPowerDeviceState.Charging:
        case UPowerDeviceState.PendingCharge:    return I18n.t.batteryCharging;
        case UPowerDeviceState.Discharging:
        case UPowerDeviceState.PendingDischarge: return I18n.t.batteryOnBattery;
        default:                                 return I18n.t.batteryPlugged;
        }
    }

    function formatSpan(secs) {
        const total = Math.round(secs / 60);
        const h = Math.floor(total / 60);
        const m = total % 60;
        if (h <= 0) return I18n.t.durationM.replace("%1", m);
        // "1 h 0 min" is how a clock reads, not how a person says it.
        if (m === 0) return I18n.t.durationH.replace("%1", h);
        return I18n.t.durationHm.replace("%1", h).replace("%2", m);
    }

    // What this mode is worth in pixels, so the island can make room
    // for it. Island.qml keeps a written height per mode and lets a
    // mode ask for more; this one never asked, so the battery row —
    // which only exists on a laptop, and so was never seen on the
    // machine this was written on — fell off the bottom edge.
    //
    // The floor is the height that was written down, so a machine with
    // no battery is pixel for pixel what it was.
    readonly property int preferredHeight: Math.max(100, col.implicitHeight)

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Meter {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: I18n.t.cpu
                value: SysInfo.cpu
                text: Math.round(SysInfo.cpu * 100) + "%"
                       + (SysInfo.cpuTemp > 0 ? "  ·  " + SysInfo.cpuTemp + "°" : "")
            }
            Meter {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: I18n.t.memory
                value: SysInfo.memRatio
                text: SysInfo.memUsed.toFixed(1) + " / " + SysInfo.memTotal.toFixed(0) + " GiB"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Stat {
                Layout.fillWidth: true
                // A common base width: fillWidth only shares out the
                // leftover space, so columns whose text differs in
                // length end up misaligned with the row above.
                Layout.preferredWidth: 1
                label: I18n.t.download
                text: SysInfo.rate(SysInfo.rxRate)
            }
            Stat {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: I18n.t.upload
                text: SysInfo.rate(SysInfo.txRate)
            }
        }

        // Kept at two columns per row so everything lines up with the
        // meters above: three columns here and two up there never meet.
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            visible: root.hasBattery

            BatteryStat {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: I18n.t.battery
                percent: root.batteryPercent
                charging: root.charging
            }
            Stat {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: root.etaLabel
                text: root.etaText
            }
        }
    }

    // ── Labelled bar ─────────────────────────────────────────────
    component Meter: Item {
        id: meter
        property string label: ""
        property real value: 0
        property string text: ""
        implicitHeight: 34

        Text {
            text: meter.label
            color: Theme.textTertiary
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 0.8
        }
        Text {
            anchors.right: parent.right
            text: meter.text
            color: Theme.textSecondary
            font.pixelSize: 10
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 5
            radius: 2.5
            color: Theme.trackBg

            Rectangle {
                width: Math.max(0, Math.min(1, meter.value)) * parent.width
                height: parent.height
                radius: parent.radius
                color: Theme.accent
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }

    // ── Battery: a figure with a glyph that follows the charge ───
    //
    // Drawn here rather than asked of the icon theme. The seven
    // sidebar icons taught us that lesson: the same name comes out as
    // a dark line glyph on one theme and in full colour on another,
    // and this one has to sit beside our own text at our own size.
    component BatteryStat: Column {
        id: bat
        property string label: ""
        property int percent: 0
        property bool charging: false
        spacing: 2

        Text {
            text: bat.label
            color: Theme.textTertiary
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 0.8
        }

        Row {
            spacing: 7

            Item {
                width: 25
                height: 18
                anchors.verticalCenter: undefined

                Rectangle {
                    id: body
                    width: 22
                    height: 11
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 3
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.textTertiary

                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 2 }
                        width: Math.max(0, Math.min(1, bat.percent / 100)) * (parent.width - 4)
                        radius: 1.5
                        color: Theme.accent
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    }
                }

                // The cap, so it reads as a battery and not as a
                // progress bar with a border.
                Rectangle {
                    anchors { left: body.right; leftMargin: 1; verticalCenter: body.verticalCenter }
                    width: 2
                    height: 5
                    radius: 1
                    color: Theme.textTertiary
                }

                // Over the fill when charging. Light enough to read
                // against the accent underneath it and against the
                // empty track on either side of it.
                Canvas {
                    anchors.centerIn: body
                    width: 8
                    height: 11
                    visible: bat.charging
                    onPaint: {
                        const c = getContext("2d");
                        c.reset();
                        c.fillStyle = Theme.textPrimary;
                        c.beginPath();
                        c.moveTo(width * 0.62, 0);
                        c.lineTo(width * 0.1,  height * 0.58);
                        c.lineTo(width * 0.45, height * 0.58);
                        c.lineTo(width * 0.38, height);
                        c.lineTo(width * 0.9,  height * 0.42);
                        c.lineTo(width * 0.55, height * 0.42);
                        c.closePath();
                        c.fill();
                    }
                    Connections {
                        target: Theme
                        function onTextPrimaryChanged() { parent.requestPaint(); }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bat.percent + "%"
                color: Theme.textPrimary
                font.pixelSize: 14
                font.weight: Font.Medium
            }
        }
    }

    // ── Standalone figure ────────────────────────────────────────
    component Stat: Column {
        id: stat
        property string label: ""
        property string text: ""
        spacing: 2

        Text {
            text: stat.label
            color: Theme.textTertiary
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 0.8
        }
        Text {
            text: stat.text
            color: Theme.textPrimary
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }
}
