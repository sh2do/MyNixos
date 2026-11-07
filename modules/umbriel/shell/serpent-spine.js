.pragma library
// Spine maths for the Umbriel serpents. A body is a chain of control points
// computed in JS and bent on the GPU; sample() produces the evenly spaced
// 24-point chain that goes to the shader as vec4 uniforms. Pure functions on
// plain objects so tests can run them in node.

var SPINE_POINTS = 24;
// Dense polyline steps per chain segment when measuring arc length.
var DENSE = 8;

// Scratch for the dense polyline, grown on demand and reused every frame.
var dx = new Float64Array(0);
var dy = new Float64Array(0);
var dl = new Float64Array(0);

// Centripetal knot spacing: chord^0.5, floored so clamped (doubled) end points
// never give a zero interval.
function knot(a, b) {
    var x = b.x - a.x, y = b.y - a.y;
    return Math.max(Math.sqrt(Math.sqrt(x * x + y * y)), 1e-4);
}

// Barry-Goldman evaluation of segment p1..p2 at local u in [0, 1]; writes into out.
function seg(p0, p1, p2, p3, u, out) {
    var t1 = knot(p0, p1), t2 = t1 + knot(p1, p2), t3 = t2 + knot(p2, p3);
    var t = t1 + (t2 - t1) * u;
    var a1x = (t1 - t) / t1 * p0.x + t / t1 * p1.x, a1y = (t1 - t) / t1 * p0.y + t / t1 * p1.y;
    var a2x = (t2 - t) / (t2 - t1) * p1.x + (t - t1) / (t2 - t1) * p2.x;
    var a2y = (t2 - t) / (t2 - t1) * p1.y + (t - t1) / (t2 - t1) * p2.y;
    var a3x = (t3 - t) / (t3 - t2) * p2.x + (t - t2) / (t3 - t2) * p3.x;
    var a3y = (t3 - t) / (t3 - t2) * p2.y + (t - t2) / (t3 - t2) * p3.y;
    var b1x = (t2 - t) / t2 * a1x + t / t2 * a2x, b1y = (t2 - t) / t2 * a1y + t / t2 * a2y;
    var b2x = (t3 - t) / (t3 - t1) * a2x + (t - t1) / (t3 - t1) * a3x;
    var b2y = (t3 - t) / (t3 - t1) * a2y + (t - t1) / (t3 - t1) * a3y;
    out.x = (t2 - t) / (t2 - t1) * b1x + (t - t1) / (t2 - t1) * b2x;
    out.y = (t2 - t) / (t2 - t1) * b1y + (t - t1) / (t2 - t1) * b2y;
}

var tmp = { x: 0, y: 0 };

function at(points, t, out) {
    var n = points.length;
    if (n === 1) { out.x = points[0].x; out.y = points[0].y; return; }
    var f = Math.min(Math.max(t, 0), 1) * (n - 1);
    var i = Math.min(Math.floor(f), n - 2);
    seg(points[Math.max(i - 1, 0)], points[i], points[i + 1], points[Math.min(i + 2, n - 1)], f - i, out);
}

function catmull(points, t) {
    var out = { x: 0, y: 0 };
    at(points, t, out);
    return out;
}

// Fill the dense polyline with cumulative lengths; returns its point count.
function dense(points) {
    var m = (points.length - 1) * DENSE + 1;
    if (m < 2) m = 2;
    if (dx.length < m) { dx = new Float64Array(m); dy = new Float64Array(m); dl = new Float64Array(m); }
    dl[0] = 0;
    for (var k = 0; k < m; k++) {
        at(points, k / (m - 1), tmp);
        dx[k] = tmp.x; dy[k] = tmp.y;
        if (k > 0) dl[k] = dl[k - 1] + Math.sqrt((dx[k] - dx[k - 1]) * (dx[k] - dx[k - 1]) + (dy[k] - dy[k - 1]) * (dy[k] - dy[k - 1]));
    }
    return m;
}

// Walk the dense polyline for n evenly spaced arc-length positions, calling
// emit(x, y, tx, ty, s, i) for each.
function walk(points, n, emit) {
    var m = dense(points);
    var total = dl[m - 1];
    var j = 0;
    for (var i = 0; i < n; i++) {
        var s = n > 1 ? total * i / (n - 1) : 0;
        while (j < m - 2 && dl[j + 1] < s) j++;
        var span = dl[j + 1] - dl[j];
        var f = span > 0 ? (s - dl[j]) / span : 0;
        var tx = dx[j + 1] - dx[j], ty = dy[j + 1] - dy[j];
        var tl = Math.sqrt(tx * tx + ty * ty);
        if (tl > 0) { tx /= tl; ty /= tl; } else { tx = 1; ty = 0; }
        emit(dx[j] + (dx[j + 1] - dx[j]) * f, dy[j] + (dy[j + 1] - dy[j]) * f, tx, ty, s, i);
    }
}

function sample(points, n) {
    var out = new Array(n);
    walk(points, n, function (x, y, tx, ty, s, i) { out[i] = { x: x, y: y, tx: tx, ty: ty, s: s }; });
    return out;
}

function smooth(a, b, x) {
    var t = Math.min(Math.max((x - a) / (b - a), 0), 1);
    return t * t * (3 - 2 * t);
}

// Width scale along the body, u = 0 at the neck (head end) to 1 at the tail tip.
function widthAt(u, bulges) {
    var w = u < 0.4 ? 0.85 + 0.15 * smooth(0, 0.1, u) : 1 - 0.8 * smooth(0.7, 1, u);
    for (var i = 0; i < bulges.length; i++) {
        var d = (u - bulges[i].u) / 0.035;
        w += bulges[i].size * Math.exp(-d * d);
    }
    return w;
}

function step(dt) {
    return Math.min(Math.max(dt, 0), 0.05);
}
