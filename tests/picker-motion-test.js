// Tests for modules/shell/picker-motion.js (run: nix run nixpkgs#nodejs -- tests/picker-motion-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/picker-motion.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const M = {};
vm.createContext(M);
vm.runInContext(src, M);

// Runs a spring from x toward target on the picker's clock; returns every x it passed.
function run(spring, x, target, ms) {
  const xs = [];
  let s = { x: x, v: 0 };
  for (let t = 0; t < ms; t += M.FRAME_MS) {
    s = M.step(s.x, s.v, target, M.FRAME_MS, spring);
    xs.push(s.x);
  }
  return { xs: xs, last: s };
}

const tests = {
  test_the_clock_is_capped_at_60_hz() {
    assert.ok(1000 / M.FRAME_MS <= 60, `${1000 / M.FRAME_MS} Hz`);
  },

  test_a_rise_overshoots_a_little_then_settles() {
    const { xs, last } = run(M.RISE, 0, 1, 1200);
    const peak = Math.max(...xs);
    assert.ok(peak > 1.02 && peak < 1.2, `peak ${peak}`);
    assert.ok(M.atRest(last.x, last.v, 1, M.LEVEL_EPS), `not settled: ${JSON.stringify(last)}`);
  },

  test_a_rise_settles_within_half_a_second_or_so() {
    const { xs } = run(M.RISE, 0, 1, 700);
    const tail = xs.slice(-5);
    assert.ok(tail.every(x => Math.abs(x - 1) < 0.02), `tail ${tail}`);
  },

  test_a_glide_never_overshoots() {
    const { xs, last } = run(M.GLIDE, 442, 0, 1200);
    assert.ok(Math.min(...xs) > -0.5, `overshot to ${Math.min(...xs)}`);
    assert.ok(M.atRest(last.x, last.v, 0, M.SHIFT_EPS), `not settled: ${JSON.stringify(last)}`);
  },

  test_a_long_stall_does_not_fling_the_spring() {
    // A dropped frame (or a first tick after a long idle) must not blow up.
    const s = M.step(0, 0, 1, 5000, M.RISE);
    assert.ok(Number.isFinite(s.x) && Math.abs(s.x) < 1.5, `x ${s.x}`);
  },

  test_at_rest_needs_both_place_and_speed() {
    assert.ok(M.atRest(1, 0, 1, M.LEVEL_EPS));
    assert.ok(!M.atRest(1, 0.5, 1, M.LEVEL_EPS), "still moving");
    assert.ok(!M.atRest(0.9, 0, 1, M.LEVEL_EPS), "not there yet");
  },

  test_a_step_at_rest_stays_put() {
    const s = M.step(1, 0, 1, M.FRAME_MS, M.RISE);
    assert.strictEqual(s.x, 1);
    assert.strictEqual(s.v, 0);
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
