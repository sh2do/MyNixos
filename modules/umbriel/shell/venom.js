.pragma library
// The hanging viper's venom (HangingViper.qml): how fast it drips, read from
// the CPU load, and each drop's life. Pure functions on plain objects so
// tests/venom-test.js can run them in node.
//
// A drop: a bead swells on the fang tip, necks into a thread, snaps, falls
// with gravity and splashes on the top edge of the window below it, or fades
// out with a faint ring when there is none.
//   bead -> thread -> fall -> splash | fade -> gone
// Coordinates are the caller's (y down); the windows are {x, y, w, h} in the
// same coordinates.
//
// A drop never falls across a window's content: one that lets go over a
// window (the fang hangs inside its rectangle) sags at most BLOCKED_FALL px
// and fades with a tiny ring. Otherwise it lands on the highest top edge
// below it, which is also the first window it meets whatever their stacking
// (Umbriel's IPC reports no z-order): it falls straight down from empty
// desktop, and enters a window only through its top edge.

var GRAVITY = 1400;      // px/s²
var BEAD_FOR = 1.2;      // s, the default swell
var THREAD_FOR = 0.3;    // s
var SPLASH_FOR = 0.8;    // s
var FADE_FOR = 0.6;      // s
var BEAD_R = 3.2;        // px, a full bead's radius
var THREAD_LEN = 9;      // px the bead sags before it snaps
var SNAP_SPEED = 30;     // px/s, downward, as it lets go
var BLOCKED_FALL = 22;   // px a drop over a window's content may sag

// Milliseconds between drops: 4 s when calm, 0.6 s at full load, and half
// as often at night (`night`, 0..1, Palette.night).
function dripInterval(load, night) {
    var l = Math.min(Math.max(+load || 0, 0), 1);
    var n = Math.min(Math.max(+night || 0, 0), 1);
    return Math.round((4000 - 3400 * l) * (1 + n));
}

// The viper at night `night` (0..1): its sway's speed, how much of its
// hanging length it draws up (`lift`) and its eye's brightness.
function nightHang(night) {
    var n = Math.min(Math.max(+night || 0, 0), 1);
    return { rate: 1 - 0.5 * n, lift: 0.3 * n, eye: 1 - 0.4 * n };
}

// The viper's own night, eased toward the shell's factor on its clock (the
// shell's moves in 2 s steps): v moves at most dt / HUSH_FOR toward `to`.
var HUSH_FOR = 2;
function toward(v, to, dt) {
    var step = Math.max(dt, 0) / HUSH_FOR;
    return v < to ? Math.min(to, v + step) : Math.max(to, v - step);
}

// How long a bead may swell when drops come every `ms`: the full 1.2 s when
// calm, shorter in a quick patter so one bead has snapped before the next.
function beadTime(ms) {
    return Math.min(Math.max(ms / 1000 - THREAD_FOR - 0.05, 0.25), BEAD_FOR);
}

// The aggregate `cpu` line of /proc/stat as {idle, total} ticks, or null.
function sampleOf(text) {
    if (typeof text !== "string")
        return null;
    var m = /^cpu\s+(.*)$/m.exec(text);
    if (!m)
        return null;
    var f = m[1].trim().split(/\s+/);
    if (f.length < 4)
        return null;
    var total = 0;
    // user nice system idle iowait irq softirq steal; guest time is already
    // inside user.
    for (var i = 0; i < Math.min(f.length, 8); i++) {
        var v = Number(f[i]);
        if (!isFinite(v))
            return null;
        total += v;
    }
    var idle = Number(f[3]) + (f.length > 4 ? Number(f[4]) : 0);
    return { idle: idle, total: total };
}

