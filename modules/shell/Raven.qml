// The bar's raven (RICE_MASCOT=raven): perched on the bottom bar pill's top
// edge at its right end, facing along the bar. The art is Umbriel's
// (RavenBody.qml, drawn once; every motion is a transform of its parts) and
// so are its moods (raven-mood.js); both are copied in from
// modules/umbriel/shell by default.nix. Colours come from the wallpaper
// (Theme).
//
// Always alive while the bar shows (raven-mood.js times it):
// - breathing, a 1.5% swell of the chest every 4 s, and the faint sheen on
//   its wing and back drifting;
// - a blink of the nictitating membrane every 4-9 s;
// - a tilt or turn of the head every 6-14 s, now and then a double-take;
// - a ruffle every 2-4 min, a preen (beak in the back's feathers, ~2 s)
//   every 5-10 min.
// A pointer resting on the bar is watched after 2 s, and hopped at and
// pecked at after 5. notice(x) (a workspace switch, a volume or brightness
// change) makes it snap its head round to x and caw (silently: two arcs from
// the beak). After dark (21:00-06:00) it fluffs up and sleeps with its head
// tucked in; a notice wakes it for ~20 s.
//
// One clock, a Timer at several rates: every repaint of the bar costs CPU
// whatever changes, so it ticks at 5 Hz for the idle life (its steps are a
// tenth of a pixel), at 30 Hz while the head turns, blinks or preens, and at
// 60 Hz during a hop, a caw or a ruffle. It runs only while the bar is shown.
//
// RICE_RAVEN_DEBUG=1: a ruffle and a preen every 20 s, and night for 30 s of
// every 2 minutes.
import QtQuick
import Quickshell
import "raven-mood.js" as Mood

