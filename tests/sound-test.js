// Tests for modules/shell/sound.js (run: nix run nixpkgs#nodejs -- tests/sound-test.js).
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/sound.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const S = {};
vm.createContext(S);
vm.runInContext(src, S);

const ok = { env: "", night: false, muted: false, kind: "notify", now: 1000, lastTick: -1e9 };
const q = o => S.shouldPlay(Object.assign({}, ok, o));

const tests = {
  test_plays_by_default() { assert.strictEqual(q({}), true); },
  test_env_zero_switches_off() { assert.strictEqual(q({ env: "0" }), false); },
  test_other_env_values_leave_it_on() {
    assert.strictEqual(q({ env: "1" }), true);
    assert.strictEqual(q({ env: "yes" }), true);
  },
  test_night_mutes() { assert.strictEqual(q({ night: true }), false); },
  test_muted_sink_mutes() { assert.strictEqual(q({ muted: true }), false); },
  test_tick_throttled_to_150ms() {
    assert.strictEqual(q({ kind: "tick", now: 1100, lastTick: 1000 }), false);
    assert.strictEqual(q({ kind: "tick", now: 1150, lastTick: 1000 }), true);
  },
  test_throttle_only_for_ticks() {
    assert.strictEqual(q({ kind: "notify", now: 1010, lastTick: 1000 }), true);
  },
  test_unknown_kind_is_silent() { assert.strictEqual(q({ kind: "boom" }), false); },
  test_sound_names() {
    assert.strictEqual(S.soundFor("notify"), "drop");
    assert.strictEqual(S.soundFor("critical"), "caw");
    assert.strictEqual(S.soundFor("tick"), "tick");
    assert.strictEqual(S.soundFor("boom"), "");
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try { fn(); console.log(`PASS ${name}`); }
  catch (e) { failed++; console.log(`FAIL ${name}\n    ${e.message}`); }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
