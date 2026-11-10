// Tests for modules/shell/power.js (run: nix run nixpkgs#nodejs -- tests/power-test.js).
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/power.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const P = {};
vm.createContext(P);
vm.runInContext(src, P);

const tests = {
  test_glyphs() {
    assert.strictEqual(P.glyph("power-saver"), "󰾆");
    assert.strictEqual(P.glyph("balanced"), "󰾅");
    assert.strictEqual(P.glyph("performance"), "󰓅");
    assert.strictEqual(P.glyph(""), "󰾅");
    assert.strictEqual(P.glyph(undefined), "󰾅");
  },

  test_next_cycles_with_performance() {
    assert.strictEqual(P.next("power-saver", true), "balanced");
    assert.strictEqual(P.next("balanced", true), "performance");
    assert.strictEqual(P.next("performance", true), "power-saver");
  },
  test_next_skips_missing_performance() {
    assert.strictEqual(P.next("balanced", false), "power-saver");
    assert.strictEqual(P.next("power-saver", false), "balanced");
  },
  test_next_from_unknown_starts_at_saver() {
    assert.strictEqual(P.next("", true), "power-saver");
    assert.strictEqual(P.next(undefined, false), "power-saver");
  },

  test_fan_mode() {
    assert.strictEqual(P.fanMode("fan max  cpu 5900 rpm  gpu 5700 rpm\n"), "max");
    assert.strictEqual(P.fanMode("fan auto  cpu 2300 rpm  gpu 2100 rpm"), "auto");
    assert.strictEqual(P.fanMode("fan manual  cpu 1 rpm  gpu 1 rpm"), "manual");
  },
  test_fan_mode_without_control() {
    for (const t of ["", null, undefined, "rice-fan: no hp-wmi fan control", "garbage"])
      assert.strictEqual(P.fanMode(t), "", JSON.stringify(t));
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log("PASS " + name);
  } catch (e) {
    failed++;
    console.log("FAIL " + name + "\n    " + e.message);
  }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
