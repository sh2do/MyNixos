// A horned viper hanging head down from under the island (the "dripping
// viper" board, hang A), jaws open, venom dripping from its forward fang.
// Island.qml hosts it under the pill, 30 px right of centre so the spider
// still drops from the centre; this item fills the island's window.
//
// The body is a Serpent (GPU-bent) wearing HangingViperSkin; it comes out
// from behind the pill and falls in a slow S about 130 px long. Everything
// else is drawn once and moved by transforms: the head (side on, from the
// close study: hinged jaws lined with labial scales, the horn of three keeled
// scales on its brow ridge, slit-pupilled eye, heat pit, pale lining with the
// glottis and tongue sheath, two sabre fangs swung forward, and the forked
// tongue), the hiss puff and up to four venom drops (venom.js).
//
// Alive on one clock that runs only as fast as the motion needs (every
// repaint of the island's window costs CPU, whatever changes in it):
// - 10 Hz idle: a ±3° pendulum sway about the hang point (a rotation) and a
//   slow coil and uncoil;
// - 30 Hz while a bead swells, necks into its thread, splashes or fades, and
//   while the viper hisses, pulls up or lowers itself;
// - the display's rate only while a drop is in free fall, and through the
//   tongue's 250 ms flick (every 10-20 s while it hangs).
// UMBRIEL_SERPENT_FPS caps all three. Only the coil re-bends the body, and
// only while it changes: at most 10 times a second, 30 while it pulls up or
// lowers itself (it straightens as it goes). Nothing runs while it is pulled
// up, the island is hidden, the session is locked or the screen is off.
//
// The drip follows the CPU load (/proc/stat every 2 s, and afresh on each
// return): a drop every 4 s when calm, every 0.6 s at full load. Drops land
// on the top edge of the highest window below them (UmbrielIpc.windows), or
// fade out 300 px down; over a window's content they only sag and fade.
//
// At night (U.Palette.night) it coils up shorter, hanging about 30% higher,
// sways at half speed, drips half as often, and its eye dims (venom.js
// nightHang). It follows the palette's 2 s night steps smoothly on its own
// clock, so night adds no ticks.
//
// In focus mode, or while a game runs (Focus.qml `calm`), it hangs still: no drip, no flick, and once it
// hangs its clock stops (it still pulls up and comes down as above).
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
        onTriggered: {
            if (root.cause)
                return;
            root.mode = "down";
            // The last sample is from before it went away: read the load
            // afresh, over the next half second.
            life.sample = null;
            stat.reload();
            reread.restart();
        }
    }
    Timer {
        id: reread
        interval: 500
        onTriggered: stat.reload()
    }

    // The clock

    readonly property int fpsCap: parseInt(Quickshell.env("UMBRIEL_SERPENT_FPS") || "") || 0
    readonly property bool running: island.visible && !locked && !Cover.outputOff(UmbrielIpc.outputs, island.screen?.name ?? "")
    // Focus mode or a game: hanging, it stops; drops and a flick under way are cleared.
    readonly property bool still: U.Focus.calm
    onStillChanged: if (still) {
        clearDrops(false);
        flicking = false;
        tongue = 0;
    }
    readonly property bool active: running && (mode !== "away" || dropCount > 0) && !(still && mode === "out")
    onRunningChanged: if (!running) clearDrops(false)

    // Set by each tick: a drop in free fall, any other drop alive, how many.
    property bool falling: false
    property bool dripping: false
    property int dropCount: 0
    // The tongue's flick is under way; how far out it is, 0..1. The display's
    // rate runs for it as for a falling drop.
    property bool flicking: false
    property real tongue: 0
    readonly property bool fast: falling || flicking
    readonly property bool moving: mode === "hiss" || mode === "up" || mode === "down"
    readonly property int idleHz: 10
    readonly property int busyHz: 30

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
        property real nextFlick: 0
        property real flickAt: 0
        property var drops: [null, null, null, null]
        property var sample: null
        // The sway's own time, which runs slower at night.
        property real swayT: 0
    }

    // The viper's night, 0..1: eased toward the palette's on each tick.
    property real hush: U.Palette.night
    readonly property var hang: Venom.nightHang(hush)

    property real load: 0
    readonly property int interval: Venom.dripInterval(load, hush)

    function ease(u) {
        const t = Math.min(Math.max(u, 0), 1);
        return t * t * (3 - 2 * t);
    }

    // `c` at `e` of its brightness.
    function dimmed(c, e) {
        return Qt.rgba(c.r * e, c.g * e, c.b * e, c.a);
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
                life.nextFlick = t + 3 + Math.random() * 10;
            }
        }

        if (hush !== U.Palette.night)
            hush = Venom.toward(hush, U.Palette.night, dt);

        // A pendulum with a slow drift in its swing, and the coil.
        life.swayT += dt * hang.rate;
        const st = life.swayT;
        sway = 3 * Math.sin(2 * Math.PI * st / 5.5) * (0.82 + 0.18 * Math.sin(2 * Math.PI * st / 17));
        coil = 0.5 - 0.5 * Math.cos(2 * Math.PI * t / 14);

        // Straight while pulled up, so it slides into the island cleanly.
        const bend = ease(out) * (0.38 + 0.27 * coil);
        life.bendAcc += dt;
        const bendHz = mode === "up" || mode === "down" ? root.busyHz : root.idleHz;
        if (Math.abs(bend - life.bent) > 0.0015 && life.bendAcc >= 1 / bendHz - 0.001)
            bendBody(bend);

        // The tongue: out and back in 250 ms, every 10-20 s while it hangs.
        if (!flicking && !still && mode === "out" && t >= life.nextFlick) {
            flicking = true;
            life.flickAt = t;
        }
        if (flicking) {
            const u = (t - life.flickAt) / 0.25;
            if (u >= 1 || mode !== "out") {
                flicking = false;
                tongue = 0;
                life.nextFlick = t + 10 + Math.random() * 10;
            } else {
                tongue = Math.min(1, 1.3 * Math.sin(Math.PI * u));
            }
        }

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

    // A little narrower at the neck, as deep as the head's back there; full
    // width from there up.
    readonly property var widths: {
        const ws = new Array(Spine.SPINE_POINTS);
        for (let k = 0; k < ws.length; k++)
            ws[k] = 0.82 + 0.18 * ease(k / (ws.length - 1) / 0.2);
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
        let onFang = false, fallNow = false, dripNow = false, count = 0;
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
            fallNow = fallNow || d.phase === "fall";
            dripNow = dripNow || d.phase !== "fall";
        }
        if (mode === "out" && !still && !onFang && life.t >= life.nextDrop) {
            const free = ds.indexOf(null);
            if (free >= 0) {
                ds[free] = Venom.newDrop(tip.x, tip.y, Venom.beadTime(root.interval));
                life.nextDrop = life.t + root.interval / 1000;
                count++;
                dripNow = true;
            }
        }
        for (let i = 0; i < ds.length; i++)
            dropItems.itemAt(i).show(ds[i]);
        falling = fallNow;
        dripping = dripNow;
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
        if (!count) {
            falling = false;
            dripping = false;
        }
    }

    FrameAnimation {
        running: root.active && root.fast && root.fpsCap <= 0
        onTriggered: root.tick(Spine.step(frameTime))
    }
    Timer {
        readonly property int hz: {
            const want = root.fast ? 1000 : root.dripping || root.moving ? root.busyHz : root.idleHz;
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
            // At night it hangs `hang.lift` of its length higher.
            y: -root.clipTop - (1 - root.ease(root.out)) * (root.hangY + root.bodyLength - root.clipTop + 50)
                - root.ease(root.out) * root.hang.lift * (root.hangY + root.bodyLength - root.clipTop)
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
                    // Gone before it reaches the pill, so it never shows
                    // beside it; it fades back in as it comes down.
                    opacity: Math.min(Math.max((root.out - 0.3) / 0.3, 0), 1)
                    hiss: root.hiss
                    tongue: root.tongue
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

    // The head, side on, as on the detail sheet: drawn in the sheet's own
    // coordinates and scaled to real size (×0.25, about 45 px long). The
    // origin is the neck joint, (70, 106) on the sheet; the snout points +x,
    // the crown -y. A long wedge, its jaws hinged parts: the upper tilted up
    // 28° (a little more in a hiss), the lower dropped 16°. The open mouth
    // shows its broad pale lining; the two long sabre fangs swing forward
    // from their roots on the upper jaw, and the venom beads on the forward
    // one's tip. A pale slate rim keeps the head off a dark wallpaper, and
    // its jowls overlap the end of the body, so there is no seam.
    readonly property real headScale: 0.25
    readonly property point upperHinge: Qt.point(70, 84)
    readonly property point fangAt: Qt.point(228, 146)

    component Lines: ShapePath {
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    component Head: Item {
        id: hd

        property real hiss: 0
        // The tongue, 0 in its sheath .. 1 flicked right out.
        property real tongue: 0
        readonly property string tonguePath: "M 185 111.5 C 210 111 236 113 256 112 L 278 101 M 256 112 L 277 121"
        readonly property real upper: -28 - 8 * Math.sin(Math.PI * hiss)
        readonly property Item fang: fangTip

        readonly property string upperPath: "M 58 52 C 108 38 188 44 230 68 Q 248 80 236 90 L 70 97 C 62 90 58 72 58 52 Z"
        readonly property string lowerPath: "M 68 99 L 222 110 Q 232 116 220 123 C 172 132 110 130 68 127 C 62 118 62 106 68 99 Z"

        // The labial scales: a row of rounded plates along a lip, from
        // (x0, y0) to (x1, y1), `depth` deep, bulging away from the mouth
        // (side -1 up, 1 down).
        function labials(x0, y0, x1, y1, n, depth, side) {
            const f = v => v.toFixed(1);
            const dx = (x1 - x0) / n, dy = (y1 - y0) / n;
            let d = `M ${f(x0)} ${f(y0)} L ${f(x1)} ${f(y1)} L ${f(x1)} ${f(y1 + side * depth * 0.55)} `;
            for (let i = n; i > 0; i--) {
                const xa = x0 + dx * i, ya = y0 + dy * i;
                d += `Q ${f(xa - dx / 2)} ${f(ya - dy / 2 + side * depth * 1.35)} ${f(xa - dx)} ${f(ya - dy + side * depth * 0.55)} `;
            }
            return d + "Z";
        }
        // The keeled scales over the crown and cheek: staggered almonds,
        // each with a pale ridge, between the crown's edge and the labials,
        // clear of the eye and the pit.
        readonly property var crownScales: {
            const f = v => v.toFixed(1);
            const top = x => 50 + 0.0011 * Math.pow(x - 120, 2) + (x > 150 ? (x - 150) * 0.12 : 0);
            const lip = x => 96.4 - (x - 74) * 0.0377;
            let scales = "", keels = "";
            const sw = 13, sh = 7.5;
            for (let r = 0, y = 54; y < 92; r++, y += sh) {
                for (let x = 64 + (r % 2) * sw / 2; x < 232; x += sw) {
                    const cx = x + sw / 2;
                    if (y < top(cx) + 4 || y > lip(cx) - 11 || Math.hypot(cx - 160, y - 66) < 15 || Math.hypot(cx - 205, y - 80) < 9 || Math.hypot(cx - 228, y - 77) < 8)
                        continue;
                    scales += `M ${f(x)} ${f(y)} Q ${f(cx)} ${f(y - sh * 0.62)} ${f(x + sw)} ${f(y)} Q ${f(cx)} ${f(y + sh * 0.62)} ${f(x)} ${f(y)} `;
                    keels += `M ${f(x + 3)} ${f(y)} L ${f(x + sw - 3)} ${f(y)} `;
                }
            }
            return { scales: scales, keels: keels };
        }
        readonly property string upperLabials: labials(74, 96.4, 228, 90.6, 10, 7.5, -1)
        readonly property string lowerLabials: labials(72, 113.2, 210, 118, 9, 6.5, 1)

        // A soft shadow on the desktop, at the body's offset.
        Shape {
            x: 2
            y: 4
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 18; centerY: 0; centerRadius: 24
                    focalX: 18; focalY: 0
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.42) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
                }
                PathSvg { path: "M -6 0 a 24 13 0 1 0 48 0 a 24 13 0 1 0 -48 0" }
            }
        }

        Item {
            transform: [
                Translate { x: -70; y: -106 },
                Scale { xScale: root.headScale; yScale: root.headScale }
            ]

            // The jowls, over the end of the body, shaded round like it.
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0; y1: 80; x2: 0; y2: 132
                        GradientStop { position: 0; color: Qt.darker(U.Palette.viperBody, 1.7) }
                        GradientStop { position: 0.45; color: U.Palette.viperBody }
                        GradientStop { position: 1; color: Qt.darker(U.Palette.viperBody, 1.7) }
                    }
                    PathSvg { path: "M 56 106 C 56 90 64 82 78 82 C 92 82 98 94 98 106 C 98 120 92 130 78 130 C 64 130 56 122 56 106 Z" }
                }
            }

            // The throat, deep in the gape: dim slate, so the open mouth
            // still reads on a dark wallpaper.
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: Qt.darker(U.Palette.slate, 1.35)
                    strokeColor: "transparent"
                    PathSvg { path: "M 64 100 L 156 62 Q 176 104 152 140 Z" }
                }
            }

            // Lower jaw, dropped: pale rim, lip scales, the broad lining
            // along its top with small teeth.
            Shape {
                preferredRendererType: Shape.CurveRenderer
                transform: Rotation { origin.x: 70; origin.y: 100; angle: 16 }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.85)
                    strokeWidth: 15
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: hd.lowerPath }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(U.Palette.viperKeel, 0.5)
                    strokeWidth: 8
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: hd.lowerPath }
                }
                ShapePath {
                    fillColor: Qt.darker(U.Palette.viperBody, 1.2)
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 3.5
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: hd.lowerPath }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperKeel, 0.8)
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 1.4
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: hd.lowerLabials }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperEye, 0.85)
                    strokeColor: "transparent"
                    PathSvg { path: "M 70 101 L 220 110 L 211 118 C 160 117 112 115 70 113 Z" }
                }
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperKeel, 0.9)
                    strokeWidth: 0.9
                    PathSvg { path: "M 84 104 Q 150 106 206 111 M 92 108 Q 150 110 198 114" }
                }
                // The glottis on the mouth's floor, and the tongue's sheath
                // in front of it.
                ShapePath {
                    fillColor: U.Palette.viperKeel
                    strokeColor: Qt.darker(U.Palette.viperKeel, 1.5)
                    strokeWidth: 1
                    PathSvg { path: "M 112 107.5 Q 142 103.5 170 109 Q 142 112.5 112 110.5 Z" }
                }
                Lines {
                    strokeColor: Qt.darker(U.Palette.viperKeel, 1.5)
                    strokeWidth: 0.8
                    PathSvg { path: "M 120 109 L 164 109.4" }
                }
                ShapePath {
                    fillColor: Qt.lighter(U.Palette.viperKeel, 1.25)
                    strokeColor: Qt.darker(U.Palette.viperKeel, 1.5)
                    strokeWidth: 1
                    PathSvg { path: "M 177 111.5 a 8 3.4 0 1 0 16 0 a 8 3.4 0 1 0 -16 0" }
                }
                Lines {
                    strokeColor: U.Palette.viperBlotch
                    strokeWidth: 1.6
                    PathSvg { path: "M 180 111.5 L 190 111.5" }
                }
                ShapePath {
                    fillColor: U.Palette.bright
                    strokeColor: "transparent"
                    PathSvg { path: "M 104 104 l 3 -7 l 3 7 Z M 132 106 l 3 -7 l 3 7 Z M 160 107 l 3 -6 l 3 6 Z M 200 109.5 l 2.5 -6 l 2.5 6 Z" }
                }
            }

            // The forked tongue, flicked out of its sheath every 10-20 s: drawn
            // once, along the dropped lower jaw, and only stretched out.
            Shape {
                visible: hd.tongue > 0
                preferredRendererType: Shape.CurveRenderer
                transform: [
                    Scale { origin.x: 185; origin.y: 111.5; xScale: hd.tongue; yScale: 0.4 + 0.6 * hd.tongue },
                    Rotation { origin.x: 70; origin.y: 100; angle: 16 }
                ]
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperKeel, 0.5)
                    strokeWidth: 7.5
                    PathSvg { path: hd.tonguePath }
                }
                Lines {
                    strokeColor: U.Palette.viperBlotch
                    strokeWidth: 4.5
                    PathSvg { path: hd.tonguePath }
                }
            }

            // Upper jaw, tilted up.
            Shape {
                preferredRendererType: Shape.CurveRenderer
                transform: Rotation { origin.x: root.upperHinge.x; origin.y: root.upperHinge.y; angle: hd.upper }
                // The pale slate rim, then the head, rounded by a gradient
                // from the crown to the lip.
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.85)
                    strokeWidth: 16
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: hd.upperPath }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(U.Palette.viperKeel, 0.55)
                    strokeWidth: 9
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: hd.upperPath }
                }
                ShapePath {
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 3.5
                    joinStyle: ShapePath.RoundJoin
                    fillGradient: LinearGradient {
                        x1: 0; y1: 44; x2: 0; y2: 97
                        GradientStop { position: 0; color: Qt.lighter(U.Palette.viperBody, 1.18) }
                        GradientStop { position: 0.55; color: U.Palette.viperBody }
                        GradientStop { position: 1; color: Qt.darker(U.Palette.viperBody, 1.3) }
                    }
                    PathSvg { path: hd.upperPath }
                }
                // The broad pale lining of the roof of the mouth.
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperEye, 0.82)
                    strokeColor: "transparent"
                    PathSvg { path: "M 236 90 L 70 97 L 72 111 C 120 109 190 103 230 96 Z" }
                }
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.35)
                    strokeWidth: 1.5
                    PathSvg { path: "M 90 104 C 140 101 190 98 226 94" }
                }
                // A highlight along the crown.
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperKeel, 0.45)
                    strokeWidth: 2.5
                    PathSvg { path: "M 74 55 C 114 45 182 49 222 71" }
                }
                // The dark stripe from the eye back to the jaw's corner, and
                // blotches on the crown.
                Lines {
                    strokeColor: U.Palette.viperBlotch
                    strokeWidth: 9
                    PathSvg { path: "M 150 74 C 128 80 104 86 80 91" }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperBlotch, 0.85)
                    strokeColor: "transparent"
                    PathSvg { path: "M 84 56 C 96 50 116 49 122 55 C 116 64 96 64 84 60 Z M 186 56 C 194 54 204 56 208 61 C 202 65 192 64 186 60 Z" }
                }
                // The keeled scales, then the labials along the lip.
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperKeel, 0.1)
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.55)
                    strokeWidth: 0.9
                    PathSvg { path: hd.crownScales.scales }
                }
                Lines {
                    strokeColor: Qt.alpha(Qt.lighter(U.Palette.viperKeel, 1.2), 0.7)
                    strokeWidth: 1.1
                    PathSvg { path: hd.crownScales.keels }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperKeel, 0.8)
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 1.4
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: hd.upperLabials }
                }
                // The heat pit between eye and nostril, rimmed.
                ShapePath {
                    fillColor: U.Palette.viperOutline
                    strokeColor: Qt.alpha(U.Palette.viperKeel, 0.9)
                    strokeWidth: 1.3
                    PathSvg { path: "M 199.5 80 a 5.5 4.2 0 1 0 11 0 a 5.5 4.2 0 1 0 -11 0" }
                }
                ShapePath {
                    fillColor: U.Palette.viperBlotch
                    strokeColor: "transparent"
                    PathSvg { path: "M 203 80.4 a 2.6 1.9 0 1 0 5.2 0 a 2.6 1.9 0 1 0 -5.2 0" }
                }
                // The nostril, in its rimmed scale.
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.8)
                    strokeWidth: 1
                    PathSvg { path: "M 222 77 a 6.4 5.4 0 1 0 12.8 0 a 6.4 5.4 0 1 0 -12.8 0" }
                }
                ShapePath {
                    fillColor: U.Palette.viperOutline
                    strokeColor: "transparent"
                    PathSvg { path: "M 225 77 a 3.4 2.6 0 1 0 6.8 0 a 3.4 2.6 0 1 0 -6.8 0" }
                }
                // The brow ridge overhanging the eye, and on it the
                // supraocular horn: three stacked keeled scales leaning
                // back, the middle one tallest, each with a pale ridge.
                Lines {
                    strokeColor: Qt.darker(U.Palette.viperBody, 1.1)
                    strokeWidth: 7
                    PathSvg { path: "M 138 58 Q 160 49 182 58" }
                }
                Lines {
                    strokeColor: Qt.alpha(Qt.lighter(U.Palette.viperKeel, 1.2), 0.7)
                    strokeWidth: 1.6
                    PathSvg { path: "M 139 54.5 Q 160 45.5 181 54.5" }
                }
                ShapePath {
                    fillColor: Qt.darker(U.Palette.viperKeel, 1.15)
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 2.5
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 128 54 C 129 45 129 36 127 26 C 135 34 141 43 146 52 Z M 160 52 C 162 44 162 37 161 28 C 168 35 173 43 177 51 Z" }
                }
                ShapePath {
                    fillColor: Qt.lighter(U.Palette.viperKeel, 1.12)
                    strokeColor: U.Palette.viperOutline
                    strokeWidth: 3
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 143 54 C 145 40 145 24 143 4 C 154 18 163 34 170 52 Z" }
                }
                Lines {
                    strokeColor: Qt.alpha(Qt.lighter(U.Palette.viperEye, 1.08), 0.85)
                    strokeWidth: 1.2
                    PathSvg { path: "M 131 49 L 129.5 32 M 147 50 L 146 12 M 164 48 L 163.5 33" }
                }
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.55)
                    strokeWidth: 1.4
                    PathSvg { path: "M 148 42 l 13 -1 M 147 31 l 8 -1 M 146 20 l 4 0 M 130 42 l 7 -1 M 162 42 l 6 -1" }
                }
                // The eye: dark ring, a pale iris shading to slate at its
                // edge and finely streaked, the slit pupil, the brow's
                // shadow across its top, and two catch-lights.
                ShapePath {
                    fillColor: U.Palette.viperOutline
                    strokeColor: "transparent"
                    PathSvg { path: "M 148 66 a 12 12 0 1 0 24 0 a 12 12 0 1 0 -24 0" }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: 160; centerY: 66; centerRadius: 9.5
                        focalX: 160; focalY: 66
                        GradientStop { position: 0.3; color: root.dimmed(Qt.lighter(U.Palette.viperEye, 1.06), root.hang.eye) }
                        GradientStop { position: 0.85; color: root.dimmed(U.Palette.viperKeel, root.hang.eye) }
                        GradientStop { position: 1; color: root.dimmed(Qt.darker(U.Palette.viperKeel, 1.5), root.hang.eye) }
                    }
                    PathSvg { path: "M 150.5 66 a 9.5 9.5 0 1 0 19 0 a 9.5 9.5 0 1 0 -19 0" }
                }
                Lines {
                    strokeColor: Qt.alpha(Qt.darker(U.Palette.viperKeel, 1.1), 0.9)
                    strokeWidth: 0.8
                    PathSvg { path: "M 153 60 L 156 62.5 M 167 60 L 164 62.5 M 152 70.5 L 155.5 69.5 M 168 71 L 164.5 69.5 M 160 57.5 L 160 60 M 160 74.5 L 160 72" }
                }
                ShapePath {
                    fillColor: "#050608"
                    strokeColor: "transparent"
                    PathSvg { path: "M 160 57 C 162.8 61.5 162.8 70.5 160 75 C 157.2 70.5 157.2 61.5 160 57 Z" }
                }
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.7)
                    strokeWidth: 3
                    PathSvg { path: "M 150 59 Q 160 53.5 170 59" }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.bright, root.hang.eye)
                    strokeColor: "transparent"
                    PathSvg { path: "M 153.4 61.6 a 2.3 2.3 0 1 0 4.6 0 a 2.3 2.3 0 1 0 -4.6 0" }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.bright, 0.5 * root.hang.eye)
                    strokeColor: "transparent"
                    PathSvg { path: "M 163.6 70.6 a 1 1 0 1 0 2 0 a 1 1 0 1 0 -2 0" }
                }
                // The fangs: long curved sabres swung forward, opaque at
                // the root and clearing to a translucent tip, the forward
                // one with its venom groove; then the pale fleshy sheath
                // folded over their roots.
                ShapePath {
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.6)
                    strokeWidth: 2.2
                    joinStyle: ShapePath.RoundJoin
                    fillGradient: LinearGradient {
                        x1: 190; y1: 94; x2: 220; y2: 146
                        GradientStop { position: 0; color: U.Palette.bright }
                        GradientStop { position: 0.55; color: Qt.alpha(U.Palette.bright, 0.95) }
                        GradientStop { position: 1; color: Qt.alpha(U.Palette.viperEye, 0.3) }
                    }
                    PathSvg { path: "M 183 95 L 196 94 C 202 105 206 121 203 140 C 198 123 192 110 183 100 Z M 203 93 L 218 92 C 225 105 230 124 228 146 C 222 128 214 112 203 98 Z" }
                }
                Lines {
                    strokeColor: Qt.alpha(U.Palette.viperKeel, 0.95)
                    strokeWidth: 1.1
                    PathSvg { path: "M 210 97 C 217 108 223 122 226 138" }
                }
                ShapePath {
                    fillColor: Qt.alpha(U.Palette.viperKeel, 0.9)
                    strokeColor: Qt.alpha(U.Palette.viperOutline, 0.5)
                    strokeWidth: 1.2
                    PathSvg { path: "M 180 95 Q 190 108 200 94.5 Q 210 108 223 92 Z" }
                }
            }
        }

        // The forward fang's tip, where the venom beads, after the tilt.
        Item {
            id: fangTip
            readonly property real a: hd.upper * Math.PI / 180
            readonly property real dx: root.fangAt.x - root.upperHinge.x
            readonly property real dy: root.fangAt.y - root.upperHinge.y
            x: root.headScale * (root.upperHinge.x + dx * Math.cos(a) - dy * Math.sin(a) - 70)
            y: root.headScale * (root.upperHinge.y + dx * Math.sin(a) + dy * Math.cos(a) - 106)
        }

        // The hiss: two pale arcs puffing out of the open mouth.
        Shape {
            visible: hd.hiss > 0
            x: 38
            y: 0
            opacity: 0.6 * Math.sin(Math.PI * hd.hiss)
            scale: 0.7 + 0.8 * hd.hiss
            transformOrigin: Item.Left
            preferredRendererType: Shape.CurveRenderer
            Lines {
                strokeColor: U.Palette.bright
                strokeWidth: 1.1
                PathSvg { path: "M 3 -6 Q 8 0 3 6 M 9 -10 Q 16 0 9 10" }
            }
        }
    }

    // One drop of venom, centred on its x, y. Moved and shaped only by
    // transforms and opacity; show(d) copies a venom.js drop in. Every part
    // has a thin dark edge or under-shadow, so the bright venom reads on a
    // pale wallpaper as well as a dark one.
    component Drop: Item {
        id: drop

        property string phase: "gone"
        property real t: 0
        property real swell: 0
        property real stretch: 0
        property real vy: 0
        property real anchorY: 0
        property real y0: 0
        property real fadeY: 0
        property bool lands: false
        property bool blocked: false

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
            y0 = d.y0;
            blocked = d.blocked;
            fadeY = root.fadeAt(d);
            lands = Venom.landing(d.x, d.y - 1, root.windows) !== null;
            phase = d.phase;
        }

        visible: phase !== "gone"

        readonly property bool hanging: phase === "bead" || phase === "thread" || phase === "fall"
        // The drop's radius, and how far it is drawn out along y.
        readonly property real r: Venom.BEAD_R * (phase === "bead" ? 0.4 + 0.6 * swell : phase === "thread" ? 1 : 0.88)
        readonly property real sag: phase === "bead" ? 0.78 + 0.22 * swell : phase === "thread" ? 1 + 0.3 * stretch : 1.12
        // Over empty desktop it fades in the last 80 px of its fall; over a
        // window's content, through its short sag.
        readonly property real fading: phase !== "fall" ? 0
            : blocked ? Math.min(Math.max((y - y0) / Venom.BLOCKED_FALL, 0), 1)
            : !lands ? Math.min(Math.max((y - fadeY + 80) / 80, 0), 1) : 0
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
            border.width: 0.3
            border.color: Qt.alpha(U.Palette.viperOutline, 0.4)
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
            visible: drop.phase === "fall" && !drop.blocked
            x: -1
            width: 2
            height: Math.min(3 + drop.vy * 0.022, 34)
            y: -height - drop.r
            radius: 1
            opacity: 1 - drop.fading
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(U.Palette.venom, 0) }
                GradientStop { position: 1; color: Qt.alpha(U.Palette.venom, 0.3) }
            }
        }

        // The glow.
        Glow {
            visible: drop.hanging
            scale: drop.r / Venom.BEAD_R
            opacity: (drop.phase === "bead" ? 0.25 + 0.75 * drop.swell : 1) * (1 - drop.fading)
        }

        // The drop: a teardrop, its tip up, lit from the upper left, over a
        // dark under-shadow, with a thin slate rim; inside, a highlight, the
        // dark band light refracts into near its foot, and a bright lip.
        Shape {
            visible: drop.hanging
            opacity: 1 - drop.fading
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                xScale: drop.r / 4
                yScale: drop.r / 4 * drop.sag
            }
            ShapePath {
                fillColor: Qt.alpha(U.Palette.viperOutline, 0.4)
                strokeColor: "transparent"
                PathSvg { path: "M 0.9 -6.2 C 3.3 -2.6 4.9 -0.2 4.9 1.8 C 4.9 4.1 3.1 5.2 0.9 5.2 C -1.3 5.2 -3.1 4.1 -3.1 1.8 C -3.1 -0.2 -1.5 -2.6 0.9 -6.2 Z" }
            }
            ShapePath {
                strokeColor: U.Palette.viperBody
                strokeWidth: 0.6
                fillGradient: RadialGradient {
                    centerX: -1.2; centerY: -1; centerRadius: 6
                    focalX: -1.2; focalY: -1
                    GradientStop { position: 0; color: "#ffffff" }
                    GradientStop { position: 0.5; color: U.Palette.venom }
                    GradientStop { position: 1; color: U.Palette.viperKeel }
                }
                PathSvg { path: "M 0 -7.4 C 2.4 -3.8 4 -1.4 4 0.6 C 4 2.9 2.2 4 0 4 C -2.2 4 -4 2.9 -4 0.6 C -4 -1.4 -2.4 -3.8 0 -7.4 Z" }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(U.Palette.viperBody, 0.75)
                strokeWidth: 0.55
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M -2.9 1.5 Q 0 3.3 2.9 1.5" }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha("#ffffff", 0.8)
                strokeWidth: 0.4
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M -2 3.1 Q 0 4 2 3.1" }
            }
            ShapePath {
                fillColor: "#ffffff"
                strokeColor: "transparent"
                PathSvg { path: "M -2.2 -0.8 a 0.75 1.25 0 1 0 1.5 0 a 0.75 1.25 0 1 0 -1.5 0" }
            }
        }

        // The splash: a flash, a ring spreading on the window's top edge,
        // a pool in it, two specks thrown up and out, and a short trickle
        // down the window's face. Elsewhere only a faint ring: a tiny one
        // over a window's content.
        Glow {
            visible: drop.phase === "splash" && drop.u < 0.35
            scale: 1.3
            opacity: 1 - drop.u / 0.35
        }
        Shape {
            id: ring
            visible: drop.phase === "splash" || drop.phase === "fade"
            opacity: (drop.phase === "splash" ? 0.9 : 0.5) * (1 - drop.u)
            preferredRendererType: Shape.CurveRenderer
            readonly property real k: (drop.phase === "fade" && drop.blocked ? 0.3 : 1) * (0.25 + 0.75 * drop.burst)
            transform: Scale {
                xScale: ring.k
                yScale: ring.k
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(U.Palette.viperOutline, 0.5)
                strokeWidth: 1.6
                PathSvg { path: "M -16 0.9 a 16 3.4 0 1 0 32 0 a 16 3.4 0 1 0 -32 0" }
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
            opacity: 0.55 * (1 - drop.u)
            preferredRendererType: Shape.CurveRenderer
            transform: Scale {
                xScale: 0.5 + 0.5 * drop.burst
                yScale: 0.5 + 0.5 * drop.burst
            }
            ShapePath {
                fillColor: U.Palette.venom
                strokeColor: Qt.alpha(U.Palette.viperOutline, 0.45)
                strokeWidth: 0.6
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
                width: 2 * modelData[3] + 0.8
                height: width
                radius: width / 2
                color: U.Palette.venom
                border.width: 0.5
                border.color: Qt.alpha(U.Palette.viperOutline, 0.55)
                opacity: 0.95 * (1 - k)
            }
        }
        Rectangle {
            visible: drop.phase === "splash" && drop.u > 0.1
            x: 0.3
            y: 1
            width: 2.2
            height: 3 + 12 * root.ease((drop.u - 0.1) / 0.6)
            radius: 1.1
            opacity: 1 - root.ease((drop.u - 0.5) / 0.5)
            border.width: 0.5
            border.color: Qt.alpha(U.Palette.viperOutline, 0.35)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(U.Palette.venom, 0.7) }
                GradientStop { position: 1; color: Qt.alpha(U.Palette.venom, 0.05) }
            }
        }
    }

    // The venom's glow round a centre at 0, 0, sized for a full bead: a
    // pre-blurred image (a soft radial falloff, rasterised once), so nothing
    // blurs at run time.
    readonly property string glowSource: {
        const c = U.Palette.venom.toString();
        const svg = "<svg xmlns='http://www.w3.org/2000/svg' width='36' height='36'><defs><radialGradient id='g' cx='0.5' cy='0.5' r='0.5'>"
            + `<stop offset='0' stop-color='${c}' stop-opacity='0.42'/><stop offset='0.45' stop-color='${c}' stop-opacity='0.16'/><stop offset='1' stop-color='${c}' stop-opacity='0'/>`
            + "</radialGradient></defs><rect width='36' height='36' fill='url(#g)'/></svg>";
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }
    component Glow: Image {
        x: -9
        y: -9
        width: 18
        height: 18
        sourceSize: Qt.size(36, 36)
        source: root.glowSource
        smooth: true
    }
}
