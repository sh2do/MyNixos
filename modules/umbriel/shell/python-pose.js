.pragma library
// The python's pose, after the overview board: three flat elliptical coils
// stacked into a soft cone just above the status row and left of it, the
// neck rising from the top coil's left end with the head beside it, level
// with the top coil and facing left, and the tail curling off to the bottom
// left. Pure functions on plain objects so tests can run them in node.
//
// The body is one helix, climbing on the left. From the tail: up into the
// bottom coil's left end, round its far side (the back half) to its right
// end, back along its near side (the front half), climbing at the left in a
// short diagonal into the next coil up. The top coil's front climbs into the
// neck the same way.
//
// Every chain runs tail to head, so each coil's back ends where its front
// starts. Serpent wants neck first: bodyChains() gives them in that order.
//
// Breath is applied exactly as the shell applies it: each coil's back and
// front scale together about that coil's centre (the neck with the top
// coil), and the tail moves with the bottom coil's left end.

var BODY_WIDTH = 22;
// Breath scales each coil by 1 + BREATH * breath about its centre: about
// 2 px at the bottom coil's ends.
var BREATH = 0.017;
// How far coil centrelines keep from the status row's edge.
var CLEAR = BODY_WIDTH / 2 + 1.5;
// Points per half coil.
var HALF = 17;
// The coils' radii, bottom up: the overview board's 95x26, 80x22 and 62x17
// at its 18 px body, scaled to this body.
var RADII = [[116, 32], [98, 27], [76, 21]];

function smooth(a, b, x) {
    var t = Math.min(Math.max((x - a) / (b - a), 0), 1);
    return t * t * (3 - 2 * t);
}

// The point at angle th (screen coordinates, y down: sin < 0 is the far side).
function ringAt(r, th) {
    return { x: r.cx + r.rx * Math.cos(th), y: r.cy + r.ry * Math.sin(th) };
}

// The area the python must stay inside: the window, which by default ends
// where the status row's 28 px band does (20 px right of it, 14 below).
function areaFor(box, area) {
    return area || { w: box.x + box.w + 28, h: box.y + box.h / 2 + 28 };
}

// The coils at rest. rings[3] is where the top coil's front ends: a little
// higher, where the neck starts.
function rings(box, area) {
    var A = areaFor(box, area), S = 1 + BREATH;
    var r0 = { rx: RADII[0][0], ry: RADII[0][1] };
    // Right end inside the window; near side clear above the row.
    r0.cx = A.w - 4 - BODY_WIDTH / 2 - r0.rx * S;
    r0.cy = box.y - CLEAR - r0.ry * S - 1;
    var r1 = { rx: RADII[1][0], ry: RADII[1][1], cx: r0.cx, cy: r0.cy - 0.846 * r0.ry };
    var r2 = { rx: RADII[2][0], ry: RADII[2][1], cx: r0.cx, cy: r1.cy - 0.909 * r1.ry };
    var r3 = { rx: 0.88 * r2.rx, ry: 0.8 * r2.ry, cx: r2.cx, cy: r2.cy - 0.5 * r2.ry };
    return [r0, r1, r2, r3];
}

function scaled(points, r, s) {
    var out = new Array(points.length);
    for (var i = 0; i < points.length; i++)
        out[i] = { x: r.cx + (points[i].x - r.cx) * s, y: r.cy + (points[i].y - r.cy) * s };
    return out;
}

// box: the status row's rectangle in the window's coordinates; area: the
// window ({w, h}, optional). t is accepted for the plan's signature; the
// coils don't drift.
function coils(box, t, breath, area) {
    var R = rings(box, area);
    var s = 1 + BREATH * (breath || 0);
    var back = [], front = [];
    for (var k = 0; k < 3; k++) {
        var a = R[k], b = R[k + 1];
        var bk = [], fr = [];
        for (var i = 0; i < HALF; i++) {
            var f = i / (HALF - 1);
            // Far side: left end, over the top, to the right end.
            bk.push(ringAt(a, Math.PI + Math.PI * f));
            // Near side: right end, along the bottom, to the left, where it
            // climbs into the next coil up.
            var th = Math.PI * f;
            var p = ringAt(a, th), q = ringAt(b, th);
            var w = smooth(0.55, 1, -Math.cos(th));
            fr.push({ x: p.x + (q.x - p.x) * w, y: p.y + (q.y - p.y) * w });
        }
        back.push(scaled(bk, a, s));
        front.push(scaled(fr, a, s));
    }
    var r0 = R[0], r2 = R[2], r3 = R[3];
    var L3 = { x: r3.cx - r3.rx, y: r3.cy };
    // The neck rises up and left from the top coil's left end; the head sits
    // just beyond, level with the top coil.
    var neck = [
        L3,
        { x: L3.x - 3, y: L3.y - 9 },
        { x: L3.x - 11, y: L3.y - 16 },
        { x: L3.x - 22, y: L3.y - 18 }
    ];
    // The tail curls off to the bottom left, its tip turned back up.
    var L0 = { x: r0.cx - r0.rx, y: r0.cy };
    var tail = [
        { x: L0.x - 46, y: L0.y + 44 },
        { x: L0.x - 40, y: L0.y + 60 },
        { x: L0.x - 20, y: L0.y + 58 },
        { x: L0.x - 5, y: L0.y + 30 },
        L0
    ];
    return {
        back: back,
        front: front,
        neck: scaled(neck, r2, s),
        tail: tail.map(function (p) { return { x: p.x - r0.rx * (s - 1), y: p.y }; }),
        rings: [R[0], R[1], R[2]]
    };
}

