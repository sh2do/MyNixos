.pragma library
// The python's pose: three stacked coils round the status row, a neck rising
// from the top one and a tail running off the bottom edge. Pure functions on
// plain objects so tests can run them in node.
//
// The body is one helix, climbing on the right. From the tail: up into the
// bottom coil's right end, round its far side (the back half, drawn under the
// status row) to its left end, back along its near side (the front half,
// drawn over it) to the right, climbing there into the next coil up. The top
// coil's front climbs into the neck, which arches back over that coil so the
// head rests on its crest, facing left.
//
// Every chain runs tail to head, so each coil's back ends where its front
// starts. Serpent wants neck first: bodyChains() gives them in that order.
//
// The bottom coil wraps the row itself, so it is a superellipse (exponent 3):
// a plain ellipse round a wide row would need twice the width. The coils above
// sit clear of the row.

var BODY_WIDTH = 22;
// Breath scales each coil's radii by 1 + BREATH * breath.
var BREATH = 0.03;
// How far coil centrelines keep from the row's edge.
var CLEAR = BODY_WIDTH / 2 + 1.5;
// Points per half coil.
var HALF = 17;

function smooth(a, b, x) {
    var t = Math.min(Math.max((x - a) / (b - a), 0), 1);
    return t * t * (3 - 2 * t);
}

function spow(v, e) {
    return (v < 0 ? -1 : 1) * Math.pow(Math.abs(v), e);
}

// The point at angle th (screen coordinates, y down: sin < 0 is the far side).
function ringAt(r, th) {
    var e = 2 / r.n;
    return { x: r.cx + r.rx * spow(Math.cos(th), e), y: r.cy + r.ry * spow(Math.sin(th), e) };
}

// The coils at rest (breath 0). rings[3] is where the top coil's front ends:
// a quarter turn higher, where the neck starts.
function rings(box) {
    var A = box.w / 2 + CLEAR, B = box.h / 2 + CLEAR;
    var n0 = 3, ry0 = 1.25 * B;
    // Wide enough that the row's corners clear: (A/rx)^n + (B/ry)^n = 1, with
    // some room for the breath's 3%.
    var rx0 = A / Math.pow(1 - Math.pow(B / ry0, n0), 1 / n0);
    var r0 = { cx: box.x + box.w / 2, cy: box.y + box.h / 2, rx: rx0 * 1.04, ry: ry0 * 1.04, n: n0 };
    var ry1 = 0.8 * r0.ry;
    var r1 = { cx: r0.cx - 0.15 * box.w / 2, cy: box.y - CLEAR - ry1 * (1 + BREATH) - 0.5, rx: 0.9 * r0.rx, ry: ry1, n: 2.4 };
    var ry2 = 0.7 * r0.ry;
    var r2 = { cx: r0.cx - 0.3 * box.w / 2, cy: r1.cy - ry2 + 0.12 * ry1, rx: 0.78 * r0.rx, ry: ry2, n: 2.2 };
    var r3 = { cx: r2.cx - 2, cy: r2.cy - 0.55 * ry2, rx: 0.85 * r2.rx, ry: 0.8 * ry2, n: 2 };
    return [r0, r1, r2, r3];
}

function scaled(points, r, s) {
    var out = new Array(points.length);
    for (var i = 0; i < points.length; i++)
        out[i] = { x: r.cx + (points[i].x - r.cx) * s, y: r.cy + (points[i].y - r.cy) * s };
    return out;
}

// box: the status row's rectangle in the window's coordinates. t is accepted
// for the plan's signature but the coils don't drift: they are computed once
// per size, and the shell breathes them as a transform about each coil's
// centre, exactly as `breath` does here.
function coils(box, t, breath) {
    var R = rings(box);
    var s = 1 + BREATH * (breath || 0);
    var back = [], front = [];
    for (var k = 0; k < 3; k++) {
        var a = R[k], b = R[k + 1];
        var bk = [], fr = [];
        for (var i = 0; i < HALF; i++) {
            var f = i / (HALF - 1);
            // Far side: right end, over the top, to the left end.
            bk.push(ringAt(a, -Math.PI * f));
            // Near side: left end, along the bottom, to the right, climbing
            // into the next coil up: the bottom coil only once well right of
            // the row, the others along their whole right half.
            var th = -Math.PI - Math.PI * f;
            var p = ringAt(a, th), q = ringAt(b, th);
            var w = smooth(k === 0 ? 0.65 : 0.1, 1, Math.cos(th));
            // Breath swells each point about its own coil's centre, blended
            // the same way through the climb.
            // (The top coil's climb into the neck stays on its own centre,
            // as the neck does.)
            var c = k < 2 ? b : a;
            var cx = a.cx + (c.cx - a.cx) * w, cy = a.cy + (c.cy - a.cy) * w;
            fr.push({ x: cx + (p.x + (q.x - p.x) * w - cx) * s, y: cy + (p.y + (q.y - p.y) * w - cy) * s });
        }
        back.push(scaled(bk, a, s));
        front.push(fr);
    }
    var r0 = R[0], r2 = R[2], r3 = R[3];
    // The neck rises from the top coil's right and arches back over its crest.
    var neck = [
        { x: r3.cx + r3.rx, y: r3.cy },
        { x: r2.cx + r2.rx * 0.86, y: r2.cy - r2.ry - 4 },
        { x: r2.cx + r2.rx * 0.5, y: r2.cy - r2.ry - 8 },
        { x: r2.cx + r2.rx * 0.15, y: r2.cy - r2.ry - 8.5 },
        { x: r2.cx - r2.rx * 0.12, y: r2.cy - r2.ry - 7 }
    ];
    // The tail comes up from below the screen edge into the bottom coil.
    var tail = [
        { x: r0.cx + r0.rx * 0.55, y: r0.cy + r0.ry + 18 },
        { x: r0.cx + r0.rx * 0.88, y: r0.cy + r0.ry * 0.95 + 8 },
        { x: r0.cx + r0.rx + 3, y: r0.cy + r0.ry * 0.45 },
        { x: r0.cx + r0.rx, y: r0.cy }
    ];
    return {
        back: back,
        front: front,
        neck: scaled(neck, r2, s),
        // The tail doesn't swell: it rides along with the coil's right end.
        tail: tail.map(function (p) { return { x: p.x + r0.rx * (s - 1), y: p.y }; }),
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
// the body each covers by length (u0..u1, 0 at the head) and which coil's
// breath it follows.
function bodyChains(c) {
    var list = [
        { name: "neck", points: c.neck, ring: 2 },
        { name: "front2", points: c.front[2], ring: 2 },
        { name: "back2", points: c.back[2], ring: 2 },
        { name: "front1", points: c.front[1], ring: 1 },
        { name: "back1", points: c.back[1], ring: 1 },
        { name: "front0", points: c.front[0], ring: 0 },
        { name: "back0", points: c.back[0], ring: 0 },
        { name: "tail", points: c.tail, ring: 0 }
    ];
    var total = 0;
    for (var i = 0; i < list.length; i++) {
        list[i].points = list[i].points.slice().reverse();
        list[i].len = length(list[i].points);
        total += list[i].len;
    }
    var at = 0;
    for (var j = 0; j < list.length; j++) {
        list[j].u0 = at / total;
        at += list[j].len;
        list[j].u1 = at / total;
    }
    return list;
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
