// A raven's life, shared by Umbriel's corner raven (Raven.qml) and the niri
// bar's (modules/shell/Raven.qml; its default.nix copies this in, with
// RavenBody.qml and raven-mood.js): the pose RavenBody draws, the tweens and
// hops that move it, and the habits raven-mood.js times.
// - breathing, and the sheen's drift while awake;
// - blinks, looks (now and then a double-take), ruffles and preens;
// - the pointer: watched, hopped at and pecked at (Mood.watchState);
// - sleep after dark with its head tucked in, and waking;
// - the caw itself (call), and rousing it for one (rouse);
// - a bob of the head (bob), which only the niri bar's raven asks for.
//
// The owner keeps its own clock and calls tick(dt) (dt already clamped), at
// `need` Hz, or idleHz while that is 0. It says where the bird is (k, homeX,
// perchY and how far it may hop either way), where the pointer is, whether
// it is night, and the rate fast motion needs (fastHz: a Timer's 60 on the
// niri bar, 1000 on Umbriel for the display's own). `moving` asks for
// fastHz for motion of the owner's own, which it steps in stepped(t), each
// tick between the hop and the habits.
import QtQuick
import "raven-mood.js" as Mood

QtObject {
    id: life

    // Set by the owner.
    property int fastHz: 60
    readonly property int idleHz: 5
    property bool moving: false
    property bool night: false
    property bool debug: false
    // RavenBody's scale, and the perch in the owner's coordinates: the line
    // its feet grip, the x of its feet at home, and how far it may hop from
    // there either way (px).
    property real k: 1
    property real homeX: 0
    property real perchY: 0
    property real reachLeft: 0
    property real reachRight: 0
    // The pointer, in the same coordinates (NaN when it isn't near), and
    // when it last really moved (Date.now()).
    property real pointerX: NaN
    property real pointerY: NaN
    property real movedAt: 0

    signal stepped(real t)

    // The pose (RavenBody's), and where the bird stands: hopX from home,
    // hopY up from the perch, facing 1 left and -1 right.
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
    property real facing: 1

    // Seconds of life (the clock's, so it stops while the clock does).
    property real t: 0
    property var tweens: []
    property var events: []
    property var hop: null
    property real nextBlink: 3
    property real nextLook: 5
    property real nextRuffle: 0
    property real nextPreen: 0
    // A long action (caw, catch, preen, ruffle, peck) holds off the idle
    // habits until then.
    property real busyUntil: 0
    property var watch: null
    property bool asleep: false
    property real awakeUntil: 0
    // The clock rate it needs now (0: idleHz).
    property int need: 0

    Component.onCompleted: {
        nextRuffle = debug ? 10 : Mood.nextIdle("ruffle", 0, Math.random) / 1000;
        nextPreen = debug ? 20 : Mood.nextIdle("preen", 0, Math.random) / 1000;
    }

    // Tweens: ease `prop` to `to` over `dur` s, starting `delay` s from now;
    // `hz` is the clock rate it needs. A tween that starts takes its property
    // over from any running one.
    function tween(prop, to, dur, delay, hz) {
        tweens.push({ p: prop, to: to, dur: Math.max(dur, 0.001), at: t + (delay || 0), from: NaN, hz: hz || 30, dead: false });
        rate();
    }
    function after(delay, fn) {
        events.push({ at: t + delay, fn: fn });
        rate();
    }
    // A new behaviour: what was still to come of the last one (a look's
    // return, a caw's lingering gaze) gives way; blinks go on.
    function interrupt() {
        tweens = tweens.filter(w => w.at <= t || w.p === "blink");
        // Feathers lifted in a preen settle whatever comes next.
        if (preening > 0)
            tween("preening", 0, 0.2);
    }
    function busy(secs) {
        busyUntil = Math.max(busyUntil, t + secs);
    }
    // A hop from hopX to x (offset from home), `h` px high, over `dur` s; at
    // `turnTo` (if given) it turns round in the air; onLand (if given) runs
    // as it lands.
    function hopTo(x, h, dur, turnTo, onLand) {
        hop = { x0: hopX, x1: x, h: h, at: t, dur: dur, f0: facing, f1: turnTo ?? facing, onLand: onLand ?? null };
        rate();
    }

    // The clock's rate: fastHz during a hop, the owner's motion or a fast
    // tween, 30 Hz for the head's moves, idleHz otherwise. It goes up a tick
    // ahead of what is due.
    function rate() {
        let hz = 0;
        if (hop || moving) {
            hz = fastHz;
        } else {
            for (const w of tweens)
                if (!w.dead && t >= w.at - 1.2 / idleHz)
                    hz = Math.max(hz, Math.min(w.hz, fastHz));
            for (const e of events)
                if (t >= e.at - 1.2 / idleHz)
                    hz = Math.max(hz, 30);
        }
        need = hz;
    }

    // dt: seconds since the last tick, already clamped by the clock.
    function tick(dt) {
        life.t += dt;
        const t = life.t;

        // The slow life: breath always, the sheen's drift while awake.
        breath = 1 + 0.0075 * (1 - Math.cos(2 * Math.PI * t / 4));
        if (!asleep) {
            sheen = 0.16 + 0.06 * Math.sin(2 * Math.PI * t / 23);
            sheenShift = 0.15 * (1 + Math.sin(2 * Math.PI * t / 41));
        }

        const due = events.filter(e => t >= e.at);
        if (due.length > 0) {
            events = events.filter(e => t < e.at);
            for (const e of due)
                e.fn();
        }

        for (const w of tweens) {
            if (w.dead || t < w.at)
                continue;
            if (isNaN(w.from)) {
                w.from = life[w.p];
                for (const o of tweens)
                    if (o !== w && o.p === w.p && !isNaN(o.from))
                        o.dead = true;
            }
            const u = Math.min((t - w.at) / w.dur, 1);
            life[w.p] = w.from + (w.to - w.from) * u * u * (3 - 2 * u);
            if (u >= 1)
                w.dead = true;
        }
        tweens = tweens.filter(w => !w.dead);

        stepHop(t);
        stepped(t);
        habits(t, dt);
        rate();
    }

    function stepHop(t) {
        const h = hop;
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
            if (h.f1 !== h.f0) {
                const q = Math.min(Math.max((p - 0.3) / 0.35, 0), 1);
                facing = h.f0 * Math.cos(Math.PI * q * q * (3 - 2 * q));
            }
        }
        if (u >= 1) {
            hop = null;
            hopX = h.x1;
            hopY = 0;
            tuck = 0;
            wingLift = 0;
            lean = 0;
            tailAngle = 0;
            facing = h.f1;
            if (h.onLand)
                h.onLand();
        }
    }

    // Habits, the pointer and sleep.
    function habits(t, dt) {
        const free = t >= busyUntil && !hop;
        const dark = night && t >= awakeUntil;
        if (free && dark && !asleep)
            sleep();
        else if (free && !dark && asleep)
            wake();
        if (asleep)
            return;

        if (t >= nextBlink) {
            nextBlink = Mood.nextIdle("blink", t * 1000, Math.random) / 1000;
            tween("blink", 1, 0.07);
            tween("blink", 0, 0.1, 0.12);
        }

        // The pointer, unless something else holds its attention.
        const watching = watch && watch.phase !== "idle";
        if (free || watching) {
            const p = !isNaN(pointerX) ? { x: pointerX, y: pointerY, still: Date.now() - movedAt } : null;
            const was = watch?.phase ?? "idle";
            watch = Mood.watchState(watch, p, dt * 1000);
            if (watch.phase !== was)
                onWatch(was, watch);
            if (watch.phase !== "idle")
                return;
        }
        if (!free)
            return;

        if (t >= nextPreen) {
            nextPreen = debug ? t + 20 : Mood.nextIdle("preen", t * 1000, Math.random) / 1000;
            preen();
        } else if (t >= nextRuffle) {
            nextRuffle = debug ? t + 20 : Mood.nextIdle("ruffle", t * 1000, Math.random) / 1000;
            ruffle();
        } else if (t >= nextLook) {
            nextLook = Mood.nextIdle("look", t * 1000, Math.random) / 1000;
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
    // the feathers of the back, which part and lift round it, for ~2 s. The
    // head stays in front of the wing (unlike asleep, tucked under it).
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
        after(delay + dur / 2, () => life.headTucked = to < 0);
    }

    readonly property real nightPuffAmount: 0.08
    function nightPuff() {
        return asleep ? nightPuffAmount : 0;
    }

    function sleep() {
        interrupt();
        asleep = true;
        tween("puff", nightPuffAmount, 1.2);
        turnHead(-1, 0.4, 0);
        tween("headAngle", 40, 0.8, 0.3);
        tween("headDrop", 5, 0.8, 0.3);
        tween("lid", 1, 0.3, 0.6);
        tween("sheen", 0.12, 1.2);
    }

    function wake() {
        interrupt();
        asleep = false;
        tween("lid", 0, 0.15);
        tween("headAngle", 0, 0.3);
        tween("headDrop", 0, 0.3);
        turnHead(1, 0.3, 0.1);
        tween("puff", 0, 0.8);
        busy(0.5);
    }

    // The head's position (near the eye), in the owner's coordinates.
    function headPos() {
        return { x: homeX + hopX - 10 * k, y: perchY - 43 * k };
    }

    // Something wants its attention (a caw, a trinket): awake for the next
    // 20 s (woken if asleep), its eye off the pointer, and the last
    // behaviour cut short. Returns how long it takes to lift its head out
    // of the wing first.
    function rouse() {
        const d = asleep ? 0.45 : 0;
        if (asleep || night) {
            awakeUntil = t + 20;
            if (asleep)
                wake();
        }
        watch = null;
        interrupt();
        return d;
    }

    // The caw, `d` s from now (the owner has turned the head to what it
    // caws at): gape, hackles up, a bob of the body and a flick of the
    // tail, and the two arcs.
    function call(d) {
        tween("beakOpen", 1, 0.08, d + 0.15, fastHz);
        tween("hackles", 1, 0.12, d + 0.15, fastHz);
        tween("lean", -6, 0.1, d + 0.15, fastHz);
        tween("tailAngle", 7, 0.1, d + 0.15, fastHz);
        tween("caw", 1, 0.75, d + 0.17, fastHz);
        tween("beakOpen", 0, 0.16, d + 0.48, fastHz);
        tween("lean", 0, 0.3, d + 0.4, fastHz);
        tween("tailAngle", 0, 0.3, d + 0.4, fastHz);
        tween("hackles", 0, 0.6, d + 0.6);
        after(d + 0.95, () => life.caw = 0);
    }

    // The pointer: watch, hop at it, peck the air, settle back.
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

    // What bob() needs to know: may the head be bobbed now (see beat.js's
    // bobAllowed, which the niri bar's raven asks)?
    function bobState() {
        return {
            asleep: asleep,
            busy: t < busyUntil,
            hop: hop !== null,
            watching: watch !== null && watch.phase !== "idle",
            headBusy: tweens.some(w => !w.dead && (w.p === "headAngle" || w.p === "headDrop" || w.p === "headFlip"))
        };
    }

    // A quick bob of the head, to a beat: down a few px with a small forward
    // tilt in ~60 ms, back in ~70 (fast ticks only for that long). Only the
    // niri bar calls it, and only once bobState() says the head is free.
    function bob() {
        tween("headDrop", 2.2, 0.05, 0, fastHz);
        tween("headAngle", -7, 0.05, 0, fastHz);
        tween("headDrop", 0, 0.07, 0.05, fastHz);
        tween("headAngle", 0, 0.07, 0.05, fastHz);
    }

    // Back on its perch at once, at rest, with nothing to come: for an owner
    // whose clock stopped mid-action.
    function perch() {
        tweens = [];
        events = [];
        hop = null;
        busyUntil = t;
        hopX = 0;
        hopY = 0;
        facing = 1;
        tuck = 0;
        wingLift = 0;
        lean = 0;
        tailAngle = 0;
        beakOpen = 0;
        hackles = 0;
        caw = 0;
        headAngle = 0;
        headFlip = 1;
        headDrop = 0;
        headTucked = false;
        preening = 0;
        gazeX = 0;
        gazeY = 0;
        need = 0;
    }
}
