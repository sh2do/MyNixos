// Tests for modules/umbriel/shell/venom.js (run: nix run nixpkgs#nodejs -- tests/venom-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/venom.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Venom = {};
vm.createContext(Venom);
vm.runInContext(src, Venom);

const near = (a, b, eps, what) => assert.ok(Math.abs(a - b) <= eps, `${what}: ${a} vs ${b}`);

// Step a drop at a fixed rate until pred(drop) or the time runs out;
// returns the drop and the seconds it took.
function run(drop, windows, fadeAt, pred, hz = 144, limit = 10) {
  let t = 0;
  while (!pred(drop) && t < limit) {
    drop = Venom.dropStep(drop, 1 / hz, windows, fadeAt);
    t += 1 / hz;
  }
  return { drop, t };
}

const tests = {
  test_drip_interval_follows_load() {
    assert.strictEqual(Venom.dripInterval(0), 4000);
    assert.strictEqual(Venom.dripInterval(1), 600);
    assert.strictEqual(Venom.dripInterval(0.5), 2300);
    // Out of range loads are clamped.
    assert.strictEqual(Venom.dripInterval(-1), 4000);
    assert.strictEqual(Venom.dripInterval(3), 600);
  },

  test_load_from_proc_stat() {
    const a = "cpu  1000 20 300 8000 100 0 30 0 0 0\ncpu0 500 10 150 4000 50 0 15 0 0 0\nintr 12345\n";
    // 100 more ticks in all, 50 of them idle (40 idle + 10 iowait).
    const b = "cpu  1030 20 310 8040 110 0 40 0 0 0\ncpu0 515 10 155 4020 55 0 20 0 0 0\nintr 12399\n";
    const first = Venom.parseLoad(null, a);
    assert.strictEqual(first.load, 0, "one sample alone has no load yet");
    assert.ok(first.sample, "the first sample is kept");
    const second = Venom.parseLoad(first.sample, b);
    near(second.load, 0.5, 1e-9, "load");
    assert.ok(second.sample, "the new sample is returned for the next read");
  },

  test_load_parse_garbage() {
    let r = Venom.parseLoad(null, "");
    assert.strictEqual(r.load, 0);
    assert.strictEqual(r.sample, null);
    r = Venom.parseLoad(null, "no cpu here\n");
    assert.strictEqual(r.load, 0);
    assert.strictEqual(r.sample, null);
    r = Venom.parseLoad(null, undefined);
    assert.strictEqual(r.load, 0);
    assert.strictEqual(r.sample, null);
    // A good previous sample with a broken new one: still no error.
    const ok = Venom.parseLoad(null, "cpu  1 2 3 4 5 6 7 8 0 0\n").sample;
    r = Venom.parseLoad(ok, "cpu  x y z\n");
    assert.strictEqual(r.load, 0);
    assert.strictEqual(r.sample, null);
    // A counter that went backwards (a reset) gives no load, not a negative one.
    r = Venom.parseLoad(Venom.parseLoad(null, "cpu  100 0 100 800 0 0 0 0 0 0\n").sample, "cpu  10 0 10 80 0 0 0 0 0 0\n");
    assert.strictEqual(r.load, 0);
  },

  test_landing_picks_window_below() {
    // The fang is at y 200. A tall window starts above it (the fang hangs over
    // its content), two overlapping ones below: the higher of those wins.
    const windows = [
      { x: 0, y: 40, w: 400, h: 800 },
      { x: 150, y: 500, w: 300, h: 300 },
      { x: 100, y: 360, w: 200, h: 300 },
      { x: 600, y: 250, w: 100, h: 100 }
    ];
    assert.strictEqual(Venom.landing(210, 200, windows), 360);
    assert.strictEqual(Venom.landing(320, 200, windows), 500, "outside the higher one's span");
    assert.strictEqual(Venom.landing(650, 200, windows), 250);
    assert.strictEqual(Venom.landing(520, 200, windows), null, "no window under x");
    assert.strictEqual(Venom.landing(210, 200, []), null);
    assert.strictEqual(Venom.landing(210, 200, null), null);
  },

  test_drop_lifecycle() {
    const windows = [{ x: 0, y: 400, w: 300, h: 300 }];
    let d = Venom.newDrop(100, 150);
    assert.strictEqual(d.phase, "bead");

    // Bead: 1.2 s of swelling.
    let r = run(d, windows, 450, x => x.phase !== "bead", 60);
    near(r.t, 1.2, 1 / 60 + 1e-9, "bead time");
    assert.strictEqual(r.drop.phase, "thread");
    // Thread: 0.3 s.
    r = run(r.drop, windows, 450, x => x.phase !== "thread", 60);
    near(r.t, 0.3, 1 / 60 + 1e-9, "thread time");
    assert.strictEqual(r.drop.phase, "fall");
    const y0 = r.drop.y0;
    assert.ok(y0 > 150 && y0 < 175, `falls from just under the fang (${y0})`);

    // Falls with gravity onto the window's top edge.
    r = run(r.drop, windows, 450, x => x.phase !== "fall");
    assert.strictEqual(r.drop.phase, "splash");
    assert.strictEqual(r.drop.y, 400, "lands on the window's top edge");
    const fall = Math.sqrt(2 * (400 - y0) / Venom.GRAVITY);
    near(r.t, fall, 0.03, "fall time under gravity");
    // The splash lasts 0.8 s.
    r = run(r.drop, windows, 450, x => x.phase === "gone");
    near(r.t, 0.8, 1 / 144 + 1e-9, "splash time");
    assert.strictEqual(r.drop.y, 400, "the splash stays put");

    // No window below: it fades by 300 px under where it started.
    d = Venom.newDrop(100, 150);
    r = run(d, [], 150 + 300, x => x.phase === "fade" || x.phase === "gone");
    assert.strictEqual(r.drop.phase, "fade");
    assert.ok(r.drop.y <= 450 + 1e-9, `fades by 300 px (${r.drop.y})`);
    r = run(r.drop, [], 450, x => x.phase === "gone");
    assert.strictEqual(r.drop.phase, "gone");
    assert.ok(r.t < 1.5, "the fade is short");
  },

  test_no_fall_over_window_content() {
    // The fang hangs over a window's content (a tiled window starting near
    // the top): the drop lets go, sags at most 24 px and fades with a tiny
    // ring, never crossing the content; not even onto a window lower down.
    const windows = [{ x: 0, y: 10, w: 400, h: 300 }, { x: 0, y: 330, w: 400, h: 300 }];
    let d = Venom.newDrop(100, 150);
    let r = run(d, windows, 450, x => x.phase === "fall");
    const y0 = r.drop.y0;
    let lowest = y0, phases = new Set();
    let t = 0;
    d = r.drop;
    while (d.phase !== "gone" && t < 5) {
      d = Venom.dropStep(d, 1 / 144, windows, 450);
      phases.add(d.phase);
      lowest = Math.max(lowest, d.y);
      t += 1 / 144;
    }
    assert.ok(d.blocked, "marked as over content");
    assert.ok(!phases.has("splash"), "never splashes across the content");
    assert.ok(phases.has("fade"), "fades");
    assert.ok(lowest - y0 <= Venom.BLOCKED_FALL + 1e-9, `fell ${lowest - y0} px`);
    assert.ok(Venom.BLOCKED_FALL <= 24);
    assert.strictEqual(d.phase, "gone");
  },

  test_covered_is_inside_a_window() {
    const windows = [{ x: 10, y: 10, w: 100, h: 100 }];
    assert.strictEqual(Venom.covered(50, 50, windows), true);
    assert.strictEqual(Venom.covered(50, 5, windows), false, "above it");
    assert.strictEqual(Venom.covered(150, 50, windows), false, "beside it");
    assert.strictEqual(Venom.covered(50, 50, null), false);
  },

  test_bead_follows_the_fang() {
    // Until it snaps, the bead hangs from wherever the fang is.
    let d = Venom.newDrop(100, 150);
    d.x = 104;
    d.anchorY = 152;
    d = Venom.dropStep(d, 0.02, [], 450);
    assert.strictEqual(d.x, 104);
    assert.ok(d.y >= 152, "the bead hangs under the fang");
  },

  test_large_dt_is_clamped() {
    const windows = [{ x: 0, y: 2000, w: 300, h: 300 }];
    const fallen = run(Venom.newDrop(100, 150), windows, 4000, x => x.phase === "fall").drop;
    fallen.t = 0.2;
    fallen.vy = 300;
    const a = Venom.dropStep(Object.assign({}, fallen), 5, windows, 4000);
    const b = Venom.dropStep(Object.assign({}, fallen), 0.05, windows, 4000);
    assert.ok(a.y - fallen.y <= b.y - fallen.y + 1e-9, `moved ${a.y - fallen.y} vs ${b.y - fallen.y}`);
    // And a bead does not skip its whole phase in one stall.
    const bead = Venom.dropStep(Venom.newDrop(100, 150), 5, windows, 4000);
    assert.strictEqual(bead.phase, "bead");
    near(bead.t, 0.05, 1e-9, "bead time after a stall");
  },

  test_clock_step_clamps_per_rate() {
    near(Venom.clockStep(0.05, 15), 0.05, 1e-12, "a normal 15 Hz tick");
    near(Venom.clockStep(1, 15), 2 / 15, 1e-12, "a stall at 15 Hz");
    near(Venom.clockStep(1, 144), 2 / 144, 1e-12, "a stall at 144 Hz");
    assert.strictEqual(Venom.clockStep(-1, 30), 0);
  }
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log("ok   " + name);
  } catch (e) {
    failed++;
    console.log("FAIL " + name + ": " + e.message);
  }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
