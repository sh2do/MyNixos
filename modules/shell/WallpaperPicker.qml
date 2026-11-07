// Animated wallpaper picker: a carousel that slides up over a dimmed screen,
// on a slab of pond glass like the bar's (a lit top rim, a depth gradient and
// reflection band). Each card sits on a faint stone; the selected one rises
// off it with a glowing rim and water drips along its bottom edge.
// Toggle it with `qs -c rice ipc call picker toggle` (Mod+Ctrl+W).
// Left/Right (or h/l, or the wheel) to browse, Enter or click to pick, Esc to close.
// Only loaded while open, so the thumbnails cost no memory the rest of the time.
// The selection's rise and glide run on the picker's own clock (under 60 Hz),
// and only while something moves; the decorations are static.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "picker-motion.js" as Motion

Scope {
    id: root

    property bool open: false
    property var walls: []

    readonly property string home: Quickshell.env("HOME")
    // The menus' drips, rendered by rice-wall from modules/theme/templates/drips.svg.
    readonly property string drips: "file://" + home + "/.cache/rice/drips.png"

    function toggle() {
        if (open) {
            loader.item?.close();
        } else {
            scan.running = true;
            open = true;
        }
    }

    // A faint stone, as under the bar's widgets.
    component Stone: Rectangle {
        radius: 12
        color: Qt.alpha(Theme.text, 0.05)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.07)
    }

    IpcHandler {
        target: "picker"
        function toggle(): void {
            root.toggle();
        }
    }

    Process {
        id: scan
        command: ["find", "-L", root.home + "/.local/share/wallpapers/rotation", root.home + "/.local/share/wallpapers/saved", "-maxdepth", "1", "-type", "f"]
        stdout: StdioCollector {
            onStreamFinished: root.walls = text.trim().split("\n").filter(s => s.length).sort()
        }
    }

    LazyLoader {
        id: loader
        active: root.open

        PanelWindow {
            id: win

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "rice-picker"
            color: "transparent"

            property bool leaving: false

            // Whether rice-wall has rendered the drips yet; until it has, the
            // selected card gets a few plain beads instead.
            readonly property int drips: dripProbe.status
            Image {
                id: dripProbe
                visible: false
                source: root.drips
                cache: false
                asynchronous: true
            }

            function close() {
                leaving = true;
                closeTimer.start();
            }

            function choose(path) {
                Quickshell.execDetached(["env", "RICE_TRANSITION=grow", "rice-wall", "set", path]);
                close();
            }

            Timer {
                id: closeTimer
                interval: 260
                onTriggered: root.open = false
            }

            // The carousel jumps to a new selection at once; this offset (px)
            // puts the cards back where they were and glides them home.
            property real shift: 0
            property real shiftV: 0
            // A key, the wheel or a click moved the selection (not a drag).
            property bool stepping: false

            // The picker's clock: under 60 Hz, and stopped once nothing moves.
            Timer {
                id: clock

                property double last: 0
                property bool busy: false
                signal frame(real dt)

                function wake() {
                    if (!running) {
                        last = Date.now();
                        start();
                    }
                }

                interval: Motion.FRAME_MS
                repeat: true
                onTriggered: {
                    const now = Date.now(), dt = now - last;
                    last = now;
                    busy = false;
                    if (Motion.atRest(win.shift, win.shiftV, 0, Motion.SHIFT_EPS)) {
                        win.shift = 0;
                        win.shiftV = 0;
                    } else {
                        const s = Motion.step(win.shift, win.shiftV, 0, dt, Motion.GLIDE);
                        win.shift = s.x;
                        win.shiftV = s.v;
                        busy = true;
                    }
                    frame(dt);
                    if (!busy)
                        stop();
                }
            }

            Rectangle {
                id: dim
                anchors.fill: parent
                color: Qt.alpha(Theme.surface, 0.55)
                opacity: win.leaving ? 0 : 1
                Component.onCompleted: fadeIn.start()

                NumberAnimation on opacity {
                    id: fadeIn
                    from: 0
                    to: 1
                    duration: 220
                    running: false
                }

                Behavior on opacity {
                    NumberAnimation { duration: 220 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: win.close()
                }
            }

            Item {
                id: stage
                anchors.fill: parent
                opacity: win.leaving ? 0 : 1
                transform: Translate { id: lift; y: win.leaving ? 60 : 0 }

                Behavior on opacity {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                Component.onCompleted: enter.start()

                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: stage; property: "opacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                    NumberAnimation { target: lift; property: "y"; from: 80; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }

                // The glass's drop shadow: 8 px down, a little inset, soft.
                RectangularShadow {
                    anchors.fill: glass
                    offset.y: 8
                    spread: -4
                    blur: 10
                    radius: glass.radius
                    color: Qt.alpha("black", 0.45)
                }

                Rectangle {
                    id: glass

                    anchors.centerIn: parent
                    width: Math.min(parent.width - 96, 2000)
                    height: 360
                    radius: 22
                    color: Qt.alpha(Theme.surface, 0.78)
                    border.width: 1
                    border.color: Qt.alpha(Theme.primary, 0.22)

                    // Clicks on the glass between cards don't close the picker.
                    MouseArea {
                        anchors.fill: parent
                    }

                    // Depth: lit from above, darker toward the bottom.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: glass.radius - 1
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.07) }
                            GradientStop { position: 0.5; color: Qt.alpha(Theme.surface, 0) }
                            GradientStop { position: 1; color: Qt.alpha("black", 0.3) }
                        }
                    }

                    Item {
                        id: well
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.topMargin: 2
                        anchors.bottomMargin: 2
                        clip: true

                        ListView {
                            id: list

                            property real lastX: 0

                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 300
                            orientation: ListView.Horizontal
                            spacing: 22
                            focus: true
                            model: root.walls
                            highlightRangeMode: ListView.StrictlyEnforceRange
                            preferredHighlightBegin: (width - 420) / 2
                            preferredHighlightEnd: (width + 420) / 2
                            // The jump is instant; win.shift glides it on the picker's clock.
                            highlightMoveDuration: 0
                            cacheBuffer: 1000
                            snapMode: ListView.SnapToItem
                            // matugen reports the resolved store path, so match on the file name.
                            currentIndex: Math.max(0, root.walls.findIndex(w => Theme.wallpaper.endsWith("-" + w.split("/").pop())))

                            function step(move) {
                                win.stepping = true;
                                move();
                            }

                            onContentXChanged: {
                                if (win.stepping && !moving) {
                                    const reach = 2 * (420 + spacing);
                                    win.shift = Math.max(-reach, Math.min(reach, win.shift + contentX - lastX));
                                    clock.wake();
                                }
                                lastX = contentX;
                            }
                            onMovementStarted: win.stepping = false

                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape) {
                                    win.close();
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    win.choose(root.walls[currentIndex]);
                                } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                                    step(() => incrementCurrentIndex());
                                } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                                    step(() => decrementCurrentIndex());
                                } else {
                                    return;
                                }
                                event.accepted = true;
                            }

                            delegate: Item {
                                id: card

                                required property string modelData
                                required property int index
                                readonly property bool current: ListView.isCurrentItem

                                // Springs on the picker's clock: the selection (0..1, it
                                // overshoots a little as it rises) and the hover (0..1).
                                property real level: 0
                                property real levelV: 0
                                property real hoverLevel: 0
                                property real hoverV: 0
                                readonly property real rest: 0.8 + 0.08 * hoverLevel
                                readonly property real size: rest + (1.12 - rest) * level

                                width: 420
                                height: 300
                                z: current ? 1 : 0
                                transform: Translate { x: win.shift }

                                Component.onCompleted: level = current ? 1 : 0
                                onCurrentChanged: clock.wake()

                                function advance(dt) {
                                    const t = current ? 1 : 0, h = hover.hovered ? 1 : 0;
                                    if (!Motion.atRest(level, levelV, t, Motion.LEVEL_EPS)) {
                                        const s = Motion.step(level, levelV, t, dt, Motion.RISE);
                                        level = s.x;
                                        levelV = s.v;
                                        clock.busy = true;
                                    } else if (level !== t) {
                                        level = t;
                                        levelV = 0;
                                    }
                                    if (!Motion.atRest(hoverLevel, hoverV, h, Motion.LEVEL_EPS)) {
                                        const s = Motion.step(hoverLevel, hoverV, h, dt, Motion.GLIDE);
                                        hoverLevel = s.x;
                                        hoverV = s.v;
                                        clock.busy = true;
                                    } else if (hoverLevel !== h) {
                                        hoverLevel = h;
                                        hoverV = 0;
                                    }
                                }

                                Connections {
                                    target: clock
                                    function onFrame(dt) {
                                        card.advance(dt);
                                    }
                                }

                                // The stone the card rests on; the selected card lifts off it.
                                Stone {
                                    anchors.centerIn: parent
                                    width: face.width + 20
                                    height: face.height + 20
                                    radius: face.radius + 10
                                    scale: card.size
                                    opacity: 0.6 + 0.4 * Math.min(card.level, 1)
                                }

                                Item {
                                    id: face

                                    readonly property int radius: 18

                                    anchors.centerIn: parent
                                    width: 420
                                    height: 236
                                    scale: card.size
                                    transform: Translate { y: -8 * card.level }

                                    // Its shadow on the stone, and the selected card's glow.
                                    RectangularShadow {
                                        anchors.fill: parent
                                        offset.y: 6
                                        spread: -4
                                        blur: 10
                                        radius: face.radius
                                        color: Qt.alpha("black", 0.4)
                                    }
                                    RectangularShadow {
                                        anchors.fill: parent
                                        spread: 1
                                        blur: 18
                                        radius: face.radius
                                        color: Qt.alpha(Theme.primary, 0.35)
                                        opacity: Math.max(0, Math.min(card.level, 1))
                                        visible: opacity > 0.01
                                    }

                                    ClippingRectangle {
                                        anchors.fill: parent
                                        radius: face.radius
                                        color: Theme.surfaceContainer
                                        opacity: 0.55 + 0.45 * Math.min(card.level, 1)

                                        Image {
                                            anchors.fill: parent
                                            source: "file://" + card.modelData
                                            sourceSize.width: 640
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            smooth: true
                                        }

                                        // Water run down the selected card, gathered at its bottom edge.
                                        Item {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            height: width * 46 / 418
                                            opacity: Math.max(0, Math.min(card.level, 1))
                                            visible: opacity > 0.01

                                            Image {
                                                id: dripArt
                                                anchors.fill: parent
                                                source: win.drips === Image.Ready ? root.drips : ""
                                                cache: false
                                                asynchronous: true
                                                smooth: true
                                            }

                                            // Until rice-wall has rendered the drips: a few plain beads.
                                            Repeater {
                                                model: win.drips === Image.Error ? [[0.07, 22, 3.1], [0.14, 36, 4.4], [0.32, 30, 3.6], [0.47, 18, 2.6], [0.57, 34, 4.8], [0.68, 26, 3.0], [0.83, 33, 3.9], [0.91, 20, 2.5]] : []

                                                Item {
                                                    required property var modelData
                                                    readonly property real r: modelData[2]
                                                    x: modelData[0] * parent.width
                                                    width: 2 * r

                                                    Rectangle {
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        width: 1.6
                                                        height: parent.parent.height * parent.modelData[1] / 46
                                                        gradient: Gradient {
                                                            GradientStop { position: 0; color: Qt.alpha(Theme.text, 0) }
                                                            GradientStop { position: 1; color: Qt.alpha(Theme.primary, 0.24) }
                                                        }
                                                    }
                                                    Rectangle {
                                                        y: parent.parent.height * parent.modelData[1] / 46 - parent.r
                                                        width: 2 * parent.r
                                                        height: width
                                                        radius: width / 2
                                                        color: Qt.alpha(Theme.primary, 0.18)
                                                        border.width: 0.7
                                                        border.color: Qt.alpha(Theme.surface, 0.55)

                                                        Rectangle {
                                                            x: parent.width * 0.22
                                                            y: parent.height * 0.18
                                                            width: Math.max(1, parent.width * 0.3)
                                                            height: width * 0.66
                                                            radius: height / 2
                                                            color: Qt.alpha("white", 0.9)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // The lit rim across the selected card's top, brightest in the middle.
                                        Rectangle {
                                            x: 20
                                            y: 1
                                            width: parent.width - 40
                                            height: 1.5
                                            opacity: Math.max(0, Math.min(card.level, 1))
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0; color: Qt.alpha("white", 0) }
                                                GradientStop { position: 0.5; color: Qt.alpha("white", 0.4) }
                                                GradientStop { position: 1; color: Qt.alpha("white", 0) }
                                            }
                                        }
                                    }

                                    // The glowing rim.
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: face.radius
                                        color: "transparent"
                                        border.width: 2
                                        border.color: Theme.primary
                                        opacity: Math.max(0, Math.min(card.level, 1))
                                        visible: opacity > 0.01
                                    }

                                    // One drop hanging from the rim's lower edge, as under the
                                    // menus' selected row.
                                    Item {
                                        x: parent.width * 0.82
                                        y: parent.height - 1
                                        width: 8
                                        height: 9
                                        opacity: Math.max(0, Math.min(card.level, 1))
                                        visible: opacity > 0.01

                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 4
                                            height: 4
                                            color: Theme.primary
                                        }
                                        Rectangle {
                                            y: 1
                                            width: 8
                                            height: 8
                                            radius: 4
                                            gradient: Gradient {
                                                GradientStop { position: 0; color: Theme.primary }
                                                GradientStop { position: 1; color: Theme.primaryContainer }
                                            }

                                            Rectangle {
                                                x: 1.8
                                                y: 2
                                                width: 2
                                                height: 1.4
                                                radius: 0.7
                                                color: Qt.alpha("white", 0.85)
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: hover
                                        cursorShape: Qt.PointingHandCursor
                                        onHoveredChanged: clock.wake()
                                    }

                                    TapHandler {
                                        onTapped: card.current ? win.choose(card.modelData) : list.step(() => list.currentIndex = card.index)
                                    }
                                }
                            }

                            WheelHandler {
                                onWheel: event => list.step(() => event.angleDelta.y < 0 ? list.incrementCurrentIndex() : list.decrementCurrentIndex())
                            }
                        }
                    }

                    // The glass over the cards: a reflection band under the rim,
                    // and the rim's highlight, brightest in the middle.
                    Rectangle {
                        x: 16
                        y: 2
                        width: parent.width - 32
                        height: 16
                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha("white", 0.05) }
                            GradientStop { position: 1; color: Qt.alpha("white", 0) }
                        }
                    }
                    Rectangle {
                        x: 22
                        y: 1
                        width: parent.width - 44
                        height: 1.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.alpha("white", 0) }
                            GradientStop { position: 0.5; color: Qt.alpha("white", 0.22) }
                            GradientStop { position: 1; color: Qt.alpha("white", 0) }
                        }
                    }
                }

                Stone {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: glass.bottom
                    anchors.topMargin: 18
                    width: hint.implicitWidth + 28
                    height: 28

                    Text {
                        id: hint
                        anchors.centerIn: parent
                        text: "←  →  browse    ⏎  set    esc  close"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }
}
