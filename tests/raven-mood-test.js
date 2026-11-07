// Tests for modules/umbriel/shell/raven-mood.js (run: nix run nixpkgs#nodejs -- tests/raven-mood-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/raven-mood.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Mood = {};
vm.createContext(Mood);
vm.runInContext(src, Mood);

const near = (a, b, eps, what) => assert.ok(Math.abs(a - b) <= eps, `${what}: ${a} vs ${b}`);
const at = (h, m) => new Date(2026, 10, 7, h, m, 0);

// Step the watch machine with a pointer held still from `still` ms, in
// `dt` ms steps, for `ms`; returns every phase it passed through, in order.
function phases(state, x, y, still, ms, dt) {
  const seen = [];
  for (let t = 0; t <= ms; t += dt) {
    state = Mood.watchState(state, { x: x, y: y, still: still + t }, dt);
    if (seen[seen.length - 1] !== state.phase)
      seen.push(state.phase);
  }
  return { state, seen };
}

const tests = {
  test_night_window() {
    assert.strictEqual(Mood.isNight(at(20, 59)), false);
    assert.strictEqual(Mood.isNight(at(21, 0)), true);
    assert.strictEqual(Mood.isNight(at(3, 0)), true);
    assert.strictEqual(Mood.isNight(at(5, 59)), true);
    assert.strictEqual(Mood.isNight(at(6, 0)), false);
    assert.strictEqual(Mood.isNight(at(12, 0)), false);
  },

  test_idle_intervals_in_range() {
    const ranges = { blink: [4000, 9000], look: [6000, 14000], ruffle: [120000, 240000], preen: [300000, 600000] };
    // A seeded generator, plus both ends of rand's range.
    let seed = 7;
    const rand = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    for (const [kind, [lo, hi]] of Object.entries(ranges)) {
      const now = 1e6;
      for (let i = 0; i < 200; i++) {
        const d = Mood.nextIdle(kind, now, rand) - now;
        assert.ok(d >= lo && d <= hi, `${kind}: ${d} outside ${lo}-${hi}`);
      }
      assert.strictEqual(Mood.nextIdle(kind, now, () => 0) - now, lo);
      assert.ok(Mood.nextIdle(kind, now, () => 0.999999) - now <= hi);
    }
  },

  test_watch_sequence() {
    let s = Mood.watchState(null, null, 0);
    assert.strictEqual(s.phase, "idle");
    s = Mood.watchState(s, { x: 10, y: 20, still: 1900 }, 16);
    assert.strictEqual(s.phase, "idle");
    s = Mood.watchState(s, { x: 10, y: 20, still: 2000 }, 16);
    assert.strictEqual(s.phase, "watch");
    assert.deepStrictEqual({ x: s.target.x, y: s.target.y }, { x: 10, y: 20 });
    s = Mood.watchState(s, { x: 10, y: 20, still: 4999 }, 16);
    assert.strictEqual(s.phase, "watch");
    s = Mood.watchState(s, { x: 10, y: 20, still: 5000 }, 16);
    assert.strictEqual(s.phase, "hop");
    // Then peck (300 ms), settle (600 ms) and back to idle, in order, with
    // the pointer still resting there.
    const r = phases(s, 10, 20, 5000, 3000, 10);
    assert.deepStrictEqual(r.seen, ["hop", "peck", "settle", "idle"]);
    // The peck lasts 300 ms and the settle 600 ms.
    let p = s, t = 0, peckAt = -1, settleAt = -1, idleAt = -1;
    while (idleAt < 0 && t < 5000) {
      p = Mood.watchState(p, { x: 10, y: 20, still: 5000 + t }, 1);
      t += 1;
      if (p.phase === "peck" && peckAt < 0) peckAt = t;
      if (p.phase === "settle" && settleAt < 0) settleAt = t;
      if (p.phase === "idle" && idleAt < 0) idleAt = t;
    }
    near(settleAt - peckAt, 300, 1, "peck length");
    near(idleAt - settleAt, 600, 1, "settle length");
    // Having pecked, it doesn't hop at the same resting pointer again.
    assert.strictEqual(r.state.phase, "idle");
    assert.strictEqual(Mood.watchState(r.state, { x: 10, y: 20, still: 9000 }, 16).phase, "idle");
  },

  test_watch_calms_when_pointer_moves() {
    let s = Mood.watchState(null, { x: 5, y: 5, still: 2500 }, 16);
    assert.strictEqual(s.phase, "watch");
    // The pointer moved: its still time starts again.
    s = Mood.watchState(s, { x: 40, y: 8, still: 0 }, 16);
    assert.strictEqual(s.phase, "idle");
    // Or it left the window.
    s = Mood.watchState(Mood.watchState(null, { x: 5, y: 5, still: 2500 }, 16), null, 16);
    assert.strictEqual(s.phase, "idle");
    // Watching follows the pointer while it rests.
    s = Mood.watchState(null, { x: 5, y: 5, still: 2500 }, 16);
    s = Mood.watchState(s, { x: 5, y: 5, still: 2600 }, 16);
    assert.strictEqual(s.target.x, 5);
    // After a peck, a move makes it ready to watch again.
    let p = Mood.watchState(null, { x: 5, y: 5, still: 5000 }, 16);
    p = phases(p, 5, 5, 5000, 3000, 10).state;
    p = Mood.watchState(p, { x: 9, y: 5, still: 0 }, 16);
    p = Mood.watchState(p, { x: 9, y: 5, still: 2100 }, 16);
    assert.strictEqual(p.phase, "watch");
  },

  test_hoard_caps_at_three_and_fades() {
    let h = [];
    for (let i = 0; i < 4; i++)
      h = Mood.hoardAdd(h, 1000 * i);
    assert.strictEqual(h.length, 3);
    assert.deepStrictEqual(h.map(t => t.at), [1000, 2000, 3000]);
    // Each keeps a slot of its own on the row; the new one takes the freed slot.
    assert.deepStrictEqual(h.map(t => t.slot).sort(), [0, 1, 2]);
    near(h[2].opacity, 1, 1e-9, "a new trinket");
    // Halfway through its 10 minutes, half faded.
    const half = Mood.hoardStep(h, 1000 + 300000);
    near(half[0].opacity, 0.5, 1e-9, "after 5 minutes");
    assert.ok(half[2].opacity > half[0].opacity, "the oldest fades first");
    // After 10 minutes all are gone.
    assert.strictEqual(Mood.hoardStep(h, 3000 + 600000).length, 0);
    // A step long past due removes them once and doesn't throw.
    const gone = Mood.hoardStep(h, 1e12);
    assert.strictEqual(gone.length, 0);
    assert.strictEqual(Mood.hoardStep(gone, 1e12 + 1).length, 0);
    // Stepping doesn't change the hoard it was given.
    assert.strictEqual(h.length, 3);
  },

  test_clock_step_clamps_per_rate() {
    near(Mood.clockStep(0.1, 10), 0.1, 1e-12, "a normal 10 Hz tick");
    near(Mood.clockStep(1, 10), 0.2, 1e-12, "a stall at 10 Hz");
    near(Mood.clockStep(1, 30), 2 / 30, 1e-12, "a stall at 30 Hz");
    near(Mood.clockStep(1, 144), 2 / 144, 1e-12, "a stall at 144 Hz");
    assert.strictEqual(Mood.clockStep(-1, 30), 0);
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
