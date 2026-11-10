import QtQuick
import "../services"

// What an opened earbud case holds out on the island: the name of the
// device and the battery of the left bud, the case and the right bud,
// for a few seconds. A tap sends it away early.
//
// By default each reading is a word and a bar. Drop photos of your own
// earbuds next to the config and they take the words' place: a folder
// named after the device, under <config>/fastpair/, with left.png,
// right.png and case.png for a picture each, or a single all.png for
// one picture of the set with the three bars in a row beneath it.
// Anything missing falls back to the word, so a half-filled folder is
// no worse than an empty one. See docs/fastpair-images.md.
Item {
    id: root

    property var entry: null   // { name, left, right, caseLevel }
    signal dismissed()

    // The folder a user may have filled, as a file URL with its spaces
    // escaped so a device with a space in its name still resolves.
    readonly property string imgBase: root.entry
        ? "file://" + encodeURI(Paths.configDir + "/fastpair/"
                                + String(root.entry.name) + "/")
        : ""

    // Empty when there is no device, so a cell is never handed a bare
    // "left.png" to resolve against its own folder and warn about.
    function imgOf(file) {
        return root.imgBase !== "" ? (root.imgBase + file) : "";
    }

    // A single combined photo, if there is one. Probed off-screen; its
    // being ready is what turns the whole peek over to one picture.
    Image {
        id: allProbe
        source: root.imgBase !== "" ? (root.imgBase + "all.png") : ""
        asynchronous: true
        cache: false
        visible: false
    }
    readonly property bool single: allProbe.status === Image.Ready

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            width: parent.width
            text: root.entry ? root.entry.name : ""
            color: Theme.textPrimary
            font.pixelSize: 12
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        // ── Default and per-piece: a column each ─────────────────
        Row {
            visible: !root.single
            width: parent.width
            spacing: 10

            Cell {
                width: (parent.width - 20) / 3
                image: root.imgOf("left.png")
                label: I18n.t.fpLeft
                level: root.entry ? root.entry.left : -1
            }
            Cell {
                width: (parent.width - 20) / 3
                image: root.imgOf("case.png")
                label: I18n.t.fpCase
                level: root.entry ? root.entry.caseLevel : -1
            }
            Cell {
                width: (parent.width - 20) / 3
                image: root.imgOf("right.png")
                label: I18n.t.fpRight
                level: root.entry ? root.entry.right : -1
            }
        }

        // ── One photo of the set, bars in a row beneath ──────────
        Column {
            visible: root.single
            width: parent.width
            spacing: 6

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: 44
                fillMode: Image.PreserveAspectFit
                source: root.single ? (root.imgBase + "all.png") : ""
                asynchronous: true
                cache: false
            }

            Row {
                width: parent.width
                spacing: 10
                // No picture here — the one above is the set — so the
                // cells fall back to their words.
                Cell {
                    width: (parent.width - 20) / 3
                    label: I18n.t.fpLeft
                    level: root.entry ? root.entry.left : -1
                }
                Cell {
                    width: (parent.width - 20) / 3
                    label: I18n.t.fpCase
                    level: root.entry ? root.entry.caseLevel : -1
                }
                Cell {
                    width: (parent.width - 20) / 3
                    label: I18n.t.fpRight
                    level: root.entry ? root.entry.right : -1
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dismissed()
    }

    // One reading: a photo if there is one, otherwise the word; then a
    // bar filled to the charge and the figure. A side with nothing in
    // it reports -1 and is drawn empty with a dash, not guessed at.
    component Cell: Column {
        id: cell
        property url image: ""
        property string label: ""
        property int level: -1
        readonly property bool known: cell.level >= 0
        spacing: 4

        Item {
            width: cell.width
            height: 40

            Image {
                id: pic
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: cell.image
                asynchronous: true
                cache: false
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: pic.status !== Image.Ready
                text: cell.label
                color: Theme.textTertiary
                font.pixelSize: 10
                font.letterSpacing: 0.4
            }
        }

        Rectangle {
            width: cell.width
            height: 6
            radius: 3
            color: "#22ffffff"

            Rectangle {
                width: parent.width * (cell.known
                    ? Math.max(0, Math.min(100, cell.level)) / 100 : 0)
                height: parent.height
                radius: 3
                // Only a known, low charge is red. An unknown reading is
                // -1, which would otherwise read as "low" and turn the
                // bar red as the peek folds away and the levels clear.
                color: (cell.known && cell.level <= 20) ? Theme.urgent : Theme.accent
                Behavior on width { NumberAnimation { duration: Theme.fadeDuration } }
            }
        }

        Text {
            text: cell.known ? cell.level + "%" : "–"
            color: cell.known ? Theme.textSecondary : Theme.textTertiary
            font.pixelSize: 11
        }
    }
}
