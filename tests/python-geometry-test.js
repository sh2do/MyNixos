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
    // Python.qml draws a tapered tip bodyW * 1.3 left of where the path starts.
    const r = Geo.layout(400, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }, { x: 350, w: 28 }], 15);
    assert.ok(r.bounds.x <= r.path[0].x0 - 15 * 1.3, `bounds start at ${r.bounds.x}, tip at ${r.path[0].x0 - 19.5}`);
  },

  test_head_aim_follows_pointer() {
    const rest = -105;
    const left = Geo.headAim(rest, 20, 800), mid = Geo.headAim(rest, 400, 800), right = Geo.headAim(rest, 780, 800);
    assert.ok(left < mid && mid < right, `aim should sweep left to right: ${left}, ${mid}, ${right}`);
    for (const a of [left, mid, right])
      assert.ok(a >= rest - 45 && a <= rest + 20, `aim ${a} outside rest-45..rest+20`);
  },

  test_head_aim_rests_without_pointer() {
    assert.strictEqual(Geo.headAim(-105, NaN, 800), -105);
  },

  test_bounds_cover_head() {
    const r = Geo.layout(400, 38, [{ x: 6, w: 30 }, { x: 260, w: 40 }, { x: 350, w: 28 }], 15);
    const b = r.bounds;
    assert.ok(b.x <= r.head.x - 20 && b.x + b.w >= r.head.x + 20, "bounds miss the head horizontally");
    assert.ok(b.y <= r.head.y - 20 && b.y + b.h >= r.head.y + 20, "bounds miss the head vertically");
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
