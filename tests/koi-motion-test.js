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

  test_gather_pulls_targets_toward_the_middle() {
    const cx = pool.x + pool.w / 2;
    for (const x of [pool.x, pool.x + 100, cx + 40, pool.x + pool.w]) {
      const g = Koi.gather({ x: x, y: 12 }, cx, 0.3);
      assert.ok(Math.abs(g.x - cx) <= Math.abs(x - cx) * 0.3 + 1e-9, `${x} -> ${g.x}`);
      assert.ok(Math.sign(g.x - cx) === Math.sign(x - cx) || g.x === cx, "stays on its side");
      assert.strictEqual(g.y, 12);
    }
  },

  test_gather_with_full_spread_leaves_targets_alone() {
    const g = Koi.gather({ x: 50, y: 20 }, 300, 1);
    assert.deepStrictEqual({ x: g.x, y: g.y }, { x: 50, y: 20 });
  },

  test_koi_cruising_to_gathered_targets_end_up_near_the_middle() {
    const cx = pool.x + pool.w / 2, rand = rng(7);
    const k = Koi.create(30, pool.x + 10, 19, 0);
    let target = Koi.gather(Koi.cruise(k, rand, pool), cx, 0.25);
    let far = 0;
    for (let i = 0; i < 6000; i++) {
      if (Math.hypot(k.x - target.x, k.y - target.y) < 8) target = Koi.gather(Koi.cruise(k, rand, pool), cx, 0.25);
      Koi.steer(k, dt, target.x, target.y, 18);
      Koi.keepIn(k, pool);
      if (i > 2000 && Math.abs(k.x - cx) > 110) far++;
    }
    assert.ok(far < 200, `${far} ticks far from the middle`);
  },

  test_heading_angles_stay_wrapped() {
    const k = Koi.create(30, 100, 19, 0);
    for (let i = 0; i < 2000; i++) Koi.steer(k, dt, 100 + 30 * Math.cos(i / 20), 19 + 8 * Math.sin(i / 20), 25);
    assert.ok(k.a > -Math.PI - 1e-9 && k.a <= Math.PI + 1e-9, `heading ${k.a}`);
  },

  test_night_by_day_is_the_day_pond() {
    const quiet = Koi.nightMood(0, false), music = Koi.nightMood(0, true);
    assert.deepStrictEqual(
      { speed: quiet.speed, rest: quiet.rest, spread: quiet.spread, reach: quiet.reach, kiss: quiet.kiss, lull: quiet.lull },
      { speed: 1, rest: 0.3, spread: 1, reach: 300, kiss: 1, lull: 1 });
    assert.strictEqual(music.speed, 1.35, "livelier to the music");
    assert.strictEqual(music.rest, 0.1);
    assert.strictEqual(music.spread, 0.3);
    assert.strictEqual(music.toPad, 0, "music gathers them in the middle by day");
  },

  test_night_slows_them_and_they_wander_less_and_rest_more() {
    const day = Koi.nightMood(0, false), night = Koi.nightMood(1, false);
    assert.ok(night.speed <= day.speed * 0.5, `speed ${night.speed}`);
    assert.ok(night.rest > day.rest, `rest chance ${night.rest}`);
    assert.ok(night.lull > day.lull, `rests last ${night.lull}x`);
    assert.ok(night.reach < day.reach * 0.5, `reach ${night.reach}`);
    assert.ok(night.kiss >= 2, `surface rises ${night.kiss}x rarer`);
    assert.ok(night.spread <= 0.3, `gathered ${night.spread}`);
    assert.strictEqual(night.toPad, 1, "under the lily pad");
  },

  test_music_still_stirs_them_a_little_at_night() {
    const still = Koi.nightMood(1, false), music = Koi.nightMood(1, true), day = Koi.nightMood(0, true);
    assert.ok(music.speed > still.speed, `${music.speed} vs ${still.speed}`);
    assert.ok(music.speed < day.speed, "but not to the day's pace");
    assert.ok(music.spread > still.spread, "a little looser");
    assert.ok(music.toPad > 0.5, "still near the pad");
  },

  test_night_mood_eases_between_day_and_night() {
    const a = Koi.nightMood(0, false), m = Koi.nightMood(0.5, false), b = Koi.nightMood(1, false);
    for (const k of ["speed", "rest", "reach", "kiss", "spread", "lull"])
      assert.ok((m[k] - a[k]) * (b[k] - m[k]) >= 0 && m[k] !== a[k], `${k}: ${a[k]} ${m[k]} ${b[k]}`);
  },

  test_cruise_keeps_within_its_reach() {
    const rand = rng(3);
    for (let i = 0; i < 400; i++) {
      const k = Koi.create(30, pool.x + 40 + rand() * (pool.w - 80), 19, rand() < 0.5 ? 0 : Math.PI);
      const t = Koi.cruise(k, rand, pool, 110);
      assert.ok(Math.abs(t.x - k.x) <= 110 + 1e-9, `${Math.abs(t.x - k.x)}`);
    }
  },

  test_koi_at_night_gather_under_the_pad() {
    const pad = pool.x + pool.w * 0.62, rand = rng(11), mood = Koi.nightMood(1, false);
    const k = Koi.create(30, pool.x + 10, 19, 0);
    const next = () => Koi.gather(Koi.cruise(k, rand, pool, mood.reach), pad, mood.spread);
    let target = next(), far = 0;
    for (let i = 0; i < 12000; i++) {
      if (Math.hypot(k.x - target.x, k.y - target.y) < 8) target = next();
      Koi.steer(k, dt, target.x, target.y, 13 * mood.speed);
      Koi.keepIn(k, pool);
      if (i > 6000 && Math.abs(k.x - pad) > 90) far++;
    }
    assert.ok(far < 300, `${far} ticks far from the pad`);
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
