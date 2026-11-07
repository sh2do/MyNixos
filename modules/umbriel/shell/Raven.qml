// Bottom-right corner: a raven perched on the status row's left edge
// (Status.qml), facing the screen, and its hoard of up to three trinkets on
// the row behind it. Drawn once (RavenBody.qml); every motion is a
// transform of its parts. Its pose and its life are RavenLife.qml, shared
// with the niri bar's raven; the island, the trinkets and the hoard are its
// own, here.
//
// Always alive (raven-mood.js times it):
// - breathing, a 1.5% swell of the chest every 4 s, and the faint sheen on
//   its wing and back drifting;
// - a blink of the pale nictitating membrane every 4-9 s;
// - a tilt or turn of the head every 6-14 s, now and then a double-take;
// - a ruffle every 2-4 min, a preen (beak in the back's feathers, ~2 s)
//   every 5-10 min.
// A notice showing on the island makes it snap round and caw (silently: two
// pale arcs from the beak). When the notice leaves, a trinket drops from the
// island down the screen's right edge, in two small windows of its own that
// exist only while it falls (one for the toss, a narrow strip down the edge); the raven hops up to catch it, turns round
// and sets it down in the hoard, where it fades over 10 minutes.
// A pointer resting near it is watched after 2 s, and hopped at and pecked
// at after 5. After dark (21:00-06:00) it fluffs up and sleeps with its
// head tucked in; a notice wakes it for ~20 s.
//
// One clock, as the serpents': every repaint of the window costs CPU
// whatever changes, so it ticks at idleHz (5 Hz) for the idle life (its
// steps are a tenth of a pixel), at 30 Hz while the head turns, blinks or
// preens, and at the display's rate only during a hop, a caw, a flap or a
// trinket's fall. UMBRIEL_SERPENT_FPS caps it. It stops while hidden
// (fullscreen), locked or with the screen off.
//
// UMBRIEL_RAVEN_DEBUG=1: a ruffle and a preen every 20 s, and night for
// 30 s of every 2 minutes.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as U
import "raven-mood.js" as Mood
import "wall-cover.js" as Cover

