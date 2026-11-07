.pragma library
// How the koi in the bottom bar swim. A koi is a head that steers toward a
// target with a limited turn rate, and a chain of spine points that follows
// it; a travelling wave along the chain makes the tail beat. Pure functions on
// plain objects, so tests can run them in node.

var SEGMENTS = 8;
// Max turn rate, rad/s, reached at TURN_SPEED px/s; slower fish turn slower.
var TURN = 2.4;
var TURN_SPEED = 14;
// How fast speed eases toward the asked-for speed, 1/s.
var ACCEL = 4;

function create(len, x, y, a) {
    var k = { len: len, x: x, y: y, a: a, v: 0, phase: 0, pts: [] };
    var seg = len / (SEGMENTS - 1);
    for (var i = 0; i < SEGMENTS; i++)
        k.pts.push({ x: x - Math.cos(a) * seg * i, y: y - Math.sin(a) * seg * i });
    return k;
}

function wrap(a) {
    return Math.atan2(Math.sin(a), Math.cos(a));
}

// One tick toward (tx, ty) at up to `speed` px/s: turn, ease the speed, move.
// It slows as it arrives, and while it is still turning to face the target.
function steer(k, dt, tx, ty, speed) {
    var dx = tx - k.x, dy = ty - k.y, dist = Math.hypot(dx, dy);
    var diff = dist > 1e-6 ? wrap(Math.atan2(dy, dx) - k.a) : 0;
    var rate = TURN * Math.max(0.15, Math.min(1, k.v / TURN_SPEED));
    var turn = Math.max(-rate * dt, Math.min(rate * dt, diff));
    k.a = wrap(k.a + turn);
    var want = Math.min(speed, dist * 1.5) * (1 - 0.5 * Math.abs(diff) / Math.PI);
    k.v += (want - k.v) * Math.min(1, dt * ACCEL);
    k.x += Math.cos(k.a) * k.v * dt;
    k.y += Math.sin(k.a) * k.v * dt;
    // The tail beats faster the faster it swims.
    k.phase += dt * (2.2 + k.v * 0.22);
    return k;
}

function keepIn(k, pool) {
    k.x = Math.max(pool.x, Math.min(pool.x + pool.w, k.x));
    k.y = Math.max(pool.y, Math.min(pool.y + pool.h, k.y));
}

// The spine trails the head: each point is pulled to one segment's length
// from the one before it.
function follow(k) {
    var seg = k.len / (SEGMENTS - 1);
    k.pts[0] = { x: k.x, y: k.y };
    for (var i = 1; i < SEGMENTS; i++) {
        var p = k.pts[i - 1], q = k.pts[i];
        var dx = q.x - p.x, dy = q.y - p.y, d = Math.hypot(dx, dy);
        if (d < 1e-6) { dx = -Math.cos(k.a); dy = -Math.sin(k.a); d = 1; }
        k.pts[i] = { x: p.x + dx / d * seg, y: p.y + dy / d * seg };
    }
}

// The drawn spine: the trailing chain plus a sideways wave that grows toward
// the tail. Each point carries the body's direction there, `a`, pointing
// head-ward.
function pose(k) {
    var n = k.pts.length, out = [];
    var amp = 0.09 * k.len * Math.min(1, 0.35 + k.v / 40);
    for (var i = 0; i < n; i++) {
        var p = k.pts[i];
        var prev = k.pts[Math.max(0, i - 1)], next = k.pts[Math.min(n - 1, i + 1)];
        var a = i === 0 ? k.a : Math.atan2(prev.y - next.y, prev.x - next.x);
        var u = i / (n - 1);
        var off = amp * Math.pow(u, 1.5) * Math.sin(k.phase - i * 0.9);
        out.push({ x: p.x - Math.sin(a) * off, y: p.y + Math.cos(a) * off, a: a });
    }
    // Directions again after the wave, so segments line up with the bent body.
    for (var j = 1; j < n; j++) {
        var b = out[j - 1], c = out[Math.min(n - 1, j + 1)];
        out[j].a = Math.atan2(b.y - c.y, b.x - c.x);
    }
    return out;
}

// Width of the body at spine point i of n, for a koi `w` px across: a rounded
// head, widest just behind it, tapering to a thin tail stalk.
function bodyWidth(i, n, w) {
    var u = i / (n - 1);
    if (u < 0.25)
        return w * (0.72 + 0.28 * Math.sin(u / 0.25 * Math.PI / 2));
    return w * (1 - 0.75 * Math.pow((u - 0.25) / 0.75, 1.3));
}

function wander(rand, pool) {
    return { x: pool.x + rand() * pool.w, y: pool.y + rand() * pool.h };
}

// The next place to swim to: usually further on the way it is heading (the
// pool is a thin strip, so a target behind means a tight U-turn), sometimes
// back the other way, and always back when a wall is close ahead.
function cruise(k, rand, pool) {
    var dir = Math.cos(k.a) >= 0 ? 1 : -1;
    if (rand() < 0.15)
        dir = -dir;
    var lo = pool.x, hi = pool.x + pool.w;
    if ((dir > 0 ? hi - k.x : k.x - lo) < 60)
        dir = -dir;
    var room = dir > 0 ? hi - k.x : k.x - lo;
    var d = 60 + rand() * Math.max(0, Math.min(room, 300) - 60);
    return { x: k.x + dir * d, y: pool.y + rand() * pool.h };
}

// Somewhere to dart to, away from (px, py). The pool is a thin strip, so it
// flees mostly sideways; if a wall is in the way it turns back past the point.
function flee(k, px, py, pool) {
    var dir = Math.abs(k.x - px) > 2 ? Math.sign(k.x - px) : (Math.cos(k.a) >= 0 ? 1 : -1);
    function at(d) {
        return {
            x: Math.max(pool.x, Math.min(pool.x + pool.w, k.x + d * 110)),
            y: Math.max(pool.y, Math.min(pool.y + pool.h, k.y + Math.sign(k.y - py || 1) * pool.h * 0.6))
        };
    }
    var t = at(dir);
    var away = function (q) { return Math.hypot(q.x - px, q.y - py); };
    if (away(t) < Math.hypot(k.x - px, k.y - py) + 30)
        t = at(-dir);
    return t;
}

// Drawn to the middle (the music, under the top pill): the same target, its
// distance from cx scaled by `spread` (1 leaves it, 0 puts it on cx).
function gather(pt, cx, spread) {
    return { x: cx + (pt.x - cx) * spread, y: pt.y };
}
