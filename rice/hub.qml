// ~/.config/rice/hub.qml
// Control centre: drops down under the bar's clock. Opened by hub.sh (Super+I,
// or a click on the clock / status icons), closed by Esc, a click outside it,
// or Super+I again. It only runs while open.
//
//   Left:  date, month calendar (arrows change month), now playing, weather
//   Right: Wi-Fi / Bluetooth / Silence / Auto lock tiles, volume and brightness,
//          battery (laptops), auto lock + sleep timers, CPU / GPU / RAM, ping,
//          and buttons for the wallpaper picker, full settings and power menu.
//
// Values come from hub-data.py every 2 s; changes run the normal tools
// (nmcli, bluetoothctl, wpctl, brightnessctl, swaync-client, playerctl, idle.sh).

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    // ---- data ----
    readonly property string dir: Quickshell.env("RICE_DIR") || (Quickshell.env("HOME") + "/.config/rice")
    readonly property var pal: JSON.parse(Quickshell.env("RICE_PALETTE") || "{}")
    property var d: JSON.parse(Quickshell.env("RICE_HUB_DATA") || "{}")
    property string ping: "..."
    property int calOffset: 0                      // months away from the current one

    // ---- sizes (tweak here) ----
    readonly property int topGap: 50               // distance from the top of the screen (under the bar)
    readonly property int leftW: 250
    readonly property int rightW: 330
    readonly property string font: "JetBrainsMono Nerd Font"

    readonly property var lockSteps: [5, 10, 15, 30, 60]
    readonly property var sleepSteps: [0, 15, 30, 60, 120]

    function col(name, fallback) { return root.pal[name] ? "#" + root.pal[name] : fallback }
    function a(c, alpha) { return Qt.rgba(c.r, c.g, c.b, alpha) }   // colour with transparency
    readonly property color cBg: col("bg", "#14151e")
    readonly property color cSurface: col("surface", "#1f2233")
    readonly property color cFg: col("fg", "#c0caf5")
    readonly property color cMuted: col("muted", "#6b7394")
    readonly property color cAccent: col("accent", "#86aaec")
    readonly property color cUrgent: col("urgent", "#dd6777")
    readonly property color cYellow: col("yellow", "#ecd3a0")
    readonly property color cGreen: col("green", "#90ceaa")

    function g(path, fallback) {            // safe lookup: g("vol.level", 0)
        let v = root.d
        for (const k of path.split(".")) { if (v === undefined || v === null) return fallback; v = v[k] }
        return (v === undefined || v === null) ? fallback : v
    }
    function sh(cmd) { Quickshell.execDetached(["bash", "-c", cmd]); refreshSoon.restart() }
    function rice(args) { Quickshell.execDetached([root.dir + "/" + args[0]].concat(args.slice(1))); refreshSoon.restart() }
    function closeAnd(args) { Quickshell.execDetached(args); Qt.quit() }
    function stepTo(list, current, dir) {
        let i = list.indexOf(current)
        if (i < 0) i = 0
        i = Math.max(0, Math.min(list.length - 1, i + dir))
        return list[i]
    }
    function minutes(m) { return m === 0 ? "Never" : (m >= 60 ? (m / 60) + " h" : m + " min") }

    // ---- refresh ----
    Process {
        id: dataProc
        command: ["python3", root.dir + "/hub-data.py"]
        stdout: SplitParser { onRead: data => { try { root.d = JSON.parse(data) } catch (e) {} } }
    }
    Timer { interval: 2000; running: true; repeat: true; onTriggered: if (!dataProc.running) dataProc.running = true }
    Timer { id: refreshSoon; interval: 450; onTriggered: if (!dataProc.running) dataProc.running = true }

    Process {
        id: pingProc
        command: ["bash", root.dir + "/ping.sh"]
        stdout: SplitParser {
            onRead: data => {
                try { const t = JSON.parse(data).text.replace(/^\S+\s+/, ""); root.ping = t } catch (e) {}
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!pingProc.running) pingProc.running = true }

    // ---- small building blocks ----
    component Label: Text {
        color: root.cFg
        font.family: root.font
        font.pixelSize: 13
    }

    component Tile: Rectangle {
        id: tile
        property bool active: false
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool hasMore: false
        signal toggled()
        signal more()
        width: (root.rightW - 8) / 2
        height: 54
        radius: 12
        color: active ? root.a(root.cAccent, 0.22) : (ma.containsMouse ? root.a(root.cFg, 0.08) : root.a(root.cFg, 0.04))
        border.width: 1
        border.color: active ? root.a(root.cAccent, 0.6) : root.a(root.cFg, 0.12)
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: tile.toggled() }
        Row {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            spacing: 10
            Label { text: tile.icon; font.pixelSize: 17; color: tile.active ? root.cAccent : root.cMuted; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Label { text: tile.title; font.bold: true }
                Label {
                    text: tile.sub; font.pixelSize: 11
                    color: tile.active ? root.cAccent : root.cMuted
                    width: tile.width - 70; elide: Text.ElideRight
                }
            }
        }
        // small arrow on the right opens the full tool (network list, Bluetooth manager)
        Rectangle {
            visible: tile.hasMore
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom; margins: 4 }
            width: 22; radius: 8
            color: mm.containsMouse ? root.a(root.cFg, 0.12) : "transparent"
            Label { anchors.centerIn: parent; text: ""; color: root.cMuted }
            MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: tile.more() }
        }
    }

    component LevelBar: Item {
        id: lb
        property real level: 0           // 0..100 from the system
        property bool dragging: false
        property real dragValue: 0
        readonly property real shown: dragging ? dragValue : level
        signal picked(int value)
        width: 200; height: 22
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: root.a(root.cFg, 0.16)
            Rectangle { width: parent.width * Math.max(0, Math.min(100, lb.shown)) / 100; height: parent.height; radius: 3; color: root.cAccent }
        }
        Rectangle {
            x: parent.width * Math.max(0, Math.min(100, lb.shown)) / 100 - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 7
            color: root.cFg
        }
        Timer { id: send; interval: 70; onTriggered: lb.picked(Math.round(lb.dragValue)) }
        MouseArea {
            anchors.fill: parent
            function setFrom(x) { lb.dragValue = Math.max(0, Math.min(100, x / width * 100)); if (!send.running) send.start() }
            onPressed: mouse => { lb.dragging = true; setFrom(mouse.x) }
            onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
            onReleased: { lb.picked(Math.round(lb.dragValue)); release.restart() }
            onWheel: wheel => { lb.picked(Math.max(0, Math.min(100, Math.round(lb.level + (wheel.angleDelta.y > 0 ? 5 : -5))))) }
        }
        // keep showing the dragged value until the system has caught up
        Timer { id: release; interval: 900; onTriggered: lb.dragging = false }
    }

    component Stepper: Row {
        id: st
        property string icon: ""
        property string title: ""
        property string value: ""
        property bool dim: false
        signal down()
        signal up()
        width: root.rightW; height: 26
        Label { text: st.icon; width: 24; color: root.cMuted; anchors.verticalCenter: parent.verticalCenter }
        Label { text: st.title; width: st.width - 24 - 130; color: st.dim ? root.cMuted : root.cFg; anchors.verticalCenter: parent.verticalCenter }
        Row {
            width: 130; spacing: 0; layoutDirection: Qt.RightToLeft
            anchors.verticalCenter: parent.verticalCenter
            SmallButton { text: ""; onClicked: st.up() }
            Label { text: st.value; width: 66; horizontalAlignment: Text.AlignHCenter; font.bold: true; anchors.verticalCenter: parent.verticalCenter; color: st.dim ? root.cMuted : root.cFg }
            SmallButton { text: ""; onClicked: st.down() }
        }
    }

    component SmallButton: Rectangle {
        id: sb
        property string text: ""
        property int size: 11
        signal clicked()
        width: 26; height: 24; radius: 8
        color: sbm.containsMouse ? root.a(root.cFg, 0.12) : "transparent"
        Label { anchors.centerIn: parent; text: sb.text; font.pixelSize: sb.size; color: root.cFg }
        MouseArea { id: sbm; anchors.fill: parent; hoverEnabled: true; onClicked: sb.clicked() }
    }

    component Pill: Rectangle {
        id: pl
        property string icon: ""
        property string text: ""
        property color tint: root.cFg
        signal clicked()
        width: plRow.width + 20; height: 30; radius: 10
        color: plm.containsMouse ? root.a(root.cAccent, 0.22) : root.a(root.cFg, 0.05)
        border.width: 1; border.color: root.a(root.cFg, 0.12)
        Row {
            id: plRow; anchors.centerIn: parent; spacing: 7
            Label { text: pl.icon; color: pl.tint }
            Label { text: pl.text; visible: pl.text !== "" }
        }
        MouseArea { id: plm; anchors.fill: parent; hoverEnabled: true; onClicked: pl.clicked() }
    }

    component Stat: Rectangle {
        id: stt
        property string name: ""
        property int value: -1
        property int count: 3
        width: (root.rightW - 6 * (count - 1)) / count; height: 44; radius: 10
        color: root.a(root.cFg, 0.05)
        Column {
            anchors.centerIn: parent
            Label { text: stt.name; font.pixelSize: 11; color: root.cMuted; anchors.horizontalCenter: parent.horizontalCenter }
            Label {
                text: stt.value < 0 ? "n/a" : stt.value + "%"
                font.bold: true; font.pixelSize: 14
                color: stt.value >= 90 ? root.cUrgent : (stt.value >= 70 ? root.cYellow : root.cFg)
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ---- calendar ----
    function calMonth() {
        const now = new Date()
        return new Date(now.getFullYear(), now.getMonth() + root.calOffset, 1)
    }
    function calCells() {
        const first = calMonth()
        const y = first.getFullYear(), m = first.getMonth()
        const lead = (first.getDay() + 6) % 7          // weeks start on Monday
        const start = new Date(y, m, 1 - lead)
        const today = new Date()
        let cells = []
        for (let i = 0; i < 42; i++) {
            const c = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
            cells.push({ day: c.getDate(), inMonth: c.getMonth() === m,
                         today: c.toDateString() === today.toDateString() })
        }
        return cells
    }

    // ---- the window ----
    PanelWindow {
        id: win
        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-hub"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        // Click anywhere outside the panel to close it.
        MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

        Item {
            focus: true
            Keys.onEscapePressed: Qt.quit()
        }

        Rectangle {
            id: panel
            x: (parent.width - width) / 2
            y: root.topGap
            width: body.width + 32
            height: body.height + 32
            radius: 18
            color: root.a(root.cBg, 0.82)
            border.width: 1
            border.color: root.a(root.cAccent, 0.3)
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: 160 } }

            MouseArea { anchors.fill: parent }       // clicks inside never close it

            Row {
                id: body
                x: 16; y: 16
                spacing: 18

                // ================= left column =================
                Column {
                    width: root.leftW
                    spacing: 12

                    Column {
                        spacing: 2
                        Label { text: Qt.formatDate(new Date(), "dddd"); font.pixelSize: 20; font.bold: true }
                        Label { text: Qt.formatDate(new Date(), "d MMMM yyyy"); color: root.cMuted }
                    }

                    // month header with arrows
                    Item {
                        width: root.leftW; height: 26
                        SmallButton { anchors.left: parent.left; text: ""; onClicked: root.calOffset-- }
                        Label {
                            anchors.centerIn: parent
                            text: Qt.formatDate(root.calMonth(), "MMMM yyyy")
                            font.bold: true
                            MouseArea { anchors.fill: parent; onClicked: root.calOffset = 0 }   // click: back to today
                        }
                        SmallButton { anchors.right: parent.right; text: ""; onClicked: root.calOffset++ }
                    }

                    Grid {
                        columns: 7
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Label { width: root.leftW / 7; height: 22; text: modelData; font.pixelSize: 11; color: root.cMuted; horizontalAlignment: Text.AlignHCenter }
                        }
                        Repeater {
                            model: root.calCells()
                            Rectangle {
                                width: root.leftW / 7; height: 27; radius: 8
                                color: modelData.today && root.calOffset === 0 ? root.cAccent : "transparent"
                                Label {
                                    anchors.centerIn: parent
                                    text: modelData.day
                                    font.pixelSize: 12
                                    font.bold: modelData.today
                                    color: modelData.today && root.calOffset === 0 ? root.cBg : (modelData.inMonth ? root.cFg : root.a(root.cMuted, 0.6))
                                }
                            }
                        }
                    }

                    // now playing (only while something plays)
                    Rectangle {
                        visible: root.g("media.active", false)
                        width: root.leftW; height: 92; radius: 12
                        color: root.a(root.cFg, 0.05)
                        border.width: 1; border.color: root.a(root.cFg, 0.1)
                        Column {
                            x: 12; y: 10; width: parent.width - 24; spacing: 2
                            Label { text: "  Now playing"; font.pixelSize: 11; color: root.cMuted }
                            Label { text: root.g("media.title", ""); font.bold: true; width: parent.width; elide: Text.ElideRight }
                            Label { text: root.g("media.artist", ""); font.pixelSize: 11; color: root.cMuted; width: parent.width; elide: Text.ElideRight }
                        }
                        Row {
                            anchors { bottom: parent.bottom; bottomMargin: 6; horizontalCenter: parent.horizontalCenter }
                            spacing: 14
                            SmallButton { text: ""; onClicked: root.sh("playerctl previous") }
                            SmallButton { text: root.g("media.playing", false) ? "" : ""; onClicked: root.sh("playerctl play-pause") }
                            SmallButton { text: ""; onClicked: root.sh("playerctl next") }
                        }
                    }

                    // weather (from the bar's cache; set the city in Settings > Weather location)
                    Rectangle {
                        visible: root.g("weather", "") !== ""
                        width: root.leftW; height: 40; radius: 12
                        color: root.a(root.cFg, 0.05)
                        Label { anchors.verticalCenter: parent.verticalCenter; x: 12; text: root.g("weather", ""); width: parent.width - 24; elide: Text.ElideRight }
                    }
                }

                // ================= right column =================
                Column {
                    width: root.rightW
                    spacing: 10

                    Grid {
                        columns: 2; spacing: 8
                        Tile {
                            icon: root.g("net.wired", false) && !root.g("net.wifiOn", false) ? "" : ""
                            title: "Wi-Fi"
                            active: root.g("net.wifiOn", false)
                            sub: active ? (root.g("net.ssid", "") || (root.g("net.wired", false) ? "Wired" : "Not connected"))
                                    : (root.g("net.wired", false) ? "Off, wired in" : "Off")
                            hasMore: true
                            onToggled: root.sh(active ? "nmcli radio wifi off" : "nmcli radio wifi on")
                            onMore: root.closeAnd(["kitty", "--class", "rice-dialog", "--title", "Wi-Fi", "nmtui", "connect"])
                        }
                        Tile {
                            icon: ""
                            title: "Bluetooth"
                            active: root.g("bt.on", false)
                            sub: !root.g("bt.present", false) ? "No adapter" : (active ? (root.g("bt.device", "") || "On") : "Off")
                            hasMore: root.g("bt.present", false)
                            onToggled: if (root.g("bt.present", false)) root.sh(active ? "bluetoothctl power off" : "bluetoothctl power on")
                            onMore: root.closeAnd(["blueman-manager"])
                        }
                        Tile {
                            icon: ""
                            title: "Silence"
                            active: root.g("dnd", false)
                            sub: active ? (root.g("gamemode", false) ? "On, game mode" : "On") : "Off"
                            onToggled: root.sh("swaync-client -d -sw")
                        }
                        Tile {
                            icon: ""
                            title: "Auto lock"
                            active: root.g("idle.enabled", false)
                            sub: active ? ("After " + root.minutes(root.g("idle.lock", 10))) : "Off"
                            onToggled: root.rice(["idle.sh", "toggle"])
                        }
                    }

                    // volume
                    Row {
                        spacing: 8; height: 26
                        SmallButton {
                            text: root.g("vol.muted", false) ? "" : ""
                            size: 15
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: root.sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
                        }
                        LevelBar {
                            width: root.rightW - 34 - 52
                            anchors.verticalCenter: parent.verticalCenter
                            level: root.g("vol.level", 0)
                            opacity: root.g("vol.muted", false) ? 0.45 : 1
                            onPicked: value => root.sh("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + (value / 100).toFixed(2))
                        }
                        Label { width: 44; text: root.g("vol.muted", false) ? "muted" : root.g("vol.level", 0) + "%"; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; color: root.cMuted }
                    }

                    // brightness (laptop screens only)
                    Row {
                        visible: root.g("bright", -1) >= 0
                        spacing: 8; height: 26
                        SmallButton { text: ""; size: 15; anchors.verticalCenter: parent.verticalCenter }
                        LevelBar {
                            width: root.rightW - 34 - 52
                            anchors.verticalCenter: parent.verticalCenter
                            level: root.g("bright", 0)
                            onPicked: value => root.sh("brightnessctl -q set " + Math.max(1, value) + "%")
                        }
                        Label { width: 44; text: root.g("bright", 0) + "%"; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter; color: root.cMuted }
                    }

                    // battery (laptops only)
                    Row {
                        visible: root.g("bat.present", false)
                        spacing: 8; height: 24
                        Label {
                            width: 26; horizontalAlignment: Text.AlignHCenter
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.g("bat.status", "") === "Charging" ? "" : ""
                            color: root.g("bat.level", 100) <= 10 ? root.cUrgent : (root.g("bat.level", 100) <= 20 ? root.cYellow : root.cGreen)
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Battery " + root.g("bat.level", 0) + "%"
                                  + (root.g("bat.time", "") !== "" ? "  ·  " + root.g("bat.time", "") : "  ·  " + root.g("bat.status", ""))
                        }
                    }

                    Rectangle { width: root.rightW; height: 1; color: root.a(root.cFg, 0.1) }

                    Stepper {
                        icon: ""; title: "Lock after"
                        value: root.minutes(root.g("idle.lock", 10))
                        dim: !root.g("idle.enabled", false)
                        onDown: root.rice(["idle.sh", "set", "lock", String(root.stepTo(root.lockSteps, root.g("idle.lock", 10), -1))])
                        onUp: root.rice(["idle.sh", "set", "lock", String(root.stepTo(root.lockSteps, root.g("idle.lock", 10), 1))])
                    }
                    Stepper {
                        icon: ""; title: "Sleep after"
                        value: root.minutes(root.g("idle.sleep", 0))
                        dim: !root.g("idle.enabled", false)
                        onDown: root.rice(["idle.sh", "set", "sleep", String(root.stepTo(root.sleepSteps, root.g("idle.sleep", 0), -1))])
                        onUp: root.rice(["idle.sh", "set", "sleep", String(root.stepTo(root.sleepSteps, root.g("idle.sleep", 0), 1))])
                    }

                    Rectangle { width: root.rightW; height: 1; color: root.a(root.cFg, 0.1) }

                    // GPU only shows on AMD graphics (the kernel reports its load directly)
                    Row {
                        spacing: 6
                        readonly property int n: root.g("gpu", -1) >= 0 ? 3 : 2
                        Stat { name: "CPU"; value: root.g("cpu", -1); count: parent.n }
                        Stat { name: "GPU"; value: root.g("gpu", -1); count: parent.n; visible: value >= 0 }
                        Stat { name: "RAM"; value: root.g("ram", -1); count: parent.n }
                    }

                    Row {
                        spacing: 8; height: 22
                        Label { text: ""; width: 24; color: root.cMuted; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "Internet"; width: root.rightW - 24 - 100 - 16; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: root.ping; width: 100; horizontalAlignment: Text.AlignRight; color: root.cMuted; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Row {
                        spacing: 8
                        anchors.right: parent.right
                        Pill { icon: ""; text: "Wallpaper"; onClicked: root.closeAnd([root.dir + "/wallpaper.sh", "pick"]) }
                        Pill { icon: ""; text: "Settings"; onClicked: root.closeAnd([root.dir + "/settings-menu.sh"]) }
                        Pill { icon: ""; tint: root.cUrgent; onClicked: root.closeAnd([root.dir + "/power-menu.sh"]) }
                    }
                }
            }
        }
    }
}