PanelWindow {
    id: root

    // The island it caws at (noticeShown, noticeGone), and the status row
    // it perches on.
    required property var island
    required property var status

    visible: !UmbrielIpc.fullscreen

    anchors {
        bottom: true
        right: true
    }
    // Level with Status, so the row's edge is a line in this window.
    margins {
        bottom: status.margins.bottom
        right: status.margins.right
    }
    implicitWidth: 180
    implicitHeight: 120
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "umbriel-raven"

    // Click-through except around the raven itself, where it sees the
    // pointer.
    mask: Region {
        item: near
    }

    readonly property bool debug: Quickshell.env("UMBRIEL_RAVEN_DEBUG") === "1"

    // Layout, in window coordinates: the perch line just above the row's
    // glyphs, the feet gripping its left end, the hoard behind the tail.
    readonly property real rowTop: height + margins.bottom - status.margins.bottom - status.height
    readonly property real perchY: rowTop + 5
    readonly property real rowLeft: width + margins.right - status.margins.right - status.width
    readonly property real homeX: rowLeft + 6
    function slotX(slot) {
        return Math.min(homeX + 46 + slot * 11, width - 6);
    }
    // This window's top-left on the screen.
    readonly property real originX: (screen?.width ?? 0) - margins.right - width
    readonly property real originY: (screen?.height ?? 0) - margins.bottom - height

    // The hoard (Mood.hoardAdd/hoardStep) and each slot's kind of trinket.
    property var hoard: []
    // Each slot's opacity as it fades: updated without rebuilding the
    // hoard's items, which change only when one comes or goes.
    property var fades: [1, 1, 1]
    property var slotRing: [true, false, true]
    // Something in the beak, and whether it is a ring (or a coin).
    property bool holding: false
    property bool heldRing: true
    // A trinket in flight (screen coordinates) and one dropping into the
    // hoard (window coordinates).
    property bool flying: false
    property point flightPos: Qt.point(0, 0)
    // The two windows it falls through (screen coordinates): the toss's box
    // from the island out to the edge, and the strip down the edge from
    // there into the beak.
    property rect tossBox: Qt.rect(0, 0, 0, 0)
    property rect stripBox: Qt.rect(0, 0, 0, 0)
    property bool flightRing: true
    property real spin: 0
    property bool dropping: false
    property bool dropRing: true
    property point dropPos: Qt.point(0, 0)

    // The pose and the life common to both ravens (RavenLife.qml), and the
    // catch's own state.
    U.RavenLife {
        id: life

        fastHz: 1000
        moving: flight !== null || drop !== null
        night: root.night
        debug: root.debug
        k: body.k
        homeX: root.homeX
        perchY: root.perchY
        reachLeft: root.homeX - root.rowLeft
        reachRight: root.width - 30 - root.homeX
        pointerX: hover.hovered ? near.x + hover.last.x : NaN
        pointerY: hover.hovered ? near.y + hover.last.y : NaN
        movedAt: root.movedAt
        onStepped: t => {
            root.stepFlight(t);
            root.stepDrop(t);
            if (t - hoardAt >= 5 && root.hoard.length > 0) {
                hoardAt = t;
                const stepped = Mood.hoardStep(root.hoard, Date.now());
                if (stepped.length !== root.hoard.length)
                    root.setHoard(stepped);
                else
                    root.fades = root.fadesOf(stepped);
            }
        }

        property var flight: null
        property var drop: null
        // From a trinket's fall until the raven is home again; a caw or
        // another trinket meanwhile waits.
        property bool catching: false
        property int cawsWaiting: 0
        property var queued: []
        property real hoardAt: 0
    }

    // The angle that points the beak at the island, as far as a neck goes.
    function islandAngle() {
        const hx = originX + homeX - 10, hy = originY + perchY - 43;
        const ix = (screen?.width ?? 0) / 2, iy = 40;
        return Math.min(Math.max(Math.atan2(hy - iy, hx - ix) * 180 / Math.PI, 8), 38);
    }

    // Snap round to the island and caw.
    function cawAtIsland() {
        // Unseen (and it would play late, once the clock runs again).
        if (!running)
            return;
        if (life.catching) {
            life.cawsWaiting++;
            return;
        }
        // Woken, it first lifts its head out of the wing.
        const d = life.rouse();
        life.busy(4);
        const a = islandAngle();
        if (life.headFlip < 0.9)
            life.turnHead(1, 0.15, d);
        life.tween("headAngle", a, 0.12, d, 1000);
        life.tween("gazeX", -0.7, 0.12, d, 1000);
        life.tween("gazeY", -0.7, 0.12, d, 1000);
        life.call(d);
        // Then it keeps an eye on the island a while.
        life.tween("headAngle", 0, 0.5, d + 3.4);
        life.tween("gazeX", 0, 0.4, d + 3.4);
        life.tween("gazeY", 0, 0.4, d + 3.4);
    }

    // The pointer (as `near` sees it): only a real move counts.
    property real movedAt: 0

    // The hoard

    // A trinket drops from the island: ~0.85 s tossed out and over to the
    // right edge, ~0.75 s down it, then off it in a little arc into the
    // beak, which the raven hops up to meet.
    readonly property real tossFor: 0.85
    readonly property real slideFor: 0.75
    readonly property real arcFor: 0.32

    function trinketFrom(at) {
        // Nobody sees it fall, and a stopped clock would leave its window
        // hanging: it goes straight into the hoard.
        if (!running) {
            stash(Math.random() < 0.5);
            return;
        }
        if (life.catching) {
            life.queued = life.queued.concat([at]);
            return;
        }
        life.rouse();
        life.catching = true;
        const total = tossFor + slideFor + arcFor;
        const sw = screen?.width ?? 0;
        // Where the toss meets the edge.
        const ex = sw - 26, ey = at.y + 0.42 * ((screen?.height ?? 0) - at.y);
        // Room round the trinket and its glow, and in the strip for the beak
        // where it is now plus its hop.
        const pad = 12;
        const b = body.beakSlot.mapToItem(null, 0, 0);
        tossBox = Qt.rect(at.x - pad, at.y - 40 - pad, sw - at.x + pad, ey - at.y + 40 + 2 * pad);
        const left = Math.min(ex, originX + b.x - 20) - pad;
        stripBox = Qt.rect(left, ey - pad, sw - left, (screen?.height ?? 0) - ey + pad);
        flightRing = Math.random() < 0.5;
        flightPos = at;
        spin = 0;
        life.flight = { sx: at.x, sy: at.y, ex: ex, ey: ey, at: life.t, total: total };
        flying = true;
        life.busy(total + 3);
        // It looks up and round at it coming down the edge, and hops to meet
        // it at the top of the hop.
        life.turnHead(-1, 0.25, tossFor * 0.6);
        life.tween("headAngle", 28, 0.3, tossFor * 0.6);
        life.tween("gazeX", 0.6, 0.2, tossFor * 0.6);
        life.tween("gazeY", -0.8, 0.2, tossFor * 0.6);
        life.tween("headAngle", 12, 0.25, total - 0.3);
        life.after(total - 0.29, () => life.hopTo(9, 12, 0.5));
        life.rate();
    }

    function stepFlight(t) {
        const f = life.flight;
        if (!f)
            return;
        const u = t - f.at;
        const ex = f.ex, ey = f.ey;
        const dy = originY + 6;
        spin = u;
        let x, y;
        if (u < tossFor) {
            const s = u / tossFor, e = s * s * (3 - 2 * s), r = 1 - e;
            x = r * r * r * f.sx + 3 * r * r * e * (f.sx + 160) + 3 * r * e * e * ex + e * e * e * ex;
            y = r * r * r * f.sy + 3 * r * r * e * (f.sy - 40) + 3 * r * e * e * (f.sy + 60) + e * e * e * ey;
        } else if (u < tossFor + slideFor) {
            const s = (u - tossFor) / slideFor;
            x = ex;
            y = ey + (dy - ey) * (0.4 * s + 0.6 * s * s);
        } else {
            // Off the edge and into the beak, wherever it is now.
            const s = Math.min((u - tossFor - slideFor) / arcFor, 1), r = 1 - s;
            const b = body.beakSlot.mapToItem(null, 0, 0);
            const bx = originX + b.x, by = originY + b.y;
            x = r * r * ex + 2 * r * s * (ex - 6) + s * s * bx;
            y = r * r * dy + 2 * r * s * (dy - 20) + s * s * by;
        }
        flightPos = Qt.point(x, y);
        if (u >= f.total) {
            life.flight = null;
            flying = false;
            caught();
        }
    }

    // In the beak: land, turn round, set it down in the hoard, turn back
    // and hop home.
    function caught() {
        heldRing = flightRing;
        holding = true;
        life.tween("beakOpen", 0.25, 0.05, 0, 1000);
        life.tween("beakOpen", 0.08, 0.08, 0.06, 1000);
        life.after(0.55, () => {
            // In the air it turns round; the head, still facing back, is
            // now forward.
            life.hopTo(9, 4, 0.34, -1);
            life.tween("headFlip", 1, 0.12, 0.1, 1000);
            life.after(0.16, () => life.headTucked = false);
            life.tween("headAngle", 0, 0.12, 0.1, 1000);
        });
        life.tween("lean", -13, 0.22, 1.0, 1000);
        life.tween("headAngle", -42, 0.22, 1.0, 1000);
        life.tween("headDrop", 4, 0.22, 1.0, 1000);
        life.tween("gazeX", -0.4, 0.2, 1.0);
        life.tween("gazeY", 0.8, 0.2, 1.0);
        life.tween("beakOpen", 0.35, 0.06, 1.24, 1000);
        life.after(1.26, root.release);
        life.tween("beakOpen", 0, 0.1, 1.34, 1000);
        life.tween("lean", 0, 0.25, 1.45, 1000);
        life.tween("headAngle", 0, 0.25, 1.45, 1000);
        life.tween("headDrop", 0, 0.25, 1.45, 1000);
        life.tween("gazeX", 0, 0.3, 1.5);
        life.tween("gazeY", 0, 0.3, 1.5);
        life.after(1.9, () => life.hopTo(0, 6, 0.45, 1, root.nextTrinket));
    }

    // Let go: it drops onto the row at its slot.
    function release() {
        const next = Mood.hoardAdd(hoard, Date.now());
        const slot = next[next.length - 1].slot;
        const b = body.beakSlot.mapToItem(null, 0, 0);
        holding = false;
        dropRing = heldRing;
        dropPos = Qt.point(b.x, b.y);
        life.drop = { x0: b.x, y0: b.y, x1: slotX(slot), y1: perchY - 3, at: life.t, dur: 0.3, next: next, slot: slot };
        dropping = true;
        life.rate();
    }

    function stepDrop(t) {
        const d = life.drop;
        if (!d)
            return;
        const u = Math.min((t - d.at) / d.dur, 1);
        // Falling, with a small bounce at the end.
        const fall = u < 0.8 ? Math.pow(u / 0.8, 2) : 1 - 0.12 * Math.sin(Math.PI * (u - 0.8) / 0.2);
        dropPos = Qt.point(d.x0 + (d.x1 - d.x0) * Math.min(u / 0.8, 1), d.y0 + (d.y1 - d.y0) * fall);
        if (u >= 1) {
            life.drop = null;
            dropping = false;
            setHoard(d.next, d.slot, dropRing);
        }
    }

    // A new hoard; a new trinket's kind goes into its slot.
    function setHoard(next, slot, ring) {
        if (slot !== undefined) {
            const kinds = slotRing.slice();
            kinds[slot] = ring;
            slotRing = kinds;
        }
        fades = fadesOf(next);
        hoard = next;
    }
    function fadesOf(h) {
        const f = [1, 1, 1];
        for (const it of h)
            f[it.slot] = it.opacity;
        return f;
    }

    // Straight into the hoard, unseen: for a notice gone while the clock is
    // stopped.
    function stash(ring) {
        const next = Mood.hoardAdd(hoard, Date.now());
        setHoard(next, next[next.length - 1].slot, ring);
    }

    // The clock stopped (fullscreen, locked, screen off) in the middle of a
    // catch: what was falling, held or dropping goes straight into the hoard,
    // and so does anything waiting; nothing (above all the trinket's window)
    // is left hanging, and the raven is back on its perch.
    function settleNow() {
        if (!life.catching)
            return;
        if (life.drop)
            setHoard(life.drop.next, life.drop.slot, dropRing);
        else if (life.flight)
            stash(flightRing);
        else if (holding)
            stash(heldRing);
        for (let i = 0; i < life.queued.length; i++)
            stash(Math.random() < 0.5);
        life.queued = [];
        life.cawsWaiting = 0;
        life.flight = null;
        life.drop = null;
        life.catching = false;
        flying = false;
        holding = false;
        dropping = false;
        life.perch();
    }
    onRunningChanged: if (!running) settleNow()

    function nextTrinket() {
        life.catching = false;
        // One caw per notice that showed meanwhile, between the catches.
        if (life.cawsWaiting > 0) {
            life.cawsWaiting--;
            cawAtIsland();
            if (life.cawsWaiting > 0 || life.queued.length > 0)
                life.after(1.2, nextTrinket);
            return;
        }
        if (life.queued.length > 0) {
            const at = life.queued[0];
            life.queued = life.queued.slice(1);
            trinketFrom(at);
        }
    }

    Connections {
        target: root.island
        function onNoticeShown() {
            root.cawAtIsland();
        }
        function onNoticeGone(at) {
            root.trinketFrom(at);
        }
    }

    // Night: checked every 30 s (every second in debug, where it is night
    // for 30 s of every 2 minutes).
    property bool night: false
    Timer {
        interval: root.debug ? 1000 : 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.night = root.debug ? (Date.now() / 1000) % 120 < 30 : Mood.isNight(new Date())
    }

    // The clock

    readonly property int fpsCap: parseInt(Quickshell.env("UMBRIEL_SERPENT_FPS") || "") || 0
    readonly property bool running: visible && !locked && !Cover.outputOff(UmbrielIpc.outputs, screen?.name ?? "")
    readonly property bool fast: life.need >= 1000

    FrameAnimation {
        running: root.running && root.fast && root.fpsCap <= 0
        onTriggered: life.tick(Mood.clockStep(frameTime, 60))
    }
    Timer {
        readonly property int hz: {
            const want = life.need > 0 ? life.need : life.idleHz;
            return root.fpsCap > 0 ? Math.min(want, root.fpsCap) : want;
        }
        property real last: 0
        running: root.running && !(root.fast && root.fpsCap <= 0)
        interval: 1000 / Math.max(1, hz)
        repeat: true
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            life.tick(Mood.clockStep((now - last) / 1000, hz));
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

    // The pointer-seeing area: the raven and a margin round it.
    Item {
        id: near
        x: Math.max(0, root.homeX - body.footX - 14)
        y: Math.max(0, root.perchY - body.perchY - 14)
        width: Math.min(root.width - x, body.width + 28)
        height: root.perchY + 6 - y

        // Hover is re-sent with the same position as the window repaints;
        // only a real move counts.
        HoverHandler {
            id: hover
            property point last: Qt.point(-1, -1)
            onPointChanged: {
                const p = point.position;
                if (Math.abs(p.x - last.x) + Math.abs(p.y - last.y) >= 1) {
                    last = p;
                    root.movedAt = Date.now();
                }
            }
        }
    }

    // The row's edge, faint: what it grips and the hoard sits on.
    Rectangle {
        x: root.rowLeft
        y: Math.round(root.perchY)
        width: root.width - root.rowLeft - 4
        height: 1
        color: U.Palette.line
        opacity: 0.6
    }

    Repeater {
        model: root.hoard
        Trinket {
            required property var modelData
            x: root.slotX(modelData.slot)
            y: root.perchY - 3
            ring: root.slotRing[modelData.slot]
            opacity: root.fades[modelData.slot]
        }
    }

    Trinket {
        visible: root.dropping
        x: root.dropPos.x
        y: root.dropPos.y
        ring: root.dropRing
    }

    RavenBody {
        id: body
        x: root.homeX + life.hopX - footX
        y: root.perchY - perchY - life.hopY
        size: 64
        bodyColor: U.Palette.ravenBody
        edgeColor: U.Palette.ravenEdge
        beakColor: U.Palette.ravenBeak
        eyeColor: U.Palette.ravenEye
        membraneColor: U.Palette.ravenMembrane
        transform: Scale {
            origin.x: body.footX
            xScale: life.facing
        }
        breath: life.breath
        puff: life.puff
        lean: life.lean
        headAngle: life.headAngle
        headFlip: life.headFlip
        headDrop: life.headDrop
        headTucked: life.headTucked
        beakOpen: life.beakOpen
        hackles: life.hackles
        blink: life.blink
        lid: life.lid
        gazeX: life.gazeX
        gazeY: life.gazeY
        wingLift: life.wingLift
        preen: life.preening
        tailAngle: life.tailAngle
        tuck: life.tuck
        caw: life.caw
        sheen: life.sheen
        sheenShift: life.sheenShift
    }

    // Held in the beak (it rides on the lower mandible).
    Trinket {
        parent: body.beakSlot
        visible: root.holding
        ring: root.heldRing
        scale: 1 / body.k
    }

    // The falling trinket's windows; they take no input and exist only
    // while it falls. Both are there from the start and go together at the
    // end, so the hand-over neither waits for a new window nor stalls on one
    // going (Umbriel reconfigures every layer when one goes): the one not
    // holding the trinket is never redrawn.
    component FlightWindow: PanelWindow {
        id: flightWindow
        required property rect box
        required property bool holds
        screen: root.screen
        anchors {
            top: true
            left: true
        }
        margins {
            left: Math.round(box.x)
            top: Math.round(box.y)
        }
        implicitWidth: Math.round(box.width)
        implicitHeight: Math.round(box.height)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "umbriel-trinket"
        mask: Region {}

        Trinket {
            visible: flightWindow.holds
            x: root.flightPos.x - flightWindow.margins.left
            y: root.flightPos.y - flightWindow.margins.top
            ring: root.flightRing
            spin: root.spin
            glint: 0.5 + 0.5 * Math.sin(root.spin * 9)
        }
    }
    LazyLoader {
        active: root.flying
        FlightWindow {
            box: root.tossBox
            holds: root.spin < root.tossFor
        }
    }
    LazyLoader {
        active: root.flying
        FlightWindow {
            box: root.stripBox
            holds: root.spin >= root.tossFor
        }
    }

    // A trinket: a pale ring or coin centred on its position, with a glow
    // (a pre-blurred radial disc) and, in flight, a spin and a glint.
    component Trinket: Item {
        property bool ring: true
        property real spin: 0
        property real glint: 0

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: RadialGradient {
                    centerX: 0; centerY: 0; centerRadius: 8
                    focalX: 0; focalY: 0
                    GradientStop { position: 0; color: Qt.alpha(U.Palette.trinket, 0.32) }
                    GradientStop { position: 0.45; color: Qt.alpha(U.Palette.trinket, 0.1) }
                    GradientStop { position: 1; color: Qt.alpha(U.Palette.trinket, 0) }
                }
                PathSvg { path: "M-8,0 a8,8 0 1,0 16,0 a8,8 0 1,0 -16,0 Z" }
            }
        }

        // The ring or coin, turning (a coin shows its edge as it spins).
        Item {
            transform: Scale {
                xScale: 0.35 + 0.65 * Math.abs(Math.cos(spin * 7))
            }
            Shape {
                visible: ring
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: U.Palette.trinket
                    strokeWidth: 1.2
                    fillColor: "transparent"
                    PathSvg { path: "M-2.6,0 a2.6,2.6 0 1,0 5.2,0 a2.6,2.6 0 1,0 -5.2,0 Z" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(U.Palette.muted, 0.8)
                    strokeWidth: 0.45
                    fillColor: "transparent"
                    PathSvg { path: "M-1.9,0.4 a1.95,1.95 0 0,0 3.8,0" }
                }
            }
            Shape {
                visible: !ring
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: U.Palette.muted
                    strokeWidth: 0.5
                    fillGradient: LinearGradient {
                        x1: -2; y1: -2.4; x2: 2; y2: 2.4
                        GradientStop { position: 0; color: U.Palette.trinket }
                        GradientStop { position: 1; color: U.Palette.muted }
                    }
                    PathSvg { path: "M-2.8,0 a2.8,2.8 0 1,0 5.6,0 a2.8,2.8 0 1,0 -5.6,0 Z" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(U.Palette.slate, 0.9)
                    strokeWidth: 0.4
                    fillColor: "transparent"
                    PathSvg { path: "M-1.6,0 a1.6,1.6 0 1,0 3.2,0 a1.6,1.6 0 1,0 -3.2,0 Z" }
                }
            }
        }

        // The glint: a four-pointed star.
        Shape {
            visible: glint > 0.02
            opacity: glint
            x: 1.6
            y: -1.8
            scale: 0.5 + 0.7 * glint
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillColor: U.Palette.trinket
                PathSvg { path: "M0,-3.4 L0.45,-0.45 L3.4,0 L0.45,0.45 L0,3.4 L-0.45,0.45 L-3.4,0 L-0.45,-0.45 Z" }
            }
        }
    }
}
