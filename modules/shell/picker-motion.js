.pragma library
// The wallpaper picker's motion: small springs stepped on the picker's own
// clock (FRAME_MS, under 60 Hz), which runs only while something moves.
// RISE lifts the selected card with a little overshoot, then lets it settle;
// GLIDE eases the carousel's offset back to zero without overshoot.

var FRAME_MS = 17;

// Stiffness k and damping c, per unit mass: c < 2*sqrt(k) overshoots.
var RISE = { k: 230, c: 19 };
var GLIDE = { k: 400, c: 2 * Math.sqrt(400) };

// How close counts as there: levels are 0..1, the glide offset is in pixels.
var LEVEL_EPS = 0.002;
var SHIFT_EPS = 0.5;

// Advances a spring at x with speed v toward target by dtMs; returns {x, v}.
// A long gap (a dropped frame, the first tick) counts as one frame's worth at
// most, and it steps in small slices so it stays stable.
function step(x, v, target, dtMs, spring) {
    if (x === target && v === 0)
        return { x: x, v: v };
    var left = Math.min(Math.max(dtMs, 0), 2 * FRAME_MS) / 1000;
    while (left > 0) {
        var h = Math.min(left, 0.004);
        v += (spring.k * (target - x) - spring.c * v) * h;
        x += v * h;
        left -= h;
    }
    return { x: x, v: v };
}

function atRest(x, v, target, eps) {
    return Math.abs(x - target) < eps && Math.abs(v) < eps * 10;
}
