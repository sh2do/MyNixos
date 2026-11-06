// Tests for modules/shell/koi-motion.js (run: nix run nixpkgs#nodejs -- tests/koi-motion-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/koi-motion.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Koi = {};
vm.createContext(Koi);
vm.runInContext(src, Koi);

const pool = { x: 14, y: 8, w: 680, h: 22 };
const dt = 0.021;

// A seeded generator, so wander runs are repeatable.
function rng(seed) {
  let s = seed >>> 0;
  return () => (s = (s * 1664525 + 1013904223) >>> 0) / 4294967296;
}

function angleDiff(a, b) {
  return Math.abs(Math.atan2(Math.sin(a - b), Math.cos(a - b)));
}

const tests = {
  test_steer_turns_at_a_limited_rate() {
    const k = Koi.create(30, 100, 19, 0);
    const before = k.a;
    Koi.steer(k, dt, 40, 19, 14);   // straight behind it
    assert.ok(angleDiff(k.a, before) <= Koi.TURN * dt + 1e-9, `turned ${angleDiff(k.a, before)}`);
    assert.ok(angleDiff(k.a, before) > 0, "should start turning");
  },

  test_slow_koi_turn_slower_than_fast_ones() {
    // Nearly still, a fish drifts round gently instead of spinning on the spot.
    const slow = Koi.create(30, 100, 19, 0), fast = Koi.create(30, 100, 19, 0);
    slow.v = 2;
    fast.v = 20;
    Koi.steer(slow, dt, 40, 19, 2);
    Koi.steer(fast, dt, 40, 19, 20);
    assert.ok(angleDiff(slow.a, 0) < 0.5 * angleDiff(fast.a, 0), `slow ${slow.a}, fast ${fast.a}`);
  },

  test_steer_reaches_target() {
    const k = Koi.create(30, 100, 19, 0);
    for (let i = 0; i < 1000; i++) Koi.steer(k, dt, 400, 12, 20);   // 300 px at 20 px/s
    assert.ok(Math.hypot(k.x - 400, k.y - 12) < 6, `ended at ${k.x.toFixed(1)}, ${k.y.toFixed(1)}`);
  },

  test_speed_eases_instead_of_jumping() {
    const k = Koi.create(30, 100, 19, 0);
    k.v = 10;
    Koi.steer(k, dt, 600, 19, 90);
    assert.ok(k.v > 10 && k.v < 40, `speed after one tick ${k.v}`);
  },

  test_wandering_stays_in_the_pool() {
    const rand = rng(7);
    const k = Koi.create(30, 100, 19, 0);
    let tx = k.x, ty = k.y;
    for (let i = 0; i < 3000; i++) {
      if (Math.hypot(k.x - tx, k.y - ty) < 6) ({ x: tx, y: ty } = Koi.wander(rand, pool));
      Koi.steer(k, dt, tx, ty, 16);
      Koi.keepIn(k, pool);
      assert.ok(k.x >= pool.x - 2 && k.x <= pool.x + pool.w + 2, `x ${k.x}`);
      assert.ok(k.y >= pool.y - 2 && k.y <= pool.y + pool.h + 2, `y ${k.y}`);
    }
  },

  test_wander_targets_are_in_the_pool() {
    const rand = rng(3);
    for (let i = 0; i < 200; i++) {
      const p = Koi.wander(rand, pool);
      assert.ok(p.x >= pool.x && p.x <= pool.x + pool.w && p.y >= pool.y && p.y <= pool.y + pool.h);
    }
  },

  test_cruise_mostly_keeps_going_the_same_way() {
    // The pool is a thin strip: a target behind means a tight U-turn, so
    // most new targets lie ahead.
    const rand = rng(11);
    const k = Koi.create(30, pool.x + pool.w / 2, 19, 0);
    let ahead = 0;
    for (let i = 0; i < 200; i++) {
      const p = Koi.cruise(k, rand, pool);
      if (p.x > k.x) ahead++;
      assert.ok(p.x >= pool.x && p.x <= pool.x + pool.w && p.y >= pool.y && p.y <= pool.y + pool.h);
      assert.ok(Math.abs(p.x - k.x) >= 60, `target only ${Math.abs(p.x - k.x)} away`);
    }
    assert.ok(ahead > 140 && ahead < 200, `${ahead}/200 ahead`);
  },

  test_cruise_turns_back_at_a_wall() {
    const rand = rng(12);
    const k = Koi.create(30, pool.x + pool.w - 20, 19, 0);
    for (let i = 0; i < 50; i++)
      assert.ok(Koi.cruise(k, rand, pool).x < k.x - 59, "heading into the wall, it should turn back");
  },

  test_body_follows_head_at_fixed_spacing() {
    const k = Koi.create(30, 100, 19, 0);
    for (let i = 0; i < 200; i++) {
      Koi.steer(k, dt, 300, 10 + 8 * Math.sin(i / 9), 30);
      Koi.follow(k);
    }
    const seg = k.len / (Koi.SEGMENTS - 1);
    assert.strictEqual(k.pts[0].x, k.x);
    for (let i = 1; i < k.pts.length; i++) {
      const d = Math.hypot(k.pts[i].x - k.pts[i - 1].x, k.pts[i].y - k.pts[i - 1].y);
      assert.ok(Math.abs(d - seg) < 1e-6, `segment ${i} is ${d}, want ${seg}`);
    }
  },

  test_body_is_widest_behind_the_head() {
    const n = Koi.SEGMENTS, w = 9;
    const widths = Array.from({ length: n }, (_, i) => Koi.bodyWidth(i, n, w));
    const widest = widths.indexOf(Math.max(...widths));
    assert.ok(widest > 0 && widest < n / 2, `widest at ${widest}`);
    assert.ok(widths[0] < w && widths[0] > 0.5 * w, `head ${widths[0]}`);
    assert.ok(widths[n - 1] < 0.4 * w, `tail ${widths[n - 1]}`);
    for (let i = widest + 1; i < n; i++) assert.ok(widths[i] <= widths[i - 1], "tapers to the tail");
  },

  test_swimming_waves_the_tail_not_the_head() {
    const k = Koi.create(30, 100, 19, 0);
    k.v = 20;
    const still = Koi.pose(k, 0).map(p => ({ ...p }));
    let headMove = 0, tailMove = 0;
    for (const phase of [0.7, 1.6, 2.4]) {
      k.phase = phase;
      const p = Koi.pose(k, 0);
      headMove = Math.max(headMove, Math.hypot(p[0].x - still[0].x, p[0].y - still[0].y));
      const n = p.length - 1;
      tailMove = Math.max(tailMove, Math.hypot(p[n].x - still[n].x, p[n].y - still[n].y));
    }
    assert.ok(headMove < 0.5, `head moved ${headMove}`);
    assert.ok(tailMove > 1.5, `tail moved only ${tailMove}`);
  },

  test_flee_points_away_and_stays_in_pool() {
    const k = Koi.create(30, 300, 19, 0);
    for (const [px, py] of [[290, 19], [320, 10], [300, 30]]) {
      const f = Koi.flee(k, px, py, pool);
      assert.ok(Math.hypot(f.x - px, f.y - py) > Math.hypot(k.x - px, k.y - py) + 30, `flee ${f.x},${f.y} from ${px},${py}`);
      assert.ok(f.x >= pool.x && f.x <= pool.x + pool.w && f.y >= pool.y && f.y <= pool.y + pool.h);
    }
  },

  test_flee_from_a_wall_side_turns_inward() {
    // Pointer between the koi and the wall it's near: it can't flee into the wall.
    const k = Koi.create(30, pool.x + 20, 19, 0);
    const f = Koi.flee(k, pool.x + 2, 19, pool);
    assert.ok(f.x > k.x + 30, `flee went to ${f.x}`);
  },

  test_heading_angles_stay_wrapped() {
    const k = Koi.create(30, 100, 19, 0);
    for (let i = 0; i < 2000; i++) Koi.steer(k, dt, 100 + 30 * Math.cos(i / 20), 19 + 8 * Math.sin(i / 20), 25);
    assert.ok(k.a > -Math.PI - 1e-9 && k.a <= Math.PI + 1e-9, `heading ${k.a}`);
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