Item {
    id: root

    // The perch, in this item's coordinates: the line its feet grip (the
    // pill's top edge) and the x of its feet (near the pill's right end).
    property real perchY: 0
    property real homeX: 0
    // How far it may hop along the perch from home, either way (px).
    property real reachLeft: 40
    property real reachRight: 4
    // The pointer over the bar, in this item's coordinates (NaN when it isn't).
    property real hoverX: NaN
    property real hoverY: NaN
    // Where a noticed change happened is level with this y.
    property real noticeY: perchY + 19
    property bool running: false

    readonly property bool debug: Quickshell.env("RICE_RAVEN_DEBUG") === "1"

    // The pose (RavenBody's), and where the bird stands: hopX from home, hopY
    // up from the perch.
    property real breath: 1
    property real puff: 0
    property real lean: 0
    property real headAngle: 0
    property real headFlip: 1
    property real headDrop: 0
    property bool headTucked: false
    property real beakOpen: 0
    property real hackles: 0
    property real blink: 0
    property real lid: 0
    property real gazeX: 0
    property real gazeY: 0
    property real wingLift: 0
    property real preening: 0
    property real tailAngle: 0
    property real tuck: 0
    property real caw: 0
    property real sheen: 0.16
    property real sheenShift: 0
    property real hopX: 0
    property real hopY: 0

    QtObject {
        id: life

        // Seconds of life (the clock's, so it stops while the bar is hidden).
        property real t: 0
        property var tweens: []
        property var events: []
        property var hop: null
        property real nextBlink: 3
        property real nextLook: 5
        property real nextRuffle: 0
        property real nextPreen: 0
        // A long action (caw, preen, ruffle, peck) holds off the idle habits
        // until then.
        property real busyUntil: 0
        property var watch: null
        property bool asleep: false
        property real awakeUntil: 0
    }

    Component.onCompleted: {
        life.nextRuffle = debug ? 10 : Mood.nextIdle("ruffle", 0, Math.random) / 1000;
        life.nextPreen = debug ? 20 : Mood.nextIdle("preen", 0, Math.random) / 1000;
    }

    // Tweens: ease `prop` to `to` over `dur` s, starting `delay` s from now;
    // `hz` is the clock rate it needs. A tween that starts takes its property
    // over from any running one.
    function tween(prop, to, dur, delay, hz) {
        life.tweens.push({ p: prop, to: to, dur: Math.max(dur, 0.001), at: life.t + (delay || 0), from: NaN, hz: hz || 30, dead: false });
        rate();
    }
    function after(delay, fn) {
        life.events.push({ at: life.t + delay, fn: fn });
        rate();
    }
    // A new behaviour: what was still to come of the last one gives way;
    // blinks go on.
    function interrupt() {
        life.tweens = life.tweens.filter(w => w.at <= life.t || w.p === "blink");
        if (preening > 0)
            tween("preening", 0, 0.2);
    }
    function busy(secs) {
        life.busyUntil = Math.max(life.busyUntil, life.t + secs);
    }
    // A hop from hopX to x (offset from home), `h` px high, over `dur` s.
    function hopTo(x, h, dur) {
        life.hop = { x0: hopX, x1: x, h: h, at: life.t, dur: dur };
        rate();
    }

    // The clock's rate: fastHz during a hop or a fast tween, 30 Hz for the
    // head's moves, idleHz otherwise. It goes up a tick ahead of what is due.
    readonly property int idleHz: 5
    readonly property int fastHz: 60
    property int need: 0
    function rate() {
        let hz = 0;
        if (life.hop) {
            hz = fastHz;
        } else {
            for (const w of life.tweens)
                if (!w.dead && life.t >= w.at - 1.2 / idleHz)
                    hz = Math.max(hz, Math.min(w.hz, fastHz));
            for (const e of life.events)
                if (life.t >= e.at - 1.2 / idleHz)
                    hz = Math.max(hz, 30);
        }
        need = hz;
    }

    // dt: seconds since the last tick, already clamped by the clock.
    function tick(dt) {
        life.t += dt;
        const t = life.t;

        breath = 1 + 0.0075 * (1 - Math.cos(2 * Math.PI * t / 4));
        if (!life.asleep) {
            sheen = 0.16 + 0.06 * Math.sin(2 * Math.PI * t / 23);
            sheenShift = 0.15 * (1 + Math.sin(2 * Math.PI * t / 41));
        }

        const due = life.events.filter(e => t >= e.at);
        if (due.length > 0) {
            life.events = life.events.filter(e => t < e.at);
            for (const e of due)
                e.fn();
        }

        for (const w of life.tweens) {
            if (w.dead || t < w.at)
                continue;
            if (isNaN(w.from)) {
                w.from = root[w.p];
                for (const o of life.tweens)
                    if (o !== w && o.p === w.p && !isNaN(o.from))
                        o.dead = true;
            }
            const u = Math.min((t - w.at) / w.dur, 1);
            root[w.p] = w.from + (w.to - w.from) * u * u * (3 - 2 * u);
            if (u >= 1)
                w.dead = true;
        }
        life.tweens = life.tweens.filter(w => !w.dead);

        stepHop(t);
        habits(t, dt);
        rate();
    }

    function stepHop(t) {
        const h = life.hop;
        if (!h)
            return;
        // A crouch, then the jump: up and over in a parabola, wings beating
        // twice, legs swung back.
        const u = Math.min((t - h.at) / h.dur, 1);
        const c = 0.15;
        if (u < c) {
            hopY = -1.5 * Math.sin(Math.PI * u / c);
        } else {
            const p = (u - c) / (1 - c);
            hopX = h.x0 + (h.x1 - h.x0) * p * p * (3 - 2 * p);
            hopY = 4 * h.h * p * (1 - p);
            tuck = Math.sin(Math.PI * p);
            wingLift = Math.sin(Math.PI * p) * (0.6 + 0.4 * Math.sin(4 * Math.PI * p));
            lean = -7 * Math.sin(Math.PI * p);
            tailAngle = 6 * Math.sin(2 * Math.PI * p);
        }
        if (u >= 1) {
            life.hop = null;
            hopX = h.x1;
            hopY = 0;
            tuck = 0;
            wingLift = 0;
            lean = 0;
            tailAngle = 0;
        }
    }

    // Habits, the pointer and sleep.
    function habits(t, dt) {
        const free = t >= life.busyUntil && !life.hop;
        const night = root.night && t >= life.awakeUntil;
        if (free && night && !life.asleep)
            sleep();
        else if (free && !night && life.asleep)
            wake();
        if (life.asleep)
            return;

        if (t >= life.nextBlink) {
            life.nextBlink = Mood.nextIdle("blink", t * 1000, Math.random) / 1000;
            tween("blink", 1, 0.07);
            tween("blink", 0, 0.1, 0.12);
        }

        // The pointer, unless something else holds its attention.
        const watching = life.watch && life.watch.phase !== "idle";
        if (free || watching) {
            const p = !isNaN(hoverX) ? { x: hoverX, y: hoverY, still: Date.now() - movedAt } : null;
            const was = life.watch?.phase ?? "idle";
            life.watch = Mood.watchState(life.watch, p, dt * 1000);
            if (life.watch.phase !== was)
                onWatch(was, life.watch);
            if (life.watch.phase !== "idle")
                return;
        }
        if (!free)
            return;

        if (t >= life.nextPreen) {
            life.nextPreen = debug ? t + 20 : Mood.nextIdle("preen", t * 1000, Math.random) / 1000;
            preen();
        } else if (t >= life.nextRuffle) {
            life.nextRuffle = debug ? t + 20 : Mood.nextIdle("ruffle", t * 1000, Math.random) / 1000;
            ruffle();
        } else if (t >= life.nextLook) {
            life.nextLook = Mood.nextIdle("look", t * 1000, Math.random) / 1000;
            look();
        }
    }

    // Behaviours

    // A tilt or a turn of the head, held for a while; sometimes a quick
    // double-take first.
    function look() {
        interrupt();
        const a = -10 + Math.random() * 26;
        const turn = Math.random() < 0.35 ? 0.72 : 1;
        const hold = 1.5 + Math.random() * 2.5;
        if (Math.random() < 0.3) {
            tween("headAngle", a, 0.09);
            tween("headAngle", 0, 0.09, 0.2);
            tween("headAngle", a, 0.1, 0.4);
            busy(0.6);
        } else {
            tween("headAngle", a, 0.25);
        }
        tween("headFlip", turn, 0.25);
        tween("gazeX", Math.random() * 2 - 1, 0.2);
        tween("gazeY", Math.random() * 1.2 - 0.6, 0.2);
        tween("headAngle", 0, 0.35, hold);
        tween("headFlip", 1, 0.35, hold);
        tween("gazeX", 0, 0.3, hold);
        tween("gazeY", 0, 0.3, hold);
    }

    // Feathers puffed and shaken out, then settled.
    function ruffle() {
        interrupt();
        busy(1.8);
        tween("puff", 0.06, 0.3);
        tween("hackles", 0.7, 0.3);
        for (let i = 0; i < 6; i++) {
            tween("lean", i % 2 ? 2.5 : -2.5, 0.06, 0.32 + i * 0.07, fastHz);
            tween("tailAngle", i % 2 ? -4 : 4, 0.06, 0.32 + i * 0.07, fastHz);
        }
        tween("wingLift", 0.14, 0.12, 0.34, fastHz);
        tween("wingLift", 0, 0.16, 0.6, fastHz);
        tween("lean", 0, 0.12, 0.76, fastHz);
        tween("tailAngle", 0, 0.12, 0.76, fastHz);
        tween("puff", nightPuff(), 0.6, 1.1);
        tween("hackles", 0, 0.6, 1.1);
    }

    // The head turned right round over the shoulder, the beak worked into
    // the feathers of the back, which part and lift round it, for ~2 s.
    function preen() {
        interrupt();
        busy(3.3);
        tween("headFlip", -1, 0.28);
        tween("headAngle", 30, 0.35, 0.2);
        tween("headDrop", 1.5, 0.35, 0.2);
        tween("preening", 1, 0.2, 0.45);
        for (let i = 0; i < 6; i++) {
            tween("headAngle", i % 2 ? 27 : 33, 0.2, 0.6 + i * 0.32);
            tween("beakOpen", i % 2 ? 0 : 0.18, 0.12, 0.6 + i * 0.32);
        }
        tween("beakOpen", 0, 0.12, 2.6);
        tween("preening", 0, 0.3, 2.6);
        tween("headAngle", 0, 0.3, 2.7);
        tween("headDrop", 0, 0.3, 2.7);
        tween("headFlip", 1, 0.28, 2.9);
    }

    // Turn the head to face `to` (1 forward, -1 back) over `dur` s; it goes
    // under the wing's edge while it faces back.
    function turnHead(to, dur, delay) {
        tween("headFlip", to, dur, delay);
        after(delay + dur / 2, () => root.headTucked = to < 0);
    }

    readonly property real nightPuffAmount: 0.08
    function nightPuff() {
        return life.asleep ? nightPuffAmount : 0;
    }

    function sleep() {
        interrupt();
        life.asleep = true;
        tween("puff", nightPuffAmount, 1.2);
        turnHead(-1, 0.4, 0);
        tween("headAngle", 40, 0.8, 0.3);
        tween("headDrop", 5, 0.8, 0.3);
        tween("lid", 1, 0.3, 0.6);
        tween("sheen", 0.12, 1.2);
    }

    function wake() {
        interrupt();
        life.asleep = false;
        tween("lid", 0, 0.15);
        tween("headAngle", 0, 0.3);
        tween("headDrop", 0, 0.3);
        turnHead(1, 0.3, 0.1);
        tween("puff", 0, 0.8);
        busy(0.5);
    }

    // The head's position (near the eye), in this item's coordinates.
    function headPos() {
        return { x: homeX + hopX - 10 * body.k, y: perchY - 43 * body.k };
    }

    // Something changed at x (level with noticeY): snap the head round to it
    // and caw.
    function notice(x) {
        // Unseen (and it would play late, once the clock runs again).
        if (!running)
            return;
        const d = life.asleep ? 0.45 : 0;
        if (life.asleep || root.night) {
            life.awakeUntil = life.t + 20;
            if (life.asleep)
                wake();
        }
        life.watch = null;
        interrupt();
        busy(4);
        const h = headPos();
        const behind = x > h.x + 6;
        const a = Math.min(Math.max(Math.atan2(h.y - noticeY, Math.abs(x - h.x)) * 180 / Math.PI, -40), 20);
        turnHead(behind ? -1 : 1, 0.15, d);
        tween("headAngle", a, 0.12, d, fastHz);
        tween("gazeX", behind ? 0.7 : -0.7, 0.12, d, fastHz);
        tween("gazeY", 0.5, 0.12, d, fastHz);
        // The call: gape, hackles up, a bob of the body and a flick of the
        // tail, and the two arcs.
        tween("beakOpen", 1, 0.08, d + 0.15, fastHz);
        tween("hackles", 1, 0.12, d + 0.15, fastHz);
        tween("lean", -6, 0.1, d + 0.15, fastHz);
        tween("tailAngle", 7, 0.1, d + 0.15, fastHz);
        tween("caw", 1, 0.75, d + 0.17, fastHz);
        tween("beakOpen", 0, 0.16, d + 0.48, fastHz);
        tween("lean", 0, 0.3, d + 0.4, fastHz);
        tween("tailAngle", 0, 0.3, d + 0.4, fastHz);
        tween("hackles", 0, 0.6, d + 0.6);
        after(d + 0.95, () => root.caw = 0);
        // Then it keeps an eye on the spot a while.
        tween("headAngle", 0, 0.5, d + 2.4);
        tween("gazeX", 0, 0.4, d + 2.4);
        tween("gazeY", 0, 0.4, d + 2.4);
        if (behind)
            turnHead(1, 0.25, d + 2.4);
    }

    // The pointer: watch, hop at it, peck the air, settle back. Hover is
    // re-sent with the same position as the window repaints; only a real
    // move counts.
    property real movedAt: 0
    property point lastHover: Qt.point(-1, -1)
    function pointerMoved() {
        if (isNaN(hoverX))
            return;
        if (Math.abs(hoverX - lastHover.x) + Math.abs(hoverY - lastHover.y) >= 1) {
            lastHover = Qt.point(hoverX, hoverY);
            movedAt = Date.now();
        }
    }
    onHoverXChanged: pointerMoved()
    onHoverYChanged: pointerMoved()

    function onWatch(was, s) {
        const h = headPos();
        interrupt();
        if (s.phase === "watch") {
            const behind = s.target.x > h.x + 6;
            const dx = Math.abs(s.target.x - h.x), dy = h.y - s.target.y;
            const a = Math.min(Math.max(Math.atan2(dy, dx) * 180 / Math.PI, -35), 35);
            turnHead(behind ? -1 : 1, 0.2, 0);
            // Cocked: one eye on it.
            tween("headAngle", a + 10, 0.25);
            tween("gazeX", behind ? 0.8 : -0.8, 0.2);
            tween("gazeY", Math.max(Math.min(-dy / 40, 1), -1), 0.2);
        } else if (s.phase === "hop") {
            const dir = s.target.x < homeX ? -1 : 1;
            hopTo(Math.min(Math.max(dir * 8, -reachLeft), reachRight), 7, Mood.HOP / 1000);
        } else if (s.phase === "peck") {
            const dx = Math.abs(s.target.x - h.x), dy = h.y - s.target.y;
            const a = Math.min(Math.max(Math.atan2(dy, dx) * 180 / Math.PI, -40), 30);
            tween("lean", -14, 0.08, 0, fastHz);
            tween("headAngle", a - 8, 0.08, 0, fastHz);
            tween("beakOpen", 0.5, 0.05, 0.06, fastHz);
            tween("beakOpen", 0, 0.05, 0.12, fastHz);
            tween("beakOpen", 0.45, 0.05, 0.18, fastHz);
            tween("beakOpen", 0, 0.05, 0.24, fastHz);
        } else if (s.phase === "settle") {
            tween("lean", 0, 0.15, 0, fastHz);
            tween("headAngle", 0, 0.3);
            tween("gazeX", 0, 0.3);
            tween("gazeY", 0, 0.3);
            turnHead(1, 0.2, 0);
            hopTo(0, 4, 0.45);
            tween("puff", 0.03, 0.15, 0.45);
            tween("puff", nightPuff(), 0.15, 0.6);
        } else if (was === "watch") {
            tween("headAngle", 0, 0.35);
            tween("gazeX", 0, 0.3);
            tween("gazeY", 0, 0.3);
            turnHead(1, 0.25, 0);
        }
    }

    // Night: checked every 30 s while the bar shows (every second in debug,
    // where it is night for 30 s of every 2 minutes).
    property bool night: false
    Timer {
        interval: root.debug ? 1000 : 30000
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: root.night = root.debug ? (Date.now() / 1000) % 120 < 30 : Mood.isNight(new Date())
    }

    // The clock.
    Timer {
        readonly property int hz: root.need > 0 ? root.need : root.idleHz
        property real last: 0
        running: root.running
        interval: 1000 / Math.max(1, hz)
        repeat: true
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            root.tick(Mood.clockStep((now - last) / 1000, hz));
            last = now;
        }
    }

    RavenBody {
        id: body
        x: root.homeX + root.hopX - footX
        y: root.perchY - perchY - root.hopY
        size: 44
        // A very dark surface, its feathers edged in a dark slate of the
        // outline (as dark as Umbriel's, so the bird reads black, not grey);
        // the eye's catch-light the text colour; the sheen the wallpaper's
        // accents, deepened so a pale palette doesn't grey the wing.
        bodyColor: Qt.darker(Theme.surface, 1.4)
        edgeColor: Qt.darker(Theme.outline, 2.6)
        beakColor: Theme.surfaceContainer
        eyeColor: Theme.text
        membraneColor: Theme.textMuted
        sheenColors: [Qt.darker(Theme.primary, 1.8), Qt.darker(Qt.tint(Theme.primary, Qt.alpha(Theme.tertiary, 0.5)), 1.8), Qt.darker(Theme.tertiary, 1.8)]
        breath: root.breath
        puff: root.puff
        lean: root.lean
        headAngle: root.headAngle
        headFlip: root.headFlip
        headDrop: root.headDrop
        headTucked: root.headTucked
        beakOpen: root.beakOpen
        hackles: root.hackles
        blink: root.blink
        lid: root.lid
        gazeX: root.gazeX
        gazeY: root.gazeY
        wingLift: root.wingLift
        preen: root.preening
        tailAngle: root.tailAngle
        tuck: root.tuck
        caw: root.caw
        sheen: root.sheen
        sheenShift: root.sheenShift
    }
}
