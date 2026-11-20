// ~/.config/rice/wallpicker.qml
// Centred one-row wallpaper picker (Quickshell). Started by wallpaper.sh pick
// (Mod+Shift+W), which passes the wallpaper list, colours and current wallpaper
// in environment variables. Every wallpaper is a tall, thin slice; the selected
// one opens up into a wide card in the middle of the screen.
//
//   A / D, Left / Right, wheel  move          Space   preview behind
//   Enter, click centre card    apply         Esc     cancel (restores the original)
//
// Layout idea from 43PR/dotfiles (MIT, Quickshell). Written separately for this rice.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

ShellRoot {
    id: root

    // ---- data from wallpaper.sh ----
    readonly property var walls: JSON.parse(Quickshell.env("RICE_WALLS") || "[]")
    readonly property var pal: JSON.parse(Quickshell.env("RICE_PALETTE") || "{}")
    readonly property string script: Quickshell.env("RICE_WALL_SCRIPT") || ""
    readonly property string original: Quickshell.env("RICE_WALL_CURRENT") || ""
    // Opens on the middle wallpaper of the list, so there is room to move both ways.
    readonly property int startIndex: Math.floor(root.walls.length / 2)
    property bool previewed: false

    // ---- sizes (tweak here) ----
    readonly property int sliceW: 96      // width of the thin slices
    readonly property int sliceH: 380     // height of the thin slices
    readonly property int selW: 600       // width of the selected card
    readonly property int selH: 420       // height of the selected card
    readonly property int gap: 10         // space between cards
    readonly property real stepFade: 0.07 // slices dim a little more the further out they are

    function col(name, fallback) { return root.pal[name] ? "#" + root.pal[name] : fallback }
    function run(args) {
        if (root.script !== "") Quickshell.execDetached(["bash", root.script].concat(args))
    }
    function apply(i) {
        if (i < 0 || i >= root.walls.length) return
        root.run(["--apply", root.walls[i].path])
        Qt.quit()
    }
    function preview(i) {
        if (i < 0 || i >= root.walls.length) return
        root.previewed = true
        root.run(["--preview", root.walls[i].path])
    }
    function cancel() {
        if (root.previewed && root.original !== "") root.run(["--preview", root.original])
        Qt.quit()
    }

    PanelWindow {
        id: win
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-wallpicker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // Dim the desktop a little; clicking empty space cancels.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.35
            MouseArea { anchors.fill: parent; onClicked: root.cancel() }
        }

        ListView {
            id: list
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: root.selH + 20
            orientation: ListView.Horizontal
            spacing: root.gap
            model: root.walls.length
            clip: false
            focus: true
            boundsBehavior: Flickable.StopAtBounds

            // Keep the current card in the middle of the screen.
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - root.selW / 2
            preferredHighlightEnd: width / 2 + root.selW / 2
            highlightMoveDuration: 260
            Component.onCompleted: {
                list.currentIndex = Math.max(0, Math.min(root.startIndex, root.walls.length - 1))
                list.positionViewAtIndex(list.currentIndex, ListView.Center)
                list.forceActiveFocus()
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.apply(list.currentIndex); event.accepted = true
                } else if (event.key === Qt.Key_Space) {
                    root.preview(list.currentIndex); event.accepted = true
                } else if (event.key === Qt.Key_Escape) {
                    root.cancel(); event.accepted = true
                } else if (event.key === Qt.Key_A) {
                    list.decrementCurrentIndex(); event.accepted = true
                } else if (event.key === Qt.Key_D) {
                    list.incrementCurrentIndex(); event.accepted = true
                }
            }

            delegate: Item {
                id: slot
                required property int index
                readonly property bool current: ListView.isCurrentItem
                readonly property int dist: Math.abs(index - list.currentIndex)

                // The slot itself changes width, so the row reflows smoothly.
                width: current ? root.selW : root.sliceW
                height: list.height
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                ClippingRectangle {
                    id: card
                    anchors.centerIn: parent
                    width: parent.width
                    height: slot.current ? root.selH : root.sliceH
                    radius: 12
                    color: root.col("surface", "#1f2233")
                    opacity: slot.current ? 1 : Math.max(0.45, 0.9 - slot.dist * root.stepFade)
                    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    // Same picture for slice and card; the slice simply shows its middle.
                    Image {
                        anchors.fill: parent
                        source: "file://" + root.walls[slot.index].thumb
                        fillMode: Image.PreserveAspectCrop
                        horizontalAlignment: Image.AlignHCenter
                        asynchronous: true
                        cache: true
                        sourceSize.height: 540
                    }
                }

                // Accent border on the selected card
                Rectangle {
                    anchors.fill: card
                    radius: card.radius
                    color: "transparent"
                    border.width: slot.current ? 3 : 0
                    border.color: root.col("accent", "#86aaec")
                }

                MouseArea {
                    anchors.fill: card
                    cursorShape: Qt.PointingHandCursor
                    onClicked: slot.current ? root.apply(slot.index) : (list.currentIndex = slot.index)
                }
            }
        }

        // Mouse wheel moves one card at a time (clicks still reach the cards).
        MouseArea {
            anchors.fill: list
            acceptedButtons: Qt.NoButton
            onWheel: (wheel) => {
                if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) list.incrementCurrentIndex()
                else list.decrementCurrentIndex()
            }
        }

        // File name of the selected wallpaper
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: list.bottom
            anchors.topMargin: 6
            text: root.walls.length > 0 ? root.walls[list.currentIndex].name : "No images in ~/Pictures/Wallpapers"
            color: root.col("fg", "#c0caf5")
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            font.bold: true
        }

        // Key hints
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 40
            width: hints.implicitWidth + 32
            height: hints.implicitHeight + 16
            radius: 12
            color: root.pal.bg ? "#bf" + root.pal.bg : "#bf14151e"     // #AARRGGBB, 75% opaque
            border.width: 1
            border.color: root.col("accent", "#86aaec")

            Text {
                id: hints
                anchors.centerIn: parent
                text: "A  D  /  ←  →  move     Space  preview     Enter  apply     Esc  cancel"
                color: root.col("muted", "#6b7394")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
            }
        }
    }
}
