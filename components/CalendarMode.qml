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
                // Qt does not inherit the session language here and
                // would print the month in English, so the locale is
                // given explicitly — the one the interface is set to,
                // not a fixed one.
                text: root.shown.toLocaleDateString(Qt.locale(I18n.qtLocale), "MMMM yyyy")
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
                model: I18n.t.weekdays
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
            text: Focus.phaseLabel
            color: Focus.onBreak ? Theme.accent : Theme.textTertiary
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 0.8
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Focus.timeText
            color: Focus.running ? Theme.accent : Theme.textPrimary
            font.pixelSize: 26
            font.weight: Font.Light
            font.family: "monospace"
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            PomoButton {
                label: Focus.running ? I18n.t.pause : I18n.t.start
                primary: true
                onTriggered: Focus.toggle()
            }
            PomoButton {
                label: Focus.phase === "idle" ? I18n.t.reset : I18n.t.skip
                onTriggered: Focus.phase === "idle" ? Focus.reset() : Focus.skip()
            }
        }

        // How many rounds you have finished, as dots.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            visible: Focus.completed > 0

            Repeater {
                model: Math.min(Focus.completed, 8)
                Rectangle {
                    width: 4; height: 4; radius: 2
                    color: Theme.accent
                    opacity: 0.7
                }
            }
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
