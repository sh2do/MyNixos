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

    // Neck: behind the pill to its right end, then up and over to the head.
    const last = path[path.length - 1];
    const neckX = pillW + bodyW;
    path.push(sweep(last.x1, last.y1, neckX, pillH / 2));
    const head = { x: pillW + bodyW * 1.6, y: -bodyW * 1.4 };
    path.push({ x0: neckX, y0: pillH / 2, c1x: neckX + bodyW, c1y: pillH / 2,
                c2x: head.x + 4, c2y: head.y + bodyW, x1: head.x, y1: head.y });
    const n = path[path.length - 1];
    head.angle = Math.atan2(n.y1 - n.c2y, n.x1 - n.c2x) * 180 / Math.PI;

    // Box around every control point (the curve stays inside its control hull)
    // plus the stroke, around the tapered tail tip, and around the head with its tongue.
    const reach = 40;
    let x0 = Math.min(head.x - reach, tailX - bodyW * 1.3 - 2), x1 = head.x + reach, y0 = head.y - reach, y1 = head.y + reach;
    for (const s of path)
        for (const [px, py] of [[s.x0, s.y0], [s.c1x, s.c1y], [s.c2x, s.c2y], [s.x1, s.y1]]) {
            x0 = Math.min(x0, px - half - 2);
            x1 = Math.max(x1, px + half + 2);
            y0 = Math.min(y0, py - half - 2);
            y1 = Math.max(y1, py + half + 2);
        }

    return { path, crossings: fronts.map(f => f.span), head, bounds: { x: x0, y: y0, w: x1 - x0, h: y1 - y0 } };
}

// Where the head points (degrees, 0 = +x) with the pointer at hoverX on a pill
// pillW wide: it leans out over the bar toward the left end and straightens up
// toward the right end. At rest without a pointer.
function headAim(restAngle, hoverX, pillW) {
    if (isNaN(hoverX) || !(pillW > 0))
        return restAngle;
    const f = Math.max(0, Math.min(1, hoverX / pillW));
    return restAngle - 45 + 65 * f;
}
