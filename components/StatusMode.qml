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

    ColumnLayout {
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

            Stat {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: I18n.t.battery
                // Depending on the version, percentage comes as 0-1 or
                // as 0-100.
                text: root.hasBattery
                    ? Math.round(root.battery.percentage <= 1
                        ? root.battery.percentage * 100
                        : root.battery.percentage) + "%"
                    : ""
            }
            Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }
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
