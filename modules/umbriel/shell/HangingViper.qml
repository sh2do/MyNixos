// A horned viper hanging head down from under the island (the "dripping
// viper" board, hang A), jaws open, venom dripping from its forward fang.
// Island.qml hosts it under the pill, 30 px right of centre so the spider
// still drops from the centre; this item fills the island's window.
//
// The body is a Serpent (GPU-bent) wearing HangingViperSkin; it comes out
// from behind the pill and falls in a slow S about 130 px long. Everything
// else is drawn once and moved by transforms: the head (side on, from the
// detail sheet: hinged jaws, horn, slit-pupilled eye, pale lining, two fangs
// swung forward), the hiss puff and up to four venom drops (venom.js).
//
// Alive on one clock that runs only as fast as the motion needs (every
// repaint of the island's window costs CPU, whatever changes in it):
// - 15 Hz idle: a ±3° pendulum sway about the hang point (a rotation) and a
//   slow coil and uncoil, the only thing that re-bends the body, at most
//   15 times a second and only while it changes;
// - 30 Hz while a bead swells on the fang;
// - the display's rate only while a drop necks, falls or splashes, and while
//   the viper pulls up or lowers itself.
// UMBRIEL_SERPENT_FPS caps all three. Nothing runs while it is pulled up, the
// island is hidden, the session is locked or the screen is off.
//
// The drip follows the CPU load (/proc/stat every 2 s): a drop every 4 s
// when calm, every 0.6 s at full load. Drops land on the top edge of the
// highest window below them (UmbrielIpc.windows), or fade out 300 px down.
//
// It pulls up behind the pill (0.6 s) while a window is fullscreen, the
// island is open or shows anything but the clock, and comes back down 2 s
// after. For fullscreen it hisses first (300 ms); `holdsIsland` keeps the
// island shown until it is gone.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "." as U
import "venom.js" as Venom
import "serpent-spine.js" as Spine
import "wall-cover.js" as Cover

