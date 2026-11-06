// Tests for modules/shell/python-geometry.js (run: nix run nixpkgs#nodejs -- tests/python-geometry-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/python-geometry.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Geo = {};
vm.createContext(Geo);
vm.runInContext(src, Geo);

// Points along a cubic segment, for checks on the drawn curve rather than its control points.
function sample(seg, n = 24) {
  const pts = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n, u = 1 - t;
    pts.push({
      x: u * u * u * seg.x0 + 3 * u * u * t * seg.c1x + 3 * u * t * t * seg.c2x + t * t * t * seg.x1,
      y: u * u * u * seg.y0 + 3 * u * u * t * seg.c1y + 3 * u * t * t * seg.c2y + t * t * t * seg.y1,
    });
  }
  return pts;
}

function insideSomeGap(c, gaps) {
  return gaps.some(g => c.x0 >= g.x && c.x1 <= g.x + g.w);
}

// Seeded so a failure can be reproduced.
let seed = 42;
function rand() {
  seed = (seed * 1103515245 + 12345) % 2147483648;
  return seed / 2147483648;
}

const tests = {
  test_three_crossings_in_widest_gaps() {
    const gaps = [{ x: 6, w: 30 }, { x: 120, w: 24 }, { x: 260, w: 40 }, { x: 350, w: 28 }];
    const r = Geo.layout(400, 38, gaps, 15);
    assert.strictEqual(r.crossings.length, 3);
    const widest = [gaps[0], gaps[2], gaps[3]];
    for (const c of r.crossings)
      assert.ok(insideSomeGap(c, widest), `crossing ${JSON.stringify(c)} not in the widest gaps`);
  },

  test_crossings_avoid_widgets_for_any_gap_set() {
    for (let run = 0; run < 200; run++) {
      const pillW = 250 + Math.floor(rand() * 351);
      const count = 2 + Math.floor(rand() * 5);
      const gaps = [];
      let x = 0;
      for (let i = 0; i < count; i++) {
        const w = 18 + Math.floor(rand() * 43);
        const room = pillW - x - w - (count - i - 1) * 61;
        if (room < 0) break;
        x += Math.floor(rand() * Math.min(room, 80));
        gaps.push({ x, w });
        x += w + 1;
      }
      const r = Geo.layout(pillW, 38, gaps, 15);
      for (const c of r.crossings)
        assert.ok(insideSomeGap(c, gaps), `run ${run}: crossing ${JSON.stringify(c)} outside ${JSON.stringify(gaps)}`);
    }
  },

  test_two_gaps_gives_two_crossings() {
    const r = Geo.layout(300, 38, [{ x: 40, w: 24 }, { x: 200, w: 30 }], 15);
    assert.strictEqual(r.crossings.length, 2);
  },

  test_tail_left_head_right() {
    const r = Geo.layout(400, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }, { x: 350, w: 28 }], 15);
    assert.ok(r.path[0].x0 < 0, "tail should start off the left end");
    assert.ok(r.head.x > 400, "head should be off the right end");
    assert.ok(r.head.y < 0, "head should be above the pill");
  },

  test_lower_loops_fit_raised_gap() {
    const r = Geo.layout(400, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }, { x: 350, w: 28 }], 15);
    const lowest = Math.max(...r.path.flatMap(s => sample(s).map(p => p.y))) + 15 / 2;
    assert.ok(lowest <= 38 + 15 + 1, `lowest point ${lowest} below the raised gap`);
  },

  test_bounds_cover_tail_tip() {
    // The tapered body ends in a round cap at the path's start.
    const r = Geo.layout(400, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }, { x: 350, w: 28 }], 15);
    assert.ok(r.bounds.x <= r.path[0].x0 - 15 / 2, `bounds start at ${r.bounds.x}, tail at ${r.path[0].x0}`);
  },

  test_head_aim_points_at_pointer() {
    const r = Geo.layout(800, 38, [{ x: 6, w: 30 }, { x: 400, w: 40 }, { x: 700, w: 28 }], 19);
    const rest = r.head.angle;
    for (const hx of [400, 600, 760]) {
      const a = Geo.headAim(rest, r.head, hx, 38) * Math.PI / 180;
      // The ray from the head along the aim passes the pointer at mid-pill height.
      const k = (19 - r.head.y) / Math.sin(a);
      const hitX = r.head.x + k * Math.cos(a);
      assert.ok(Math.abs(hitX - hx) < 2, `aim for ${hx} hits ${hitX}`);
    }
  },

  test_head_aim_is_clamped() {
    const r = Geo.layout(800, 38, [{ x: 6, w: 30 }, { x: 400, w: 40 }, { x: 700, w: 28 }], 19);
    const rest = r.head.angle;
    for (const hx of [-500, 0, 790, 2000]) {
      const a = Geo.headAim(rest, r.head, hx, 38);
      assert.ok(a >= rest - 50 - 1e-9 && a <= rest + 15 + 1e-9, `aim ${a} for ${hx} outside rest-50..rest+15`);
    }
  },

  test_head_aim_rests_without_pointer() {
    const r = Geo.layout(800, 38, [{ x: 6, w: 30 }], 19);
    assert.strictEqual(Geo.headAim(r.head.angle, r.head, NaN, 38), r.head.angle);
  },

  test_head_rests_low_and_faces_the_bar() {
    const r = Geo.layout(800, 38, [{ x: 6, w: 30 }, { x: 400, w: 40 }, { x: 700, w: 28 }], 19);
    // Pointing left along the bar and a little down, not straight up.
    assert.ok(r.head.angle > 150 && r.head.angle < 180, `rest angle ${r.head.angle}`);
    assert.ok(r.head.y > -3 * 19 && r.head.y < -19, `head y ${r.head.y}`);
  },

  test_bounds_cover_head() {
    const bw = 15;
    const r = Geo.layout(400, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }, { x: 350, w: 28 }], bw);
    const b = r.bounds, reach = 3.2 * bw;
    assert.ok(b.x <= r.head.x - reach && b.x + b.w >= r.head.x + reach, "bounds miss the head horizontally");
    assert.ok(b.y <= r.head.y - reach && b.y + b.h >= r.head.y + reach, "bounds miss the head vertically");
  },

  test_body_tapers_at_tail_and_neck() {
    const bw = 19, len = 1000;
    assert.ok(Geo.widthAt(0, len, bw) < 0.3 * bw, "tail tip should be thin");
    assert.strictEqual(Geo.widthAt(len / 2, len, bw), bw, "mid-body is full width");
    const neck = Geo.widthAt(len, len, bw);
    assert.ok(neck > 0.6 * bw && neck < 0.8 * bw, `neck ${neck}`);
    for (let s = 0; s < 5 * bw; s += 5)
      assert.ok(Geo.widthAt(s + 5, len, bw) >= Geo.widthAt(s, len, bw), "tail widens monotonically");
  },

  test_samples_follow_path() {
    const r = Geo.layout(400, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }], 15);
    const pts = Geo.samples(r.path, 2);
    assert.strictEqual(pts[0].x, r.path[0].x0);
    const last = r.path[r.path.length - 1], end = pts[pts.length - 1];
    assert.ok(Math.hypot(end.x - last.x1, end.y - last.y1) < 1e-6, "samples end at the head");
    for (let i = 1; i < pts.length; i++) {
      assert.ok(pts[i].s > pts[i - 1].s, "arc length increases");
      assert.ok(Math.abs(Math.hypot(pts[i].tx, pts[i].ty) - 1) < 1e-6, "unit tangent");
    }
  },

  test_blotches_stay_inside_body() {
    const bw = 19;
    const r = Geo.layout(600, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }, { x: 500, w: 30 }], bw);
    const pts = Geo.samples(r.path, 2), len = pts[pts.length - 1].s;
    const marks = Geo.blotches(pts, bw, 0);
    assert.ok(marks.length > 10, `only ${marks.length} blotches`);
    for (const poly of marks)
      for (const p of poly) {
        // Distance to the nearest spine sample is within the half width there.
        let best = Infinity, at = null;
        for (const q of pts) {
          const d = Math.hypot(p.x - q.x, p.y - q.y);
          if (d < best) { best = d; at = q; }
        }
        assert.ok(best <= Geo.widthAt(at.s, len, bw) / 2 + 1.5, `blotch point ${best.toFixed(1)} from spine`);
      }
  },

  test_slide_moves_blotches_along_body() {
    const bw = 19;
    const r = Geo.layout(600, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }], bw);
    const pts = Geo.samples(r.path, 2);
    const a = Geo.blotches(pts, bw, 0), b = Geo.blotches(pts, bw, 7);
    const moved = a.some((poly, i) => b[i] && Math.hypot(poly[0].x - b[i][0].x, poly[0].y - b[i][0].y) > 3);
    assert.ok(moved, "a slide of 7 px should move the blotches");
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log(`PASS ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${name}\n    ${e.message}`);
  }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
