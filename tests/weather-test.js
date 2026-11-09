// Tests for modules/shell/weather.js: reading rice-weather's file (stale
// after 3 h, RICE_WEATHER forcing a kind), the scene both shells draw from
// it, and the ~10 s ease between scenes.
// Run: nix run nixpkgs#nodejs -- tests/weather-test.js
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

function load() {
  const src = fs.readFileSync(path.join(__dirname, "../modules/shell/weather.js"), "utf8")
    .replace(/^\.pragma library.*$/m, "");
  const W = {};
  vm.createContext(W);
  vm.runInContext(src, W);
  return W;
}
const W = load();

const NOW = 1_800_000_000;
const file = (o) => JSON.stringify(Object.assign({ kind: "rain", intensity: 0.6, wind: 0.2, isDay: true, updated: NOW - 600 }, o));
const near = (a, b, eps, what) => assert.ok(Math.abs(a - b) <= eps, `${what}: ${a} vs ${b}`);
const scene = (kind, intensity, wind) => W.scene({ kind, intensity, wind: wind || 0, isDay: true, updated: NOW });

const tests = {
  test_reads_a_fresh_file() {
    const w = W.parse(file({}), NOW, "");
    assert.strictEqual(w.kind, "rain");
    assert.strictEqual(w.intensity, 0.6);
    assert.strictEqual(w.wind, 0.2);
  },

  test_stale_after_three_hours() {
    assert.ok(W.parse(file({ updated: NOW - 3 * 3600 + 60 }), NOW, ""), "2h59 is fresh");
    assert.strictEqual(W.parse(file({ updated: NOW - 3 * 3600 - 1 }), NOW, ""), null);
  },

  test_garbage_is_no_weather() {
    assert.strictEqual(W.parse("", NOW, ""), null);
    assert.strictEqual(W.parse("{nope", NOW, ""), null);
    assert.strictEqual(W.parse(file({ kind: "hail-of-frogs" }), NOW, ""), null);
    assert.strictEqual(W.parse(file({ updated: undefined }), NOW, ""), null);
  },

  test_values_are_clamped() {
    const w = W.parse(file({ intensity: 7, wind: -2 }), NOW, "");
    assert.strictEqual(w.intensity, 1);
    assert.strictEqual(w.wind, 0);
  },

  test_forced_kind_wins_even_without_a_file() {
    const w = W.parse("", NOW, "storm");
    assert.strictEqual(w.kind, "storm");
    assert.ok(w.intensity > 0.8 && w.wind > 0.4, "a proper storm");
    assert.strictEqual(W.parse(file({ kind: "clear" }), NOW, "fog").kind, "fog");
    assert.strictEqual(W.parse(file({ updated: 0 }), NOW, "rain").kind, "rain", "stale doesn't matter");
  },

  test_unknown_force_is_ignored() {
    assert.strictEqual(W.parse(file({}), NOW, "frogs").kind, "rain");
    assert.strictEqual(W.parse("", NOW, "frogs"), null);
  },

  test_no_weather_is_todays_scene() {
    assert.deepStrictEqual(JSON.parse(JSON.stringify(W.scene(null))),
      { rain: 1, slant: 0, fall: 1, mist: 1, fog: 0, drops: 0, flash: 1, skyRain: 0 });
  },

  test_clear_day_is_mist_only_and_leaves_the_pond() {
    for (const kind of ["clear", "cloudy"]) {
      const s = scene(kind, 0.5);
      assert.strictEqual(s.rain, 0, kind + ": no streaks");
      assert.ok(s.mist > 0, kind + ": the mist still breathes");
      assert.strictEqual(s.drops, 0, kind + ": the pond is as it was");
      assert.strictEqual(s.fog, 0, kind);
      assert.strictEqual(s.skyRain, 0, kind);
    }
  },

  test_drizzle_rain_storm_get_heavier() {
    const d = scene("drizzle", 0.5), r = scene("rain", 0.5), s = scene("storm", 0.5);
    assert.ok(d.rain > 0 && d.rain < r.rain && r.rain < s.rain, `rain ${d.rain} ${r.rain} ${s.rain}`);
    assert.ok(d.drops > 0 && d.drops < r.drops && r.drops < s.drops, `drops ${d.drops} ${r.drops} ${s.drops}`);
    assert.ok(d.skyRain > 0 && d.skyRain < s.skyRain);
    near(r.rain, 1, 0.25, "medium rain is today's rain");
  },

  test_intensity_scales_within_a_kind() {
    assert.ok(scene("rain", 0.1).rain < scene("rain", 1).rain);
    assert.ok(scene("rain", 0.1).drops < scene("rain", 1).drops);
  },

  test_storm_slants_with_the_wind() {
    const calm = scene("storm", 1, 0), windy = scene("storm", 1, 1);
    assert.ok(calm.slant > 0, "a storm always leans");
    assert.ok(windy.slant > calm.slant);
    assert.ok(scene("rain", 1, 1).slant < windy.slant);
    assert.ok(scene("storm", 1).flash > 1.5, "more lightning");
    assert.ok(scene("clear", 0).flash < 1, "less lightning");
  },

  test_fog_tints_and_snow_falls_slowly() {
    assert.ok(scene("fog", 0.6).fog > 0.3);
    assert.ok(scene("fog", 0.6).mist > 1, "a thicker mist");
    assert.strictEqual(scene("rain", 0.6).fog, 0);
    assert.ok(scene("snow", 0.5).fall < 0.5);
  },

  test_ease_takes_about_ten_seconds() {
    const a = W.scene(null), b = scene("storm", 1, 1);
    let s = a, ms = 0;
    while (!W.settled(s, b) && ms < 60000) { s = W.ease(s, b, 500); ms += 500; }
    assert.ok(ms >= 7000 && ms <= 13000, `settled after ${ms} ms`);
    assert.deepStrictEqual(s, b, "lands exactly");
    const half = W.ease(W.ease(a, b, 500), b, 500);
    assert.ok(half.rain > a.rain && half.rain < b.rain, "moves gradually");
  },

  test_ease_doesnt_jump_on_a_stalled_clock() {
    const a = W.scene(null), b = scene("storm", 1, 1);
    const s = W.ease(a, b, 60000);
    assert.ok(s.rain < b.rain, "a long gap is one capped step");
  },

  test_drop_gap() {
    assert.strictEqual(W.dropGap(0, () => 0.5), null, "no rain: the pond's own dimples");
    const slow = W.dropGap(1, () => 0.5), fast = W.dropGap(10, () => 0.5);
    near(slow, 1000, 1, "one a second");
    near(fast, 100, 1, "ten a second");
    assert.ok(W.dropGap(10, () => 0) < W.dropGap(10, () => 0.999), "jittered");
  }
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try { fn(); console.log("PASS " + name); }
  catch (e) { failed++; console.log("FAIL " + name + "\n    " + e.message); }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