Item {
    id: root

    // The Island window this hangs from.
    required property var island

    // Where the body comes out, behind the pill, and the line (the clock
    // pill's middle) above which it is hidden, in window coordinates.
    readonly property real hangX: width / 2 + 30
    readonly property real hangY: 24
    readonly property real clipTop: 28

    readonly property real bodyWidth: 12
    readonly property real bodyLength: 150

    anchors.fill: parent

    // Retreat and return

    // out: hanging | hiss: hissing, then up | up: pulling up | away: behind
    // the pill | down: lowering itself.
    property string mode: "away"
    readonly property bool cause: UmbrielIpc.fullscreen || island.expanded || island.view !== "clock"
    // Already true the moment fullscreen starts, so the island never blinks
    // off before the hiss.
    readonly property bool holdsIsland: UmbrielIpc.fullscreen && mode !== "away"

    onCauseChanged: {
        if (cause) {
            back.stop();
            if (mode === "out" || mode === "down") {
                clearDrops(true);
                if (UmbrielIpc.fullscreen && mode === "out") {
                    life.hissAt = life.t;
                    mode = "hiss";
                } else {
                    mode = "up";
                }
            }
        } else if (mode !== "out" && mode !== "down") {
            back.restart();
        }
    }
    Component.onCompleted: if (!cause) back.restart()

    Timer {
        id: back
        interval: 2000
        onTriggered: if (!root.cause) root.mode = "down"
    }

    // The clock

    readonly property int fpsCap: parseInt(Quickshell.env("UMBRIEL_SERPENT_FPS") || "") || 0
    readonly property bool running: island.visible && !locked && !Cover.outputOff(UmbrielIpc.outputs, island.screen?.name ?? "")
    readonly property bool active: running && (mode !== "away" || dropCount > 0)
    onRunningChanged: if (!running) clearDrops(false)

    // Set by each tick: drops on the move, a bead on the fang, drops alive.
    property bool dropsFast: false
    property bool beading: false
    property int dropCount: 0
    readonly property bool fast: dropsFast || mode === "hiss" || mode === "up" || mode === "down"
    readonly property int idleHz: 15

    // 0 pulled up .. 1 hanging; the pendulum, in degrees; the coil, 0..1;
    // the hiss, 0..1 through its 300 ms.
    property real out: 0
    property real sway: 0
    property real coil: 0
    property real hiss: 0

    QtObject {
        id: life

        property real t: 0
        property real hissAt: 0
        property real bent: -1
        property real bendAcc: 1
        property real nextDrop: 0
        property var drops: [null, null, null, null]
        property var sample: null
    }

    property real load: 0
    readonly property int interval: Venom.dripInterval(load)

    function ease(u) {
        const t = Math.min(Math.max(u, 0), 1);
        return t * t * (3 - 2 * t);
    }

    // dt: seconds since the last tick, already clamped by its clock.
    function tick(dt) {
        life.t += dt;
        const t = life.t;

        if (mode === "hiss") {
            hiss = Math.min((t - life.hissAt) / 0.3, 1);
            if (hiss >= 1) {
                hiss = 0;
                mode = "up";
            }
        }
        if (mode === "up") {
            out = Math.max(0, out - dt / 0.6);
            if (out === 0)
                mode = "away";
        } else if (mode === "down") {
            out = Math.min(1, out + dt / 1.2);
            if (out === 1) {
                mode = "out";
                life.nextDrop = t + 1.2;
            }
        }

        // A pendulum with a slow drift in its swing, and the coil.
        sway = 3 * Math.sin(2 * Math.PI * t / 5.5) * (0.82 + 0.18 * Math.sin(2 * Math.PI * t / 17));
        coil = 0.5 - 0.5 * Math.cos(2 * Math.PI * t / 14);

        // Straight while pulled up, so it slides into the island cleanly.
        const bend = ease(out) * (0.38 + 0.27 * coil);
        life.bendAcc += dt;
        if (Math.abs(bend - life.bent) > 0.0015 && (fast || life.bendAcc >= 1 / root.idleHz - 0.001))
            bendBody(bend);

        stepDrops(dt);
    }

    // The S: the spine's heading wanders round straight down along its
    // length (bend: the swing, in radians), integrated from the hang point
    // so the body keeps its length however much it coils. Neck first.
    function bendBody(bend) {
        const n = 16, steps = 240, L = root.bodyLength, ds = L / steps;
        const pts = new Array(n);
        let x = root.hangX, y = root.hangY;
        pts[n - 1] = { x: x, y: y };
        for (let i = 1; i <= steps; i++) {
            const s = (i - 0.5) * ds;
            const a = Math.PI / 2 + bend * Math.cos(2 * Math.PI * s / 125 + 0.77) + 0.15 * Math.pow(Math.max(0, (s - L + 30) / 30), 2);
            x += Math.cos(a) * ds;
            y += Math.sin(a) * ds;
            if (i % (steps / (n - 1)) === 0)
                pts[n - 1 - i / (steps / (n - 1))] = { x: x, y: y };
        }
        body.setSpine(pts, root.widths);
        life.bent = bend;
        life.bendAcc = 0;
    }

    // Narrower at the neck, under the head; full width from there up.
    readonly property var widths: {
        const ws = new Array(Spine.SPINE_POINTS);
        for (let k = 0; k < ws.length; k++)
            ws[k] = 0.68 + 0.32 * ease(k / (ws.length - 1) / 0.2);
        return ws;
    }

    // Venom

    // The windows on this output's active workspace, in window coordinates.
    readonly property var windows: {
        const s = island.screen;
        if (!s)
            return [];
        const ox = s.x + (s.width - island.width) / 2, oy = s.y + island.margins.top;
        return UmbrielIpc.windows.filter(w => w.output === s.name && w.visible && !w.minimized).map(w => ({ x: w.x - ox, y: w.y - oy, w: w.w, h: w.h }));
    }

    function fadeAt(d) {
        return Math.min(d.y0 + 300, root.height - 8);
    }

    function stepDrops(dt) {
        const ds = life.drops;
        let onFang = false, fastNow = false, beadNow = false, count = 0;
        const tip = head.fang.mapToItem(root, 0, 0);
        for (let i = 0; i < ds.length; i++) {
            const d = ds[i];
            if (!d)
                continue;
            if (d.phase === "bead" || d.phase === "thread") {
                d.x = tip.x;
                d.anchorY = tip.y;
            }
            Venom.dropStep(d, dt, root.windows, fadeAt(d));
            if (d.phase === "gone") {
                ds[i] = null;
                continue;
            }
            count++;
            onFang = onFang || d.phase === "bead" || d.phase === "thread";
            beadNow = beadNow || d.phase === "bead";
            fastNow = fastNow || d.phase !== "bead";
        }
        if (mode === "out" && !onFang && life.t >= life.nextDrop) {
            const free = ds.indexOf(null);
            if (free >= 0) {
                ds[free] = Venom.newDrop(tip.x, tip.y, Venom.beadTime(root.interval));
                life.nextDrop = life.t + root.interval / 1000;
                count++;
                beadNow = true;
            }
        }
        for (let i = 0; i < ds.length; i++)
            dropItems.itemAt(i).show(ds[i]);
        dropsFast = fastNow;
        beading = beadNow;
        dropCount = count;
    }

    // Drops still on the fang go with it; with `onlyFang` false, all of them.
    function clearDrops(onlyFang) {
        const ds = life.drops;
        let count = 0;
        for (let i = 0; i < ds.length; i++) {
            if (ds[i] && (!onlyFang || ds[i].phase === "bead" || ds[i].phase === "thread"))
                ds[i] = null;
            if (ds[i])
                count++;
            dropItems.itemAt(i)?.show(ds[i]);
        }
        dropCount = count;
        beading = false;
        if (!count)
            dropsFast = false;
    }

    FrameAnimation {
        running: root.active && root.fast && root.fpsCap <= 0
        onTriggered: root.tick(Spine.step(frameTime))
    }
    Timer {
        readonly property int hz: {
            const want = root.fast ? 1000 : root.beading ? 30 : root.idleHz;
            return root.fpsCap > 0 ? Math.min(want, root.fpsCap) : want;
        }
        property real last: 0
        running: root.active && !(root.fast && root.fpsCap <= 0)
        interval: 1000 / Math.max(1, hz)
        repeat: true
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            root.tick(Venom.clockStep((now - last) / 1000, hz));
            last = now;
        }
    }

    // The load, and the lock (Umbriel's IPC doesn't report it; the rice-lock
    // locker keeps this file while the lock is secure, as Background.qml
    // reads it), every 2 s while the island shows.
    property bool locked: false
    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const r = Venom.parseLoad(life.sample, text());
            life.sample = r.sample;
            root.load = r.load;
        }
        onLoadFailed: {
            life.sample = null;
            root.load = 0;
        }
    }
    FileView {
        id: lockFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/rice-lock.secure"
        printErrors: false
        onLoaded: root.locked = true
        onLoadFailed: root.locked = false
    }
    Timer {
        interval: 2000
        repeat: true
        running: root.island.visible
        onTriggered: {
            lockFile.reload();
            if (root.mode !== "away")
                stat.reload();
        }
    }

    // Drawing

    HangingViperSkin {
        id: skinStrip
        bodyWidth: root.bodyWidth
        bodyLength: root.bodyLength
    }

    // Hidden above the pill's middle, so it comes out from behind the island.
    Item {
        y: root.clipTop
        width: root.width
        height: root.height - y
        clip: true
        visible: root.out > 0

        // Pulled straight up by its full length when away.
        Item {
            y: -root.clipTop - (1 - root.ease(root.out)) * (root.hangY + root.bodyLength - root.clipTop + 50)
            width: root.width
            height: root.height

            Item {
                id: swing
                anchors.fill: parent
                transform: Rotation {
                    origin.x: root.hangX
                    origin.y: root.hangY
                    angle: root.sway
                }

                Serpent {
                    id: body
                    skin: skinStrip
                    bodyWidth: root.bodyWidth
                    shadowOffset: Qt.point(2, 4)
                    Component.onCompleted: root.bendBody(0)
                }

                Head {
                    id: head
                    readonly property var p: body.head
                    visible: p !== null
                    x: p?.x ?? 0
                    y: p?.y ?? 0
                    // The spine's tangent runs neck to tail; the head points
                    // the other way, turned so the open jaws gape downward.
                    rotation: p ? Math.atan2(-p.ty, -p.tx) * 180 / Math.PI + 6 : 90
                    hiss: root.hiss
                }
            }
        }
    }

    // The drops, unrotated and unclipped, in window coordinates.
    Repeater {
        id: dropItems
        model: 4
        Drop {}
    }

    // The head, side on: the detail sheet's parts on the overview board's
    // stockier head, so it reads at this size. Drawn in head units (×1.3 px)
    // with the origin at the neck joint and the snout along +x, the crown
    // toward -y. The jaws are hinged at the mouth's corner: the upper tilted
    // up 28° (a little more in a hiss), the lower dropped 16°.
    readonly property real headScale: 1.3
    // The forward fang's tip on the upper jaw, before its tilt.
    readonly property point fangAt: Qt.point(17.6, 4.4)
    readonly property point upperHinge: Qt.point(-4, 0)

    component Lines: ShapePath {
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    component Head: Item {
        id: hd

        property real hiss: 0
        readonly property real upper: -28 - 8 * Math.sin(Math.PI * hiss)
        readonly property Item fang: fangTip

        // A soft shadow on the desktop, at the body's offset.
        Shape {
            x: 2
            y: 4
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 10; centerY: 0; centerRadius: 16
                    focalX: 10; focalY: 0
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.42) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
                }
                PathSvg { path: "M -6 0 a 16 13 0 1 0 32 0 a 16 13 0 1 0 -32 0" }
            }
        }

        Item {
            scale: root.headScale
            transformOrigin: Item.TopLeft

            // The throat, dark between the open jaws.
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: U.Palette.viperOutline
                    strokeColor: "transparent"
                    PathSvg { path: "M -4.5 0.3 L 9 -4.6 Q 12.5 1.4 9 6.4 Z" }
                }
            }

            // Lower jaw, dropped: the pale lining and small teeth along its
            // top, a row of lip scales.
            Shape {
                preferredRendererType: Shape.CurveRenderer
                transform: Rotation { origin.x: -4; origin.y: 0.6; angle: 16 }
                ShapePath {
                    fillColor: Qt.darker(U.Palette.viperBody, 1.25)
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 0.7
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M -4.5 0.6 L 9 1.4 Q 14.6 1.9 15.4 3.1 Q 15 4.8 12 5.3 C 7 6.1 1 6.3 -4.5 6.5 Z" }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperEye, 0.55)
                    strokeColor: "transparent"
                    PathSvg { path: "M -3.6 1.1 L 9 1.9 L 14.2 2.5 L 13.4 3.2 L 9 2.9 L -3.6 2.4 Z" }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperEye, 0.85)
                    strokeColor: "transparent"
                    PathSvg { path: "M 2 1.6 l 0.5 -1 l 0.5 1.1 Z M 5.4 1.8 l 0.5 -1 l 0.5 1.1 Z M 8.8 2 l 0.45 -0.9 l 0.45 1 Z M 11.8 2.3 l 0.4 -0.8 l 0.4 0.9 Z" }
                }
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperBlotch, 0.95)
                    strokeWidth: 0.45
                    PathSvg { path: "M -1 5.6 l 2.4 -0.1 M 2.8 5.5 l 2.4 -0.1 M 6.6 5.3 l 2.4 -0.2 M 10.2 4.9 l 2 -0.3" }
                }
            }

            // Upper jaw, tilted up.
            Shape {
                preferredRendererType: Shape.CurveRenderer
                transform: Rotation { origin.x: root.upperHinge.x; origin.y: root.upperHinge.y; angle: hd.upper }
                // Fangs first, swung forward out of the mouth: the rear one,
                // then the forward one the venom drips from.
                ShapePath {
                    fillColor: U.Palette.bright
                    strokeColor: U.Palette.viperKeel
                    strokeWidth: 0.3
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 9.4 -0.9 Q 12.6 0.4 13.4 3.4 L 10.9 -0.2 Z M 12.4 -1.3 Q 16.4 0.2 17.6 4.4 L 14.3 -0.3 Z" }
                }
                // The head: broad jowls narrowing to a blunt snout.
                ShapePath {
                    fillColor: U.Palette.viperBody
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 0.7
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M -6 -6.2 C -2.4 -8.8 3.4 -10 9 -9.8 Q 15.4 -9.4 17 -6.2 Q 18 -4.4 17.4 -2.6 Q 16.8 -1.5 15 -1.4 L 9 -0.8 L -4.5 0.3 Z" }
                }
                // The dark stripe from the eye back to the jaw's corner, and
                // a blotch on the crown.
                Lines {
                    strokeColor: U.Palette.viperBlotch
                    strokeWidth: 1.5
                    PathSvg { path: "M 6.4 -5 C 3.6 -4.2 0.6 -3.2 -3.4 -1.8" }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperBlotch, 0.9)
                    strokeColor: "transparent"
                    PathSvg { path: "M -3.4 -6.6 C -1 -8.2 2.2 -8.6 3.4 -7.8 C 2.6 -6.2 -1 -5.6 -3.4 -6.6 Z" }
                }
                // Keeled scales: rows of pale ridges over the crown and
                // cheek, and the lip scales.
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperKeel, 0.75)
                    strokeWidth: 0.4
                    PathSvg { path: "M -4.2 -4.8 l 1.6 -0.5 M -1.6 -5.6 l 1.6 -0.5 M 4.2 -8.8 l 1.6 -0.3 M 11.8 -8.8 l 1.5 0.2 M 14 -7.6 l 1.2 0.6 M -2.2 -3 l 1.6 -0.4 M 0.8 -3.8 l 1.6 -0.4 M 10.6 -6.6 l 1.5 0 M 13.2 -5.6 l 1.4 0.3 M 2 -6.6 l 1.5 -0.4" }
                }
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.85)
                    strokeWidth: 0.35
                    PathSvg { path: "M 0 -0.2 l 0 -1.1 M 3.2 -0.5 l 0 -1.1 M 6.4 -0.7 l 0 -1.1 M 9.6 -1 l 0 -1.1 M 12.6 -1.2 l 0 -1.1 M 15.2 -1.5 l 0.2 -1" }
                }
                // The pale mouth lining.
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperEye, 0.65)
                    strokeColor: "transparent"
                    PathSvg { path: "M 16.6 -1.6 L 9 -0.8 L -4.2 0.3 L -4.2 1.3 L 9 0.4 L 15.6 -0.5 Z" }
                }
                // The nostril.
                ShapePath {
                    fillColor: U.Palette.viperOutline
                    strokeColor: "transparent"
                    PathSvg { path: "M 15.1 -4.8 a 0.55 0.45 0 1 0 1.1 0 a 0.55 0.45 0 1 0 -1.1 0" }
                }
                // The horn over the eye, its scales ridged.
                ShapePath {
                    fillColor: U.Palette.viperKeel
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 0.55
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 5.6 -9.4 C 6.2 -11.8 7.2 -14.2 8.4 -16.4 C 9 -14.2 9.8 -11.8 10.6 -9.6 Z" }
                }
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.6)
                    strokeWidth: 0.3
                    PathSvg { path: "M 7 -11.6 l 2.2 -0.1 M 7.6 -13.6 l 1.4 0" }
                }
                // The eye: dark ring, pale iris, slit pupil, a catch-light.
                ShapePath {
                    fillColor: U.Palette.viperOutline
                    strokeColor: "transparent"
                    PathSvg { path: "M 5.9 -6.4 a 2.2 2.2 0 1 0 4.4 0 a 2.2 2.2 0 1 0 -4.4 0" }
                }
                ShapePath {
                    fillColor: U.Palette.viperEye
                    strokeColor: "transparent"
                    PathSvg { path: "M 6.4 -6.4 a 1.7 1.7 0 1 0 3.4 0 a 1.7 1.7 0 1 0 -3.4 0" }
                }
                ShapePath {
                    fillColor: U.Palette.viperOutline
                    strokeColor: "transparent"
                    PathSvg { path: "M 8.1 -8 C 8.55 -7.2 8.55 -5.6 8.1 -4.8 C 7.65 -5.6 7.65 -7.2 8.1 -8 Z" }
                }
                ShapePath {
                    fillColor: U.Palette.bright
                    strokeColor: "transparent"
                    PathSvg { path: "M 7 -7.2 a 0.42 0.42 0 1 0 0.84 0 a 0.42 0.42 0 1 0 -0.84 0" }
                }
            }
        }

        // The forward fang's tip, where the venom beads, after the tilt.
        Item {
            id: fangTip
            readonly property real a: hd.upper * Math.PI / 180
            readonly property real dx: root.fangAt.x - root.upperHinge.x
            readonly property real dy: root.fangAt.y - root.upperHinge.y
            x: root.headScale * (root.upperHinge.x + dx * Math.cos(a) - dy * Math.sin(a))
            y: root.headScale * (root.upperHinge.y + dx * Math.sin(a) + dy * Math.cos(a))
        }

        // The hiss: two pale arcs puffing out of the open mouth.
        Shape {
            visible: hd.hiss > 0
            x: 26
            y: 0
            opacity: 0.55 * Math.sin(Math.PI * hd.hiss)
            scale: 0.7 + 0.8 * hd.hiss
            transformOrigin: Item.Left
            preferredRendererType: Shape.CurveRenderer
            Lines {
                strokeColor: U.Palette.bright
                strokeWidth: 1
                PathSvg { path: "M 3 -5 Q 7 0 3 5 M 8 -8.5 Q 14 0 8 8.5" }
            }
        }
    }

    // One drop of venom, centred on its x, y. Moved and shaped only by
    // transforms and opacity; show(d) copies a venom.js drop in.
    component Drop: Item {
        id: drop

        property string phase: "gone"
        property real t: 0
        property real swell: 0
        property real stretch: 0
        property real vy: 0
        property real anchorY: 0
        property real fadeY: 0
        property bool lands: false

        function show(d) {
            if (!d) {
                phase = "gone";
                return;
            }
            x = d.x;
            y = d.y;
            t = d.t;
            swell = d.swell;
            stretch = d.stretch;
            vy = d.vy;
            anchorY = d.anchorY;
            fadeY = root.fadeAt(d);
            lands = Venom.landing(d.x, d.y - 1, root.windows) !== null;
            phase = d.phase;
        }

        visible: phase !== "gone"

        readonly property bool hanging: phase === "bead" || phase === "thread" || phase === "fall"
        // The drop's radius, and how far it is drawn out along y.
        readonly property real r: Venom.BEAD_R * (phase === "bead" ? 0.4 + 0.6 * swell : phase === "thread" ? 1 : 0.88)
        readonly property real sag: phase === "bead" ? 0.78 + 0.22 * swell : phase === "thread" ? 1 + 0.3 * stretch : 1.12
        // Over empty desktop it fades in the last 80 px of its fall.
        readonly property real fading: phase === "fall" && !lands ? Math.min(Math.max((y - fadeY + 80) / 80, 0), 1) : 0
        readonly property real u: phase === "splash" ? t / Venom.SPLASH_FOR : phase === "fade" ? t / Venom.FADE_FOR : 0
        readonly property real burst: 1 - Math.pow(1 - Math.min(u, 1), 3)

        // The thread, necking thinner, from the fang to the bead's tip.
        Rectangle {
            visible: drop.phase === "thread"
            x: -width / 2
            y: drop.anchorY - drop.y
            width: 1.1 - 0.5 * drop.stretch
            height: Math.max(0, drop.y - drop.anchorY - 1.4 * drop.r * drop.sag)
            radius: width / 2
            color: U.Palette.venom
        }
        // After the snap, the thread's stub springs back up to the fang.
        Rectangle {
            visible: drop.phase === "fall" && drop.t < 0.15
            x: -0.5
            y: drop.anchorY - drop.y
            width: 1
            height: 4 * (1 - drop.t / 0.15)
            radius: 0.5
            color: U.Palette.venom
        }
        // The faint streak it leaves as it falls.
        Rectangle {
            visible: drop.phase === "fall"
            x: -1
            width: 2
            height: Math.min(3 + drop.vy * 0.022, 34)
            y: -height - drop.r
            radius: 1
            opacity: 1 - drop.fading
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(U.Palette.venom, 0) }
                GradientStop { position: 1; color: Qt.alpha(U.Palette.venom, 0.22) }
            }
        }

        // The glow: a baked radial falloff, scaled with the drop.
        Glow {
            visible: drop.hanging
            scale: drop.r / Venom.BEAD_R
            opacity: (drop.phase === "bead" ? 0.25 + 0.75 * drop.swell : 1) * (1 - drop.fading)
        }

        // The drop: a teardrop, its tip up, lit from the upper left.
        Shape {
            visible: drop.hanging
            opacity: 1 - drop.fading
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                xScale: drop.r / 4
                yScale: drop.r / 4 * drop.sag
            }
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: -1.2; centerY: -1; centerRadius: 6
                    focalX: -1.2; focalY: -1
                    GradientStop { position: 0; color: "#ffffff" }
                    GradientStop { position: 0.5; color: U.Palette.venom }
                    GradientStop { position: 1; color: U.Palette.viperKeel }
                }
                PathSvg { path: "M 0 -7.4 C 2.4 -3.8 4 -1.4 4 0.6 C 4 2.9 2.2 4 0 4 C -2.2 4 -4 2.9 -4 0.6 C -4 -1.4 -2.4 -3.8 0 -7.4 Z" }
            }
        }

        // The splash: a flash, a ring spreading on the window's top edge,
        // a pool in it, two specks thrown up and out, and a short trickle
        // down the window's face. Over empty desktop, only a faint ring.
        Glow {
            visible: drop.phase === "splash" && drop.u < 0.35
            scale: 1.3
            opacity: 1 - drop.u / 0.35
        }
        Shape {
            visible: drop.phase === "splash" || drop.phase === "fade"
            opacity: (drop.phase === "splash" ? 0.45 : 0.22) * (1 - drop.u)
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                xScale: 0.25 + 0.75 * drop.burst
                yScale: 0.25 + 0.75 * drop.burst
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: U.Palette.venom
                strokeWidth: 1
                PathSvg { path: "M -16 0 a 16 3.4 0 1 0 32 0 a 16 3.4 0 1 0 -32 0" }
            }
        }
        Shape {
            visible: drop.phase === "splash"
            opacity: 0.32 * (1 - drop.u)
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                xScale: 0.5 + 0.5 * drop.burst
                yScale: 0.5 + 0.5 * drop.burst
            }
            ShapePath {
                fillColor: U.Palette.venom
                strokeColor: "transparent"
                PathSvg { path: "M -6 0 a 6 1.4 0 1 0 12 0 a 6 1.4 0 1 0 -12 0" }
            }
        }
        Repeater {
            model: [[-1, 11, 10, 1.2], [1, 13, 12, 1]]
            Rectangle {
                required property var modelData
                readonly property real k: Math.min(drop.u / 0.7, 1)
                visible: drop.phase === "splash" && k < 1
                x: modelData[0] * (3 + modelData[1] * (1 - Math.pow(1 - k, 2))) - width / 2
                y: -modelData[2] * Math.sin(Math.PI * k) * (1 - 0.3 * k) - height / 2
                width: 2 * modelData[3]
                height: width
                radius: width / 2
                color: U.Palette.venom
                opacity: 0.65 * (1 - k)
            }
        }
        Rectangle {
            visible: drop.phase === "splash" && drop.u > 0.1
            x: 0.6
            y: 1
            width: 1.6
            height: 3 + 12 * root.ease((drop.u - 0.1) / 0.6)
            radius: 0.8
            opacity: 1 - root.ease((drop.u - 0.5) / 0.5)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(U.Palette.venom, 0.3) }
                GradientStop { position: 1; color: Qt.alpha(U.Palette.venom, 0) }
            }
        }
    }

    // The venom's glow round a centre at 0, 0: a soft radial falloff drawn
    // once (no blur effect), sized for a full bead.
    component Glow: Shape {
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 0; centerY: 0; centerRadius: 9
                focalX: 0; focalY: 0
                GradientStop { position: 0; color: Qt.alpha(U.Palette.venom, 0.42) }
                GradientStop { position: 0.45; color: Qt.alpha(U.Palette.venom, 0.16) }
                GradientStop { position: 1; color: Qt.alpha(U.Palette.venom, 0) }
            }
            PathSvg { path: "M -9 0 a 9 9 0 1 0 18 0 a 9 9 0 1 0 -18 0" }
        }
    }
}
