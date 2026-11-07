// Tests for modules/shell/beat.js (run: nix run nixpkgs#nodejs -- tests/beat-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/beat.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Beat = {};
vm.createContext(Beat);
vm.runInContext(src, Beat);

// Feed `level(t)` every `dt` ms from t0 for `ms`; the times of the beats.
function run(level, ms, dt = 21, state = null, t0 = 0) {
  const beats = [];
  for (let t = t0; t < t0 + ms; t += dt) {
    const r = Beat.beatStep(state, level(t), t);
    state = r.state;
    if (r.beat) beats.push(t);
  }
  return { beats, state };
}

const tests = {
  test_steady_input_gives_no_beats() {
    for (const v of [0, 0.3, 0.9, 1])
      assert.deepStrictEqual(run(() => v, 10000).beats, [], `level ${v}`);
  },

  test_a_little_wobble_is_not_a_beat() {
    const r = run(t => 0.4 + 0.03 * Math.sin(t / 90), 10000);
    assert.deepStrictEqual(r.beats, []);
  },

  test_a_spike_gives_one_beat() {
    const r = run(t => (t >= 3000 && t < 3200 ? 0.9 : 0.2), 6000);
    assert.strictEqual(r.beats.length, 1, `beats ${r.beats}`);
    assert.ok(r.beats[0] >= 3000 && r.beats[0] < 3050, `beat at ${r.beats[0]}`);
  },

  test_spikes_faster_than_twice_a_second_are_rate_limited() {
    // A spike every 200 ms (5/s) for 5 s: at most 2/s get through.
    const r = run(t => (t % 200 < 60 ? 0.9 : 0.1), 5000);
    assert.ok(r.beats.length >= 5, `too few: ${r.beats.length}`);
    for (let i = 1; i < r.beats.length; i++)
      assert.ok(r.beats[i] - r.beats[i - 1] >= Beat.REFRACTORY, `gap ${r.beats[i] - r.beats[i - 1]}`);
    assert.ok(Beat.REFRACTORY >= 500);
  },

  test_spikes_at_a_steady_tempo_each_beat() {
    // 100 bpm, a spike every 600 ms: slower than the cap, so every one counts.
    const r = run(t => ((t + 300) % 600 < 80 ? 0.85 : 0.15), 6000);
    assert.strictEqual(r.beats.length, 10, `beats ${r.beats}`);
  },

  test_silence_then_a_spike_is_a_beat() {
    const r = run(t => (t >= 8000 && t < 8100 ? 0.6 : 0), 9000);
    assert.strictEqual(r.beats.length, 1);
  },

  test_a_tiny_spike_in_silence_is_not_a_beat() {
    // Noise in a quiet room shouldn't flick tails.
    const r = run(t => (t >= 3000 && t < 3100 ? 0.05 : 0), 5000);
    assert.deepStrictEqual(r.beats, []);
  },

  test_garbage_input_is_safe() {
    let state = null;
    for (const [v, t] of [[NaN, 0], [undefined, 21], ["x", 42], [null, 63], [Infinity, 84], [-5, 105], [{}, 126]]) {
      const r = Beat.beatStep(state, v, t);
      assert.strictEqual(r.beat, false, `input ${v}`);
      state = r.state;
    }
    // Still works afterwards.
    const r = run(t => (t >= 3000 && t < 3100 ? 0.9 : 0.1), 4000, 21, state, 200);
    assert.strictEqual(r.beats.length, 1);
    for (const s of [undefined, null, 7, "s", { avg: NaN, last: "q" }]) {
      const r2 = Beat.beatStep(s, 0.5, 100);
      assert.strictEqual(typeof r2.beat, "boolean");
      assert.ok(Number.isFinite(r2.state.avg));
    }
  },

  test_time_going_backwards_is_safe() {
    let { state } = run(() => 0.2, 2000);
    const r = Beat.beatStep(state, 0.9, -50);
    assert.strictEqual(typeof r.beat, "boolean");
    assert.ok(Number.isFinite(r.state.avg));
  },

  // The raven's gate: may it bob to this beat?
  test_bob_allowed_when_perched_and_free() {
    assert.strictEqual(Beat.bobAllowed({ asleep: false, busy: false, hop: false, watching: false, headBusy: false, sinceBob: 5000 }), true);
  },

  test_bob_refused_in_every_other_state() {
    const ok = { asleep: false, busy: false, hop: false, watching: false, headBusy: false, sinceBob: 5000 };
    for (const k of ["asleep", "busy", "hop", "watching", "headBusy"])
      assert.strictEqual(Beat.bobAllowed(Object.assign({}, ok, { [k]: true })), false, k);
  },

  test_bob_capped_at_twice_a_second() {
    const ok = { asleep: false, busy: false, hop: false, watching: false, headBusy: false };
    assert.strictEqual(Beat.bobAllowed(Object.assign({ sinceBob: 499 }, ok)), false);
    assert.strictEqual(Beat.bobAllowed(Object.assign({ sinceBob: 500 }, ok)), true);
  },

  test_bob_gate_is_safe_with_garbage() {
    for (const s of [null, undefined, 3, "x", {}, { sinceBob: NaN }])
      assert.strictEqual(Beat.bobAllowed(s), false);
  },

  test_does_not_mutate_the_old_state() {
    const a = Beat.beatStep(null, 0.2, 0).state;
    const copy = JSON.stringify(a);
    Beat.beatStep(a, 0.9, 1000);
    assert.strictEqual(JSON.stringify(a), copy);
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
