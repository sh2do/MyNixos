.pragma library

// Where the python's body goes around the bottom bar pill. Pure geometry, no QML,
// so tests/python-geometry-test.js can run it under node.
//
// Coordinates are in the pill's frame: x 0..pillW, y 0..pillH, negative y above.
// The body is a helix seen from the front: it crosses the pill top-to-bottom in
// front (only inside gaps between widget groups), then loops back behind it
// bottom-to-top to the next crossing. The tail starts off the left end and the
// neck rises off the right end.

// Up to n gaps for the front crossings, widest first, returned left to right.
function pickGaps(gaps, n) {
    return gaps.slice().sort((a, b) => b.w - a.w).slice(0, n).sort((a, b) => a.x - b.x);
}

// One cubic segment that leaves (x0, y0) and arrives at (x1, y1) with
// horizontal tangents, so consecutive segments join smoothly.
function sweep(x0, y0, x1, y1) {
    const k = (x1 - x0) / 2;
    return { x0, y0, c1x: x0 + k, c1y: y0, c2x: x1 - k, c2y: y1, x1, y1 };
}

function layout(pillW, pillH, gaps, bodyW) {
    const half = bodyW / 2;
    const top = -half;
    const bottom = pillH + half;

    // Each front crossing slants from top-left to bottom-right inside its gap,
    // keeping the whole stroke within the gap while it is over the pill.
    const fronts = pickGaps(gaps, 3).map(g => {
        const cx = g.x + g.w / 2;
        const slant = Math.max(0, Math.min(8, (g.w - bodyW) / 2 - 1));
        return {
            xa: cx - slant,
            xb: cx + slant,
            span: { x0: Math.max(g.x, cx - slant - half), x1: Math.min(g.x + g.w, cx + slant + half) }
        };
    });

    const path = [];
    // Tail: from off the left end, behind the pill, up to the first crossing.
    const tailX = -bodyW * 2;
    let x = tailX, y = bottom;
    for (const f of fronts) {
        path.push(sweep(x, y, f.xa, top));        // behind, bottom to top
        path.push(sweep(f.xa, top, f.xb, bottom)); // in front, top to bottom
        x = f.xb;
        y = bottom;
    }
    if (!fronts.length)
        path.push(sweep(x, y, pillW / 2, top));

    // Neck: behind the pill past its right end, then up and back over it, so the
    // head rests low above the bar's right end looking left along it.
    const last = path[path.length - 1];
    const neckX = pillW + bodyW;
    path.push(sweep(last.x1, last.y1, neckX, pillH / 2));
    const a = 165 * Math.PI / 180;
    const head = { x: pillW + bodyW * 0.5, y: -bodyW * 2, angle: 165 };
    path.push({ x0: neckX, y0: pillH / 2, c1x: neckX + bodyW * 1.4, c1y: pillH / 2,
                c2x: head.x - bodyW * 1.4 * Math.cos(a), c2y: head.y - bodyW * 1.4 * Math.sin(a),
                x1: head.x, y1: head.y });

    // Box around every control point (the curve stays inside its control hull)
    // plus the stroke, and around the head with its tongue.
    const reach = bodyW * 3.6;
    let x0 = head.x - reach, x1 = head.x + reach, y0 = head.y - reach, y1 = head.y + reach;
    for (const s of path)
        for (const [px, py] of [[s.x0, s.y0], [s.c1x, s.c1y], [s.c2x, s.c2y], [s.x1, s.y1]]) {
            x0 = Math.min(x0, px - half - 2);
            x1 = Math.max(x1, px + half + 2);
            y0 = Math.min(y0, py - half - 2);
            y1 = Math.max(y1, py + half + 2);
        }

    return { path, crossings: fronts.map(f => f.span), head, bounds: { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } };
}

// Where the head points (degrees, 0 = +x, y down): at the pointer, seen at
// mid-pill height, within -50..+15 degrees of its rest pose. At rest without one.
function headAim(restAngle, head, hoverX, pillH) {
    if (isNaN(hoverX))
        return restAngle;
    let a = Math.atan2(pillH / 2 - head.y, hoverX - head.x) * 180 / Math.PI;
    while (a - restAngle > 180) a -= 360;
    while (a - restAngle < -180) a += 360;
    return Math.max(restAngle - 50, Math.min(restAngle + 15, a));
}

// ---- The body's skin: a tapered outline and its pattern, from the spine ----

function smooth(u) {
    u = Math.max(0, Math.min(1, u));
    return u * u * (3 - 2 * u);
}

// Body width at arc length s along a spine len long: thin at the tail tip,
// full through the coils, narrowing into the neck.
function widthAt(s, len, bodyW) {
    let f = 0.2 + 0.8 * smooth(s / (bodyW * 5));
    const neck = bodyW * 3;
    if (s > len - neck)
        f *= 1 - 0.3 * smooth((s - (len - neck)) / neck);
    return bodyW * f;
}

// Points along the path about `step` px apart, each with its arc length s and
// unit tangent (tx, ty).
function samples(path, step) {
    const pts = [];
    let s = 0;
    for (const seg of path) {
        const chord = Math.hypot(seg.c1x - seg.x0, seg.c1y - seg.y0) + Math.hypot(seg.c2x - seg.c1x, seg.c2y - seg.c1y)
            + Math.hypot(seg.x1 - seg.c2x, seg.y1 - seg.c2y);
        const n = Math.max(2, Math.ceil(chord / step));
        for (let i = pts.length ? 1 : 0; i <= n; i++) {
            const t = i / n, u = 1 - t;
            const x = u * u * u * seg.x0 + 3 * u * u * t * seg.c1x + 3 * u * t * t * seg.c2x + t * t * t * seg.x1;
            const y = u * u * u * seg.y0 + 3 * u * u * t * seg.c1y + 3 * u * t * t * seg.c2y + t * t * t * seg.y1;
            let dx = 3 * u * u * (seg.c1x - seg.x0) + 6 * u * t * (seg.c2x - seg.c1x) + 3 * t * t * (seg.x1 - seg.c2x);
            let dy = 3 * u * u * (seg.c1y - seg.y0) + 6 * u * t * (seg.c2y - seg.c1y) + 3 * t * t * (seg.y1 - seg.c2y);
            const d = Math.hypot(dx, dy) || 1;
            if (pts.length) {
                const p = pts[pts.length - 1], ds = Math.hypot(x - p.x, y - p.y);
                if (ds < 1e-9)
                    continue;
                s += ds;
            }
            pts.push({ x, y, s, tx: dx / d, ty: dy / d });
        }
    }
    return pts;
}

