// Bottom-right corner: a reticulated python in three flat coils piled over
// the status row (StatusRow.qml, hosted here between the coils' far and near
// halves), its head raised beside the top coil, watching the screen.
//
// The pose (python-pose.js) is computed once per size: eight Serpent bodies,
// all wearing their own stretch of one skin strip (PythonSkin.qml), drawn far
// halves first, then the row, then the near halves, the neck and the head
// (PythonHead.qml). The skin runs on unbroken from head to tail; the bodies'
// shader lights whichever flank is on top on screen.
//
// Always alive, on one clock, which stops while hidden, locked or with the
// screen off. It runs at the display's rate only while something moves fast,
// and slower otherwise (see `idleHz`); UMBRIEL_SERPENT_FPS caps it.
// - breath: each coil swells about 2 px about its own centre every 5 s, as
//   a transform, so nothing is rebuilt for it;
// - muscle ripples along the body (shader uniforms), with a stronger wave
//   every 6-10 s;
// - a tongue flick every 8-15 s, a drift of the gaze every 10-20 s.
// Only the neck re-bends (at most 30 times a second, and not at all while the
// head is still); the head follows it by transform.
//
// Task 4 drives: lookAt(p) and strikeAt(p, onHit) (p in this window's
// coordinates), night, dilation, jaw, dull and bulges ([{u, size}], u along
// the body from the head).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Shapes
import "python-pose.js" as Pose
import "serpent-spine.js" as Spine
import "wall-cover.js" as Cover

