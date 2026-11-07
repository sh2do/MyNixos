.pragma library

// The raven's moods, pure (tests/raven-mood-test.js). Shared with the niri
// bar's raven, so nothing here knows about Umbriel.
//
// Times are ms unless named otherwise; clockStep works in seconds, like the
// clocks that call it.

// After dark (21:00-06:00, local time) it sleeps.
function isNight(date) {
    var h = date.getHours();
    return h >= 21 || h < 6;
}

// How long each idle habit waits between turns, [shortest, longest].
var IDLE = {
    blink: [4000, 9000],
    look: [6000, 14000],
    ruffle: [120000, 240000],
    preen: [300000, 600000]
};

// When the next `kind` is due; rand() is in [0, 1).
function nextIdle(kind, now, rand) {
    var r = IDLE[kind];
    return now + r[0] + (r[1] - r[0]) * Math.min(Math.max(rand(), 0), 1);
}

// The pointer: watched after resting WATCH ms near the raven, hopped at
// after HOP_AT, then a hop, a peck at the air and a settle back.
var WATCH = 2000;
var HOP_AT = 5000;
var HOP = 400;
var PECK = 300;
var SETTLE = 600;

// state: the last result (or null); pointer: {x, y, still} while it is in
// the raven's window, `still` being ms since it last moved, else null; dt:
// ms since the last call.
// Returns {phase: "idle"|"watch"|"hop"|"peck"|"settle", target, t, spent}:
// t is ms into a hop, peck or settle, which run to the end whatever the
// pointer does; `spent` keeps it from hopping at the same resting pointer
// twice (it waits for the pointer to move).
function watchState(state, pointer, dt) {
    var s = state || { phase: "idle", target: null, t: 0, spent: false };
    var moved = !pointer || pointer.still < WATCH;
    var spent = s.spent && !moved;
    var here = pointer ? { x: pointer.x, y: pointer.y } : null;
    var t = s.t + dt;
    switch (s.phase) {
    case "hop":
        if (t >= HOP)
            return { phase: "peck", target: s.target, t: t - HOP, spent: true };
        return { phase: "hop", target: s.target, t: t, spent: true };
    case "peck":
        if (t >= PECK)
            return { phase: "settle", target: s.target, t: t - PECK, spent: true };
        return { phase: "peck", target: s.target, t: t, spent: true };
    case "settle":
        if (t >= SETTLE)
            return { phase: "idle", target: null, t: 0, spent: !moved };
        return { phase: "settle", target: s.target, t: t, spent: true };
    }
    // idle or watch
    if (moved || spent)
        return { phase: "idle", target: null, t: 0, spent: spent };
    if (pointer.still >= HOP_AT)
        return { phase: "hop", target: here, t: 0, spent: true };
    return { phase: "watch", target: here, t: 0, spent: false };
}

// The hoard on the status row: at most HOARD trinkets, each {at, slot,
// opacity}, fading over FADE ms, oldest first.
var HOARD = 3;
var FADE = 600000;

function hoardAdd(hoard, now) {
    var kept = hoard.slice(Math.max(0, hoard.length - (HOARD - 1)));
    var used = [];
    for (var i = 0; i < kept.length; i++)
        used.push(kept[i].slot);
    var slot = 0;
    while (used.indexOf(slot) >= 0)
        slot++;
    return kept.concat([{ at: now, slot: slot, opacity: 1 }]);
}

function hoardStep(hoard, now) {
    var out = [];
    for (var i = 0; i < hoard.length; i++) {
        var o = 1 - (now - hoard[i].at) / FADE;
        if (o > 0)
            out.push({ at: hoard[i].at, slot: hoard[i].slot, opacity: Math.min(o, 1) });
    }
    return out;
}

// A clock's step in seconds, clamped to two of its own ticks so a stall
// (or a paused clock starting again) doesn't jump the motion.
function clockStep(dt, hz) {
    return Math.min(Math.max(dt, 0), 2 / hz);
}