function length(points) {
    var l = 0;
    for (var i = 1; i < points.length; i++)
        l += Math.sqrt((points[i].x - points[i - 1].x) * (points[i].x - points[i - 1].x) + (points[i].y - points[i - 1].y) * (points[i].y - points[i - 1].y));
    return l;
}

// The chains neck first, each reversed to run head to tail, with the share of
// the body each covers by length (u0..u1, 0 at the head), which coil it
// breathes with, and whether it is a near half.
function bodyChains(c) {
    var list = [
        { name: "neck", points: c.neck, ring: 2, near: true },
        { name: "front2", points: c.front[2], ring: 2, near: true },
        { name: "back2", points: c.back[2], ring: 2, near: false },
        { name: "front1", points: c.front[1], ring: 1, near: true },
        { name: "back1", points: c.back[1], ring: 1, near: false },
        { name: "front0", points: c.front[0], ring: 0, near: true },
        { name: "back0", points: c.back[0], ring: 0, near: false },
        { name: "tail", points: c.tail, ring: 0, near: false }
    ];
    var total = 0;
    for (var i = 0; i < list.length; i++) {
        list[i].points = list[i].points.slice().reverse();
        list[i].len = length(list[i].points);
        total += list[i].len;
    }
    var at = 0;
    for (var j = 0; j < list.length; j++) {
        list[j].order = j;
        list[j].u0 = at / total;
        at += list[j].len;
        list[j].u1 = at / total;
    }
    return list;
}

// Width scale along the body, u = 0 at the head to 1 at the tail tip: a
// slimmer neck, then full width round all three coils, tapering only along
// the tail (from tailFrom) to a blunt tip. bulges: [{u, size}], as
// serpent-spine.js widthAt takes them.
function widthAt(u, tailFrom, bulges) {
    var w = 0.85 + 0.15 * smooth(0, 0.08, u) - 0.86 * Math.pow(smooth(tailFrom, 1, u), 0.8);
    for (var i = 0; i < (bulges ? bulges.length : 0); i++) {
        var d = (u - bulges[i].u) / 0.035;
        w += bulges[i].size * Math.exp(-d * d);
    }
    return w;
}

// The neck's head end as a Serpent sample: tangent pointing into the body.
function neckEnd(neck) {
    var a = neck[neck.length - 1], b = neck[neck.length - 2];
    var tx = b.x - a.x, ty = b.y - a.y, l = Math.sqrt(tx * tx + ty * ty) || 1;
    return { x: a.x, y: a.y, tx: tx / l, ty: ty / l, s: 0 };
}

// How far the head end rises at lift 1, in px.
var LIFT = 34;

// The neck (tail to head, as coils() gives it) bent from its root: lifted,
// turned by look (about -1..1), and, with target and k > 0, stretched toward
// target so that at k = 1 the head end is on it.
function neckFor(rest, look, lift, target, k) {
    var n = rest.length, root = rest[0], out = new Array(n);
    var turn = (look || 0) * 0.12;
    for (var i = 0; i < n; i++) {
        var f = i / (n - 1), w = Math.pow(f, 1.6);
        var x = rest[i].x + (lift || 0) * 6 * w, y = rest[i].y - (lift || 0) * LIFT * w;
        var a = turn * w, dx = x - root.x, dy = y - root.y;
        x = root.x + dx * Math.cos(a) - dy * Math.sin(a);
        y = root.y + dx * Math.sin(a) + dy * Math.cos(a);
        if (target && k > 0) {
            var m = k * Math.pow(f, 0.7);
            x += (root.x + (target.x - root.x) * f - x) * m;
            y += (root.y + (target.y - root.y) * f - y) * m;
        }
        out[i] = { x: x, y: y };
    }
    return out;
}

// Where the head sits on the neck's end and which way it points, in degrees
// (0 = +x). look turns it (22° at 1); lift tilts the snout up.
function headPose(neckEnd, look, lift) {
    var base = Math.atan2(-neckEnd.ty, -neckEnd.tx) * 180 / Math.PI;
    var up = Math.cos(base * Math.PI / 180) < 0 ? 1 : -1;
    return { x: neckEnd.x, y: neckEnd.y, angle: base + (look || 0) * 22 + up * (lift || 0) * 12 };
}

// One tick of a clock running at `hz`: the elapsed seconds, never negative,
// and clamped only against stalls (twice the clock's own interval), so
// motion keeps its speed whatever the tick rate.
function clockStep(dt, hz) {
    return Math.min(Math.max(dt, 0), 2 / hz);
}
