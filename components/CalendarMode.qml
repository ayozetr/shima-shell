import QtQuick
import Quickshell
import "../services"

// The month at a glance, with a pomodoro beside it so you don't have
// to switch windows every time you want to time something.
Item {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date today: clock.date
    property int monthOffset: 0

    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + monthOffset, 1)
    readonly property int daysInMonth: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()
    // The week starts on Monday, not Sunday.
    readonly property int firstWeekday: (new Date(shown.getFullYear(), shown.getMonth(), 1).getDay() + 6) % 7

    // Anchors instead of a RowLayout: the calendar is exactly seven
    // columns wide and the pomodoro sits on the right, no negotiation.
    readonly property int cellW: 24
    readonly property int calW: cellW * 7

    Column {
        id: cal
        anchors.left: parent.left
        anchors.top: parent.top
        width: root.calW
        spacing: 4

        Item {
            width: parent.width
            height: 18

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                // Qt doesn't inherit the system language here and
                // prints month names in English, so we pin the locale.
                text: root.shown.toLocaleDateString(Qt.locale("es_ES"), "MMMM yyyy")
                color: Theme.textPrimary
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.capitalization: Font.Capitalize
                elide: Text.ElideRight
                width: parent.width - 36
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Arrow { dir: -1; onTriggered: root.monthOffset-- }
                Arrow { dir:  1; onTriggered: root.monthOffset++ }
            }
        }

        Grid {
            columns: 7
            spacing: 0

            Repeater {
                model: ["L", "M", "X", "J", "V", "S", "D"]
                Text {
                    width: root.cellW; height: 13
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Theme.textTertiary
                    font.pixelSize: 9
                    font.bold: true
                }
            }

            Repeater {
                model: root.firstWeekday + root.daysInMonth
                Item {
                    width: root.cellW; height: 17
                    readonly property int day: index - root.firstWeekday + 1
                    readonly property bool valid: day > 0
                    readonly property bool isToday: valid
                        && root.monthOffset === 0
                        && day === root.today.getDate()

                    Rectangle {
                        anchors.centerIn: parent
                        width: 17; height: 17; radius: 8.5
                        color: Theme.accent
                        visible: parent.isToday
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: parent.valid
                        text: parent.day
                        color: parent.isToday ? Theme.accentText : Theme.textSecondary
                        font.pixelSize: 10
                    }
                }
            }
        }
    }

    // ── Pomodoro ─────────────────────────────────────────────────
    Column {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ENFOQUE"
            color: Theme.textTertiary
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 0.8
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const m = Math.floor(pomo.remaining / 60);
                const sec = pomo.remaining % 60;
                return m + ":" + (sec < 10 ? "0" : "") + sec;
            }
            color: pomo.running ? Theme.accent : Theme.textPrimary
            font.pixelSize: 26
            font.weight: Font.Light
            font.family: "monospace"
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            PomoButton {
                label: pomo.running ? "Pausar" : "Iniciar"
                primary: true
                onTriggered: pomo.running = !pomo.running
            }
            PomoButton {
                label: "Reiniciar"
                onTriggered: { pomo.running = false; pomo.remaining = pomo.duration; }
            }
        }
    }

    Timer {
        id: pomo
        property int duration: 25 * 60
        property int remaining: 25 * 60
        interval: 1000
        repeat: true
        onTriggered: {
            if (remaining > 0) remaining--;
            else running = false;
        }
    }

    // ── Month arrow ──────────────────────────────────────────────
    component Arrow: Item {
        id: arrow
        property int dir: 1
        signal triggered()
        width: 16; height: 16

        Glyph {
            anchors.centerIn: parent
            width: 9; height: 9
            kind: arrow.dir < 0 ? "prev" : "next"
            fill: am.containsMouse ? Theme.textPrimary : Theme.textTertiary
        }
        MouseArea {
            id: am
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.triggered()
        }
    }

    // ── Pomodoro button ──────────────────────────────────────────
    component PomoButton: Rectangle {
        id: btn
        property string label: ""
        property bool primary: false
        signal triggered()

        width: txt.implicitWidth + 14
        height: 22
        radius: 7
        color: btn.primary
            ? (bm.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent)
            : (bm.containsMouse ? "#25ffffff" : "#15ffffff")

        Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }

        Text {
            id: txt
            anchors.centerIn: parent
            text: btn.label
            color: btn.primary ? Theme.accentText : Theme.textSecondary
            font.pixelSize: 10
        }

        MouseArea {
            id: bm
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }
}