// Load (0..1) between the previous sample and this read of /proc/stat; the
// new sample is returned for the next call. Garbage gives load 0 and no
// sample, so the drip falls back to calm.
function parseLoad(prev, text) {
    var s = sampleOf(text);
    if (!s)
        return { load: 0, sample: null };
    if (!prev || !(s.total > prev.total) || s.idle < prev.idle)
        return { load: 0, sample: s };
    var load = 1 - (s.idle - prev.idle) / (s.total - prev.total);
    return { load: Math.min(Math.max(load, 0), 1), sample: s };
}

// Is (x, y) inside any window?
function covered(x, y, windows) {
    for (var i = 0; i < (windows || []).length; i++) {
        var w = windows[i];
        if (x >= w.x && x < w.x + w.w && y >= w.y && y < w.y + w.h)
            return true;
    }
    return false;
}

// The y of the top edge of the highest window under x whose top is below
// y0, or null.
function landing(x, y0, windows) {
    var best = null;
    for (var i = 0; i < (windows || []).length; i++) {
        var w = windows[i];
        if (x >= w.x && x < w.x + w.w && w.y > y0 && (best === null || w.y < best))
            best = w.y;
    }
    return best;
}

// A new bead on a fang tip at (x, anchorY). While it hangs, the caller moves
// x and anchorY with the fang.
function newDrop(x, anchorY, beadFor) {
    return {
        phase: "bead", t: 0,
        x: x, anchorY: anchorY, y: anchorY, y0: anchorY, vy: 0,
        beadFor: beadFor > 0 ? beadFor : BEAD_FOR,
        swell: 0, stretch: 0, blocked: false
    };
}

function ease(u) {
    var t = Math.min(Math.max(u, 0), 1);
    return t * t * (3 - 2 * t);
}

// Advance a drop by dt seconds (clamped to 50 ms, so a stall never throws it
// through a window). y is the drop's centre; in the splash and fade it is
// where it landed. Mutates and returns the drop.
function dropStep(drop, dt, windows, fadeAt) {
    var d = drop;
    var s = Math.min(Math.max(dt, 0), 0.05);
    d.t += s;
    if (d.phase === "bead") {
        // A cube root of the volume: it grows fast at first, then fills out.
        d.swell = Math.pow(Math.min(d.t / d.beadFor, 1), 0.6);
        d.y = d.anchorY + BEAD_R * (0.4 + 0.6 * d.swell);
        if (d.t >= d.beadFor) {
            d.phase = "thread";
            d.t = 0;
        }
    } else if (d.phase === "thread") {
        d.stretch = ease(d.t / THREAD_FOR);
        d.y = d.anchorY + BEAD_R + THREAD_LEN * d.stretch;
        if (d.t >= THREAD_FOR) {
            d.phase = "fall";
            d.t = 0;
            d.y0 = d.y;
            d.vy = SNAP_SPEED;
            d.blocked = covered(d.x, d.y, windows);
        }
    } else if (d.phase === "fall") {
        var from = d.y;
        d.vy += GRAVITY * s;
        d.y += d.vy * s;
        if (d.blocked) {
            if (d.y >= d.y0 + BLOCKED_FALL) {
                d.y = d.y0 + BLOCKED_FALL;
                d.phase = "fade";
                d.t = 0;
            }
            return d;
        }
        // Measured from where it was, so a window that opens under a drop
        // already past its top doesn't pull the drop back up.
        var land = landing(d.x, from, windows);
        if (land !== null && d.y >= land) {
            d.y = land;
            d.phase = "splash";
            d.t = 0;
        } else if (land === null && d.y >= fadeAt) {
            d.y = fadeAt;
            d.phase = "fade";
            d.t = 0;
        }
    } else if (d.phase === "splash") {
        if (d.t >= SPLASH_FOR)
            d.phase = "gone";
    } else if (d.phase === "fade") {
        if (d.t >= FADE_FOR)
            d.phase = "gone";
    }
    return d;
}

// A clock's dt, clamped against stalls at twice its own interval, so motion
// keeps its speed at any rate.
function clockStep(dt, hz) {
    return Math.min(Math.max(dt, 0), 2 / hz);
}
