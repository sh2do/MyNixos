// Tests for the night shift in modules/umbriel/shell/raven-mood.js: the shared
// night clock (isNight and its debug override), the fade both shells ease
// through, and the dusk tint they apply to their colours.
// Run: nix run nixpkgs#nodejs -- tests/night-test.js
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

function load() {
  const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/raven-mood.js"), "utf8")
    .replace(/^\.pragma library.*$/m, "");
  const Mood = {};
  vm.createContext(Mood);
  vm.runInContext(src, Mood);
  return Mood;
}
const Mood = load();

const near = (a, b, eps, what) => assert.ok(Math.abs(a - b) <= eps, `${what}: ${a} vs ${b}`);
const at = (h, m) => new Date(2026, 10, 7, h, m, 0);
const hex = s => ({ r: parseInt(s.slice(1, 3), 16) / 255, g: parseInt(s.slice(3, 5), 16) / 255, b: parseInt(s.slice(5, 7), 16) / 255, a: 1 });
// WCAG relative luminance and contrast ratio.
const lin = c => (c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));
const lum = c => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
const contrast = (a, b) => { const x = lum(a), y = lum(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); };

const tests = {
  test_forced_night_makes_noon_night() {
    const M = load();
    assert.strictEqual(M.isNight(at(12, 0)), false);
    M.forceNight("1");
    assert.strictEqual(M.isNight(at(12, 0)), true);
    M.forceNight("");
    assert.strictEqual(M.isNight(at(12, 0)), false);
    assert.strictEqual(M.isNight(at(23, 0)), true, "the clock counts again");
  },

  test_forced_day_makes_midnight_day() {
    const M = load();
    M.forceNight("0");
    assert.strictEqual(M.isNight(at(0, 30)), false);
    M.forceNight(undefined);
    assert.strictEqual(M.isNight(at(0, 30)), true);
  },

  test_fade_takes_about_two_minutes_each_way() {
    let f = 0, ms = 0;
    while (f < 1 && ms < 600000) { f = Mood.nightFade(f, true, 2000); ms += 2000; }
    near(ms, 120000, 2000, "dusk");
    while (f > 0 && ms < 1200000) { f = Mood.nightFade(f, false, 2000); ms += 2000; }
    near(ms, 240000, 4000, "dawn");
  },

  test_fade_stays_put_at_its_end_and_clamps() {
    assert.strictEqual(Mood.nightFade(1, true, 2000), 1);
    assert.strictEqual(Mood.nightFade(0, false, 2000), 0);
    assert.strictEqual(Mood.nightFade(0.99, true, 60000), 1);
    assert.strictEqual(Mood.nightFade(0.5, true, -5000), 0.5, "no step backwards");
  },

  test_ease_is_smooth_and_pinned() {
    assert.strictEqual(Mood.nightEase(0), 0);
    assert.strictEqual(Mood.nightEase(1), 1);
    near(Mood.nightEase(0.5), 0.5, 1e-9, "middle");
    assert.ok(Mood.nightEase(0.1) < 0.1, "starts gently");
    assert.strictEqual(Mood.nightEase(-1), 0);
    assert.strictEqual(Mood.nightEase(2), 1);
  },

  test_dusk_by_day_changes_nothing() {
    const c = hex("#dbbce5"), d = Mood.dusk(c, 0, hex("#151315"), 1);
    for (const k of ["r", "g", "b", "a"]) near(d[k], c[k], 1e-9, k);
  },

  test_dusk_dims_surfaces_and_accents_about_twelve_percent() {
    for (const s of ["#dbbce5", "#62496c", "#211f21", "#ffb3b3", "#2c292c"]) {
      const c = hex(s), d = Mood.dusk(c, 1, hex("#151315"), 1);
      const before = (c.r + c.g + c.b) / 3, after = (d.r + d.g + d.b) / 3;
      const drop = 1 - after / before;
      assert.ok(drop > 0.09 && drop < 0.16, `${s} dimmed ${(drop * 100).toFixed(1)}%`);
    }
  },

  test_dusk_cools_toward_blue() {
    const c = hex("#ffb3b3"), d = Mood.dusk(c, 1, hex("#191111"), 1);
    assert.ok(d.b / d.r > c.b / c.r, `blue/red ${d.b / d.r} vs ${c.b / c.r}`);
  },

  test_dusk_keeps_alpha_and_stays_in_range() {
    const d = Mood.dusk({ r: 1, g: 1, b: 1, a: 0.4 }, 1, hex("#000000"), 3);
    assert.strictEqual(d.a, 0.4);
    for (const k of ["r", "g", "b"]) assert.ok(d[k] >= 0 && d[k] <= 1, `${k} ${d[k]}`);
  },

  test_text_keeps_its_contrast_on_the_dimmed_surface() {
    // Surfaces at full strength, text at the lighter strength Theme uses.
    for (const [text, surf, tone] of [["#e7e1e4", "#211f21", "#151315"], ["#f0dfde", "#261d1d", "#191111"], ["#cec3ce", "#151315", "#151315"], ["#d6dbe3", "#14161b", "#0a0b0e"]]) {
      const day = contrast(hex(text), hex(surf));
      const night = contrast(Mood.dusk(hex(text), 1, hex(tone), Mood.TEXT_DUSK), Mood.dusk(hex(surf), 1, hex(tone), 1));
      assert.ok(night >= day * 0.95, `${text} on ${surf}: ${night.toFixed(2)} vs ${day.toFixed(2)}`);
    }
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