// The spine point at arc length s, interpolated between samples.
function at(pts, s) {
    let lo = 0, hi = pts.length - 1;
    while (hi - lo > 1) {
        const mid = (lo + hi) >> 1;
        if (pts[mid].s <= s) lo = mid; else hi = mid;
    }
    const a = pts[lo], b = pts[hi], f = b.s > a.s ? Math.max(0, Math.min(1, (s - a.s) / (b.s - a.s))) : 0;
    const tx = a.tx + (b.tx - a.tx) * f, ty = a.ty + (b.ty - a.ty) * f, d = Math.hypot(tx, ty) || 1;
    return { x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f, tx: tx / d, ty: ty / d };
}

// Reticulated saddles: lens-shaped blotches along the back, uneven in length and
// nudged to alternate sides, so they read as a net rather than a chain. `slide`
// moves them along the body (px). Returns polygons as arrays of {x, y}.
const blotchLengths = [1.3, 0.95, 1.5, 1.1, 1.25, 0.9];
function blotches(pts, bodyW, slide) {
    const len = pts[pts.length - 1].s, period = bodyW * 2.4, out = [];
    const first = Math.floor((bodyW * 2 - slide) / period) - 1;
    for (let k = first; k * period + slide < len; k++) {
        const i = ((k % blotchLengths.length) + blotchLengths.length) % blotchLengths.length;
        const bl = blotchLengths[i] * bodyW, c = k * period + slide;
        if (c - bl / 2 < bodyW * 2 || c + bl / 2 > len - bodyW * 1.2)
            continue;
        const side = (k & 1 ? 0.06 : -0.06), top = [], bottom = [];
        for (let j = 0; j <= 8; j++) {
            const u = j / 8, s = c + (u - 0.5) * bl, p = at(pts, s), w = widthAt(s, len, bodyW);
            const half = 0.38 * w * Math.sqrt(Math.sin(Math.PI * u)), off = side * w;
            top.push({ x: p.x - p.ty * (off + half), y: p.y + p.tx * (off + half) });
            bottom.push({ x: p.x - p.ty * (off - half), y: p.y + p.tx * (off - half) });
        }
        out.push(top.concat(bottom.reverse()));
    }
    return out;
}

// Pale flecks on the flanks between saddles: {x, y, r}.
function flecks(pts, bodyW, slide) {
    const len = pts[pts.length - 1].s, period = bodyW * 2.4, out = [];
    const first = Math.floor((bodyW * 2 - slide) / period) - 1;
    for (let k = first; k * period + slide < len; k++) {
        const s = k * period + slide + period / 2;
        if (s < bodyW * 2.5 || s > len - bodyW * 1.5)
            continue;
        const p = at(pts, s), w = widthAt(s, len, bodyW);
        for (const side of k & 1 ? [0.34] : [-0.34, 0.3])
            out.push({ x: p.x - p.ty * side * w, y: p.y + p.tx * side * w, r: bodyW * 0.075 });
    }
    return out;
}

// SVG path strings, shifted by (ox, oy) into the item's frame.
function outlineSvg(pts, bodyW, ox, oy) {
    const len = pts[pts.length - 1].s, left = [], right = [];
    for (const p of pts) {
        const h = widthAt(p.s, len, bodyW) / 2;
        left.push(`${(p.x - p.ty * h - ox).toFixed(1)} ${(p.y + p.tx * h - oy).toFixed(1)}`);
        right.push(`${(p.x + p.ty * h - ox).toFixed(1)} ${(p.y - p.tx * h - oy).toFixed(1)}`);
    }
    const t = pts[0], r = widthAt(0, len, bodyW) / 2;
    const tip = `${(t.x - t.tx * r - ox).toFixed(1)} ${(t.y - t.ty * r - oy).toFixed(1)}`;
    return `M ${tip} L ${left.join(" L ")} L ${right.reverse().join(" L ")} Z`;
}

// A line along the body at `k` body widths off the spine (negative = left side).
function edgeSvg(pts, bodyW, k, ox, oy) {
    const len = pts[pts.length - 1].s;
    return "M " + pts.map(p => {
        const o = k * widthAt(p.s, len, bodyW);
        return `${(p.x - p.ty * o - ox).toFixed(1)} ${(p.y + p.tx * o - oy).toFixed(1)}`;
    }).join(" L ");
}

function polysSvg(polys, ox, oy) {
    return polys.map(poly => "M " + poly.map(p => `${(p.x - ox).toFixed(1)} ${(p.y - oy).toFixed(1)}`).join(" L ") + " Z").join(" ");
}

function dotsSvg(dots, ox, oy) {
    return dots.map(d => `M ${(d.x - ox - d.r).toFixed(1)} ${(d.y - oy).toFixed(1)} a ${d.r} ${d.r} 0 1 0 ${2 * d.r} 0 a ${d.r} ${d.r} 0 1 0 ${-2 * d.r} 0`).join(" ");
}