PanelWindow {
    id: root

    property bool night: false
    property real dilation: 0
    property real jaw: 0
    property real dull: 0
    property var bulges: []

    function lookAt(p) {
        const h = root.headAt;
        if (!h)
            return;
        const rest = Pose.headPose(Pose.neckEnd(root.pose.neck), 0, 0).angle;
        const lift = Math.min(Math.max((h.y - p.y) / 300, 0), 1) * 0.7;
        let diff = Math.atan2(p.y - h.y, p.x - h.x) * 180 / Math.PI - rest - 12 * lift;
        diff = ((diff + 540) % 360) - 180;
        root.turnTo(Math.min(Math.max(diff / 22, -1.6), 1.6), lift, 0.5);
        life.holdUntil = life.t + 5;
    }

    // Lunge so the snout lands on p, call onHit there, then recoil.
    function strikeAt(p, onHit) {
        const r = root.pose.neck[0];
        let dx = p.x - r.x, dy = p.y - r.y;
        const d = Math.hypot(dx, dy) || 1;
        // The joint stops a head's length short of p, and the neck only
        // reaches so far.
        const reach = Math.min(Math.max(d - 40, 0), 150);
        life.strike = { joint: { x: r.x + dx / d * reach, y: r.y + dy / d * reach }, at: life.raw, k: 0, hit: false, onHit: onHit };
    }

    visible: !UmbrielIpc.fullscreen

    anchors {
        bottom: true
        right: true
    }
    implicitWidth: 340
    implicitHeight: 230
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "umbriel-python"

    // Click-through except for the coils and the head; never the status row
    // (it has no handlers).
    mask: Region {
        Region {
            shape: RegionShape.Ellipse
            readonly property var r: root.pose.rings[0]
            x: r.cx - r.rx - 12; y: r.cy - r.ry - 12
            width: 2 * (r.rx + 12); height: 2 * (r.ry + 12)
        }
        Region {
            shape: RegionShape.Ellipse
            readonly property var r: root.pose.rings[1]
            x: r.cx - r.rx - 12; y: r.cy - r.ry - 12
            width: 2 * (r.rx + 12); height: 2 * (r.ry + 12)
        }
        Region {
            shape: RegionShape.Ellipse
            readonly property var r: root.pose.rings[2]
            x: r.cx - r.rx - 12; y: r.cy - r.ry - 12
            width: 2 * (r.rx + 12); height: 2 * (r.ry + 12)
        }
        // The tail's curl.
        Region {
            readonly property var t: root.pose.tail
            x: t[0].x - 14; y: t[t.length - 1].y
            width: t[t.length - 1].x - t[0].x + 28; height: t[1].y - t[t.length - 1].y + 14
        }
        // Where the head rests and lifts.
        Region {
            readonly property var j: root.pose.neck[root.pose.neck.length - 1]
            x: j.x - 52; y: j.y - 50
            width: 64; height: 68
        }
        Region {
            item: status
            intersection: Intersection.Subtract
        }
    }

    // The pose

    readonly property real bodyWidth: Pose.BODY_WIDTH
    // The row's glyphs in window coordinates, the width rounded up to 8 px so
    // the battery's digits don't reshape the coils.
    // Kept as plain numbers so the pose is only rebuilt when one changes.
    readonly property int boxW: Math.ceil((status.glyphs.width + 2) / 8) * 8
    readonly property int boxH: Math.ceil(status.glyphs.height + 2)
    readonly property int boxRight: Math.round(status.x + status.glyphs.x + status.glyphs.width + 1)
    readonly property int boxY: Math.floor(status.y + status.glyphs.y - 1)
    readonly property var pose: Pose.coils({ x: boxRight - boxW, y: boxY, w: boxW, h: boxH }, 0, 0, { w: implicitWidth, h: implicitHeight })
    readonly property var chains: Pose.bodyChains(pose)
    readonly property real bodyLength: chains.reduce((a, c) => a + c.len, 0)
    readonly property var neckChain: chains[0]
    readonly property real tailFrom: chains[chains.length - 1].u0
    readonly property var neckWidths: widthsFor(neckChain)

    // Width scales for a chain, at 24 points, from where it lies on the body.
    function widthsFor(c) {
        const ws = new Array(Spine.SPINE_POINTS), n = ws.length;
        for (let k = 0; k < n; k++)
            ws[k] = Pose.widthAt(c.u0 + (c.u1 - c.u0) * k / (n - 1), root.tailFrom, root.bulges);
        return ws;
    }

    // Life

    readonly property int fpsCap: parseInt(Quickshell.env("UMBRIEL_SERPENT_FPS") || "") || 0
    readonly property bool running: visible && !locked && !Cover.outputOff(UmbrielIpc.outputs, screen?.name ?? "")

    // Seconds for the shader, wrapped hourly to keep its floats precise.
    property real clock: 0
    property real swell: 1
    property real phase: 0
    property real rippleAmp: 0.06
    property real look: 0
    property real lift: 0
    property real tongue: 0
    property real flutter: 0

    QtObject {
        id: life

        // Seconds of life (slowed at night) and of wall time.
        property real t: 0
        property real raw: 0
        property real nextFlick: 3
        property real flickAt: -10
        property real nextGaze: 6
        property real holdUntil: 0
        property real nextWave: 4
        property real waveAt: -10
        // The head's current turn: from where, to where, since when and
        // for how long (life seconds).
        property real lookFrom: 0
        property real liftFrom: 0
        property real lookTarget: 0
        property real liftTarget: 0
        property real turnAt: -10
        property real turnFor: 1
        property bool turning: false
        property real bentLook: 0
        property real bentLift: 0
        property real neckAcc: 0
        property var strike: null
    }

    onNightChanged: turnTo(look, night ? -0.18 : 0, 1.6)

    // Ease the head to a new turn and lift over `secs`.
    function turnTo(toLook, toLift, secs) {
        life.lookFrom = look;
        life.liftFrom = lift;
        life.lookTarget = toLook;
        life.liftTarget = toLift;
        life.turnAt = life.t;
        life.turnFor = secs;
        life.turning = true;
    }

    // dt: seconds since the last tick, already clamped by its clock.
    function tick(raw) {
        const d = raw * (night ? 0.5 : 1);
        life.raw += raw;
        life.t += d;
        const t = life.t;
        clock = (clock + d) % 3600;
        swell = 1 + Pose.BREATH * Math.sin(2 * Math.PI * t / 5);
        phase = (phase + 2.4 * d) % (2 * Math.PI);

        if (t >= life.nextWave) {
            life.waveAt = t;
            life.nextWave = t + 6 + 4 * Math.random();
        }
        const wt = (t - life.waveAt) / 2.5;
        rippleAmp = 0.06 + (wt < 1 ? 0.1 * Math.pow(Math.sin(Math.PI * wt), 2) : 0);

        if (t >= life.nextFlick) {
            life.flickAt = t;
            life.nextFlick = t + 8 + 7 * Math.random();
        }
        const ft = (t - life.flickAt) / 0.7;
        tongue = ft < 1 ? Math.pow(Math.sin(Math.PI * ft), 0.6) : 0;
        flutter = ft < 1 ? Math.sin(ft * 2 * Math.PI * 4.5) : 0;

        if (t >= life.nextGaze && t >= life.holdUntil) {
            turnTo((Math.random() - 0.5) * 1.1, night ? -0.18 : Math.random() * 0.25, 1.6);
            life.nextGaze = t + 10 + 10 * Math.random();
        }
        if (life.turning) {
            const u = Math.min((t - life.turnAt) / life.turnFor, 1), e = u * u * (3 - 2 * u);
            look = life.lookFrom + (life.lookTarget - life.lookFrom) * e;
            lift = life.liftFrom + (life.liftTarget - life.liftFrom) * e;
            if (u >= 1)
                life.turning = false;
        }

        const s = life.strike;
        if (s) {
            const tau = life.raw - s.at;
            s.k = tau < 0.12 ? 1 - Math.pow(1 - tau / 0.12, 4) : tau < 0.72 ? 0.5 + 0.5 * Math.cos(Math.PI * (tau - 0.12) / 0.6) : 0;
            if (tau >= 0.12 && !s.hit) {
                s.hit = true;
                if (s.onHit)
                    s.onHit();
            }
            if (tau >= 0.72)
                life.strike = null;
            bendNeck();
            return;
        }
        life.neckAcc += raw;
        if (life.neckAcc >= 1 / 30 && (Math.abs(look - life.bentLook) > 0.003 || Math.abs(lift - life.bentLift) > 0.003))
            bendNeck();
    }

    function bendNeck() {
        const s = life.strike;
        const pts = Pose.neckFor(pose.neck, look, lift, s ? s.joint : null, s ? s.k : 0);
        neck.setSpine(pts.reverse(), neckWidths);
        life.bentLook = look;
        life.bentLift = lift;
        life.neckAcc = 0;
    }
    onPoseChanged: Qt.callLater(bendNeck)
    onNeckWidthsChanged: bendNeck()

    // The clock. Every repaint of this window costs CPU whatever changes
    // in it, so it runs only as fast as the motion needs: the slow idle life
    // (breath, ripples and the stronger wave, the sheen's drift: brightness
    // steps of about a pixel at most) at idleHz, the head's slow turns and the
    // jaw at 30 Hz, and only a tongue flick or a strike at the display's rate.
    // (Running the wave at 30 Hz measured about 1.4% more CPU.)
    // UMBRIEL_SERPENT_FPS caps all three. Each clock clamps its dt only
    // against stalls (Pose.clockStep), so motion keeps its speed at any rate.
    readonly property int idleHz: 10
    readonly property bool fast: tongue > 0 || life.strike !== null
    readonly property bool slow: life.turning || jawMoving
    property bool jawMoving: false
    onJawChanged: {
        jawMoving = true;
        jawSettle.restart();
    }
    Timer {
        id: jawSettle
        interval: 250
        onTriggered: root.jawMoving = false
    }

    FrameAnimation {
        running: root.running && root.fast && root.fpsCap <= 0
        onTriggered: root.tick(Spine.step(frameTime))
    }
    Timer {
        readonly property int hz: {
            const want = root.fast ? 1000 : root.slow ? 30 : root.idleHz;
            return root.fpsCap > 0 ? Math.min(want, root.fpsCap) : want;
        }
        property real last: 0
        running: root.running && !(root.fast && root.fpsCap <= 0)
        interval: 1000 / Math.max(1, hz)
        repeat: true
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            root.tick(Pose.clockStep((now - last) / 1000, hz));
            last = now;
        }
    }

    // Umbriel's IPC doesn't report the session lock, but the rice-lock locker
    // keeps this file while the lock is secure (as Background.qml reads it).
    property bool locked: false
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
        running: root.visible
        onTriggered: lockFile.reload()
    }

    // Drawing

    PythonSkin {
        id: skinStrip
        bodyWidth: root.bodyWidth
        bodyLength: root.bodyLength
    }

    // One stretch of the body. Each coil's back and front breathe together
    // about its centre (the neck with the top coil); the tail rides along
    // with the bottom coil's left end. Only the near halves and the neck
    // catch the sheen, as on the overview board.
    component Body: Serpent {
        required property var chain
        readonly property var ring: root.pose.rings[chain.ring]
        readonly property bool isTail: chain.name === "tail"

        skin: skinStrip
        skinRect: Qt.rect(chain.u0 * skinStrip.stripWidth, 0, (chain.u1 - chain.u0) * skinStrip.stripWidth, skinStrip.height)
        bodyWidth: root.bodyWidth
        time: root.clock
        sheen: chain.near ? 0.4 : 0
        // One soft shadow lies under the whole pile instead (below).
        castShadow: false
        dull: root.dull
        // Offset per stretch so the wave runs on unbroken across the seams.
        ripplePhase: root.phase - 40 * chain.order
        rippleAmp: root.rippleAmp
        transform: [
            Scale {
                origin.x: ring.cx
                origin.y: ring.cy
                xScale: isTail ? 1 : root.swell
                yScale: isTail ? 1 : root.swell
            },
            Translate {
                x: isTail ? -ring.rx * (root.swell - 1) : 0
            }
        ]
    }

    // The pile's soft shadow on the desktop.
    Shape {
        id: pileShadow
        readonly property var r: root.pose.rings[0]
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 0; centerY: 0; centerRadius: 1
                focalX: 0; focalY: 0
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.45) }
                GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.25) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
            }
            PathSvg { path: "M -1 0 a 1 1 0 1 0 2 0 a 1 1 0 1 0 -2 0" }
        }
        transform: [
            Scale { xScale: pileShadow.r.rx + 18; yScale: pileShadow.r.ry + 16 },
            Translate { x: pileShadow.r.cx + 4; y: pileShadow.r.cy + 7 }
        ]
    }

    // Far halves, lowest first, with the tail under them all.
    Repeater {
        model: ["tail", "back0", "back1", "back2"].map(n => root.chains.find(c => c.name === n))
        Body {
            required property var modelData
            chain: modelData
            spine: modelData.points
            widths: root.widthsFor(modelData)
        }
    }

    StatusRow {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
    }

    // Near halves, lowest first: each coil lies on the one below.
    Repeater {
        model: ["front0", "front1", "front2"].map(n => root.chains.find(c => c.name === n))
        Body {
            required property var modelData
            chain: modelData
            spine: modelData.points
            widths: root.widthsFor(modelData)
        }
    }

    // The neck breathes with the top coil; the head only follows it there
    // (moving it is cheaper than scaling its shapes).
    Body {
        id: neck
        chain: root.neckChain
        Component.onCompleted: root.bendNeck()
    }

    PythonHead {
        readonly property var p: root.headAt
        readonly property var c: root.pose.rings[2]
        visible: p !== null
        x: p ? c.cx + (p.x - c.cx) * root.swell : 0
        y: p ? c.cy + (p.y - c.cy) * root.swell : 0
        rotation: p?.angle ?? 0
        dilation: root.dilation
        jaw: root.jaw
        tongue: root.tongue
        flutter: root.flutter
        glint: root.night ? 1 : 0
        milk: root.dull
    }

    readonly property var headAt: neck.head ? Pose.headPose(neck.head, look, lift) : null
}
