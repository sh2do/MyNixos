// Tests for modules/umbriel/shell/season.js: the one season clock both shells
// read (which season a date is, RICE_SEASON's override, what each season
// touches given the night, the weather and focus mode) and the few sprites
// it drifts (petals, snow, fireflies).
// Run: nix run nixpkgs#nodejs -- tests/season-test.js
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/season.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const S = {};
vm.createContext(S);
vm.runInContext(src, S);

const day = (m, d) => new Date(2026, m - 1, d, 12, 0, 0);
const seeded = seed => () => (seed = (seed * 16807) % 2147483647) / 2147483647;
const box = { x: 10, y: 0, w: 400, h: 34, k: 1, drift: 1.5, land: [0.3, 0.9] };
const ctx = (o) => Object.assign({ night: false, weather: "", focus: false }, o || {});

// Run one sprite for `secs` at the shells' rate; returns what it went through.
function run(sprite, secs, b, seed) {
  const rand = seeded(seed || 3);
  const p = S.spawn(sprite, b || box, rand);
  const dt = 1 / S.HZ;
  const seen = { states: [], splashes: 0, xs: [], ys: [], ops: [], p };
  for (let t = 0; t < secs; t += dt) {
    S.step(p, sprite, dt, b || box, rand);
    if (seen.states[seen.states.length - 1] !== p.state)
      seen.states.push(p.state);
    if (p.splash)
      seen.splashes++;
    seen.xs.push(p.x);
    seen.ys.push(p.y);
    seen.ops.push(p.opacity);
  }
  return seen;
}

const tests = {
  test_months_map_to_seasons() {
    const want = { 1: "none", 2: "none", 3: "spring", 4: "spring", 5: "spring", 6: "summer", 7: "summer",
      8: "summer", 9: "none", 10: "october", 11: "none", 12: "december" };
    for (const [m, s] of Object.entries(want)) {
      assert.strictEqual(S.seasonOf(day(+m, 1)), s, `month ${m} on the 1st`);
      assert.strictEqual(S.seasonOf(day(+m, 28)), s, `month ${m} on the 28th`);
    }
    assert.strictEqual(S.seasonOf(new Date(2026, 4, 31, 23, 59)), "spring");
    assert.strictEqual(S.seasonOf(new Date(2026, 8, 1, 0, 0)), "none");
  },

  test_rice_season_forces_one() {
    for (const s of ["spring", "summer", "october", "december"])
      assert.strictEqual(S.season(day(11, 9), s), s);
    assert.strictEqual(S.season(day(12, 20), "none"), "none", "none forces nothing even in December");
    assert.strictEqual(S.season(day(12, 20), ""), "december");
    assert.strictEqual(S.season(day(12, 20), undefined), "december");
    assert.strictEqual(S.season(day(12, 20), "winter"), "december", "an unknown name is the clock");
  },

  test_each_season_touches() {
    const sp = S.touches("spring", ctx());
    assert.strictEqual(sp.sprite, "petals");
    assert.ok(sp.count > 0 && sp.count <= 8, `a few petals: ${sp.count}`);
    assert.strictEqual(sp.trinkets, false);

    assert.strictEqual(S.touches("summer", ctx()).count, 0, "no fireflies by day");
    const su = S.touches("summer", ctx({ night: true }));
    assert.strictEqual(su.sprite, "fireflies");
    assert.ok(su.count > 0 && su.count <= 8);

    const oc = S.touches("october", ctx());
    assert.strictEqual(oc.count, 0);
    assert.strictEqual(oc.trinkets, true);
    assert.strictEqual(oc.flicker, true);

    const de = S.touches("december", ctx());
    assert.strictEqual(de.sprite, "snow");
    assert.ok(de.count > 0 && de.count <= 12, `sparse snow: ${de.count}`);

    const no = S.touches("none", ctx({ night: true }));
    assert.strictEqual(no.count, 0);
    assert.strictEqual(no.trinkets, false);
    assert.strictEqual(no.sprite, "");
  },

  test_rain_and_storm_keep_the_sky_clear() {
    for (const w of ["rain", "storm"]) {
      assert.strictEqual(S.touches("spring", ctx({ weather: w })).count, 0, `petals in ${w}`);
      assert.strictEqual(S.touches("december", ctx({ weather: w })).count, 0, `snow in ${w}`);
      assert.strictEqual(S.touches("summer", ctx({ weather: w, night: true })).count, 0, `fireflies in ${w}`);
      assert.strictEqual(S.touches("october", ctx({ weather: w })).trinkets, true, "the hoard is indoors");
    }
    for (const w of ["", "clear", "cloudy", "fog", "drizzle", "snow"])
      assert.ok(S.touches("december", ctx({ weather: w })).count > 0, `snow in ${w || "no weather"}`);
  },

  test_focus_pauses_it() {
    for (const s of ["spring", "summer", "december"])
      assert.strictEqual(S.touches(s, ctx({ focus: true, night: true })).count, 0, s);
    const oc = S.touches("october", ctx({ focus: true }));
    assert.strictEqual(oc.trinkets, true, "the trinkets stay");
    assert.strictEqual(oc.flicker, false, "the candle holds still");
  },

  test_capped_clock() {
    assert.ok(S.HZ > 0 && S.HZ <= 20, `HZ ${S.HZ}`);
  },

  test_sprites_makes_the_count() {
    assert.strictEqual(S.sprites(S.touches("spring", ctx()), box, seeded(1)).length, S.touches("spring", ctx()).count);
    assert.strictEqual(S.sprites(S.touches("none", ctx()), box, seeded(1)).length, 0);
    assert.strictEqual(S.sprites(S.touches("october", ctx()), box, seeded(1)).length, 0);
  },

  test_petal_falls_settles_once_and_comes_back() {
    const r = run("petals", 120);
    assert.ok(r.states.indexOf("fall") >= 0 && r.states.indexOf("float") > r.states.indexOf("fall"), r.states.join(","));
    // It goes round again: wait -> fall -> float -> wait -> fall ...
    assert.ok(r.states.filter(s => s === "fall").length >= 2, "it comes back: " + r.states.join(","));
    // One ring per landing.
    assert.strictEqual(r.splashes, r.states.filter(s => s === "float").length);
    for (const o of r.ops)
      assert.ok(o >= 0 && o <= 1, `opacity ${o}`);
    for (const x of r.xs)
      assert.ok(x >= box.x - 8 && x <= box.x + box.w + 8, `x ${x} strays`);
    for (const y of r.ys)
      assert.ok(y >= box.y - 8 && y <= box.y + box.h, `y ${y} strays`);
  },

  test_petal_lands_in_the_water_band() {
    const rand = seeded(9);
    const dt = 1 / S.HZ;
    for (let n = 0; n < 20; n++) {
      const p = S.spawn("petals", box, rand);
      let guard = 0;
      while (!p.splash && guard++ < 10000)
        S.step(p, "petals", dt, box, rand);
      assert.ok(p.splash, "it lands");
      const f = (p.y - box.y) / box.h;
      assert.ok(f >= box.land[0] - 0.01 && f <= box.land[1] + 0.01, `landed at ${f}`);
    }
  },

  test_snow_melts_where_it_lands() {
    const r = run("snow", 90, box, 5);
    assert.ok(r.states.indexOf("melt") > 0, r.states.join(","));
    assert.strictEqual(r.splashes, r.states.filter(s => s === "melt").length);
    // A melt is short: never more than a second of it in a row.
    const p = r.p;
    assert.ok(p.state !== "melt" || p.t <= 1.01);
  },

  test_fireflies_stay_and_blink() {
    const b = { x: 0, y: 0, w: 300, h: 34, k: 1, drift: 0, land: [0.3, 0.9] };
    const r = run("fireflies", 60, b, 11);
    assert.strictEqual(r.splashes, 0);
    for (let i = 0; i < r.xs.length; i++) {
      assert.ok(r.xs[i] >= b.x && r.xs[i] <= b.x + b.w, `x ${r.xs[i]}`);
      assert.ok(r.ys[i] >= b.y && r.ys[i] <= b.y + b.h, `y ${r.ys[i]}`);
    }
    assert.ok(Math.max(...r.ops) > 0.8, "it glows");
    assert.ok(Math.min(...r.ops.slice(S.HZ * 10)) < 0.1, "and goes dark between");
  },

  test_a_stall_does_not_teleport() {
    const rand = seeded(2);
    const p = S.spawn("snow", box, rand);
    // Into the fall first.
    let guard = 0;
    while (p.state !== "fall" && guard++ < 10000)
      S.step(p, "snow", 1 / S.HZ, box, rand);
    const y = p.y;
    S.step(p, "snow", 30, box, rand);
    assert.ok(Math.abs(p.y - y) < box.h * 0.2, `jumped ${p.y - y}`);
  },

  test_a_bigger_box_falls_further() {
    // Umbriel's field is tall; a fall takes seconds there too, not minutes.
    const tall = { x: 0, y: 0, w: 800, h: 900, k: 2, drift: 0, land: [0.6, 1] };
    const rand = seeded(4);
    const p = S.spawn("petals", tall, rand);
    let t = 0, guard = 0;
    while (p.state !== "fall" && guard++ < 10000)
      S.step(p, "petals", 1 / S.HZ, tall, rand);
    while (!p.splash && t < 60) {
      S.step(p, "petals", 1 / S.HZ, tall, rand);
      t += 1 / S.HZ;
    }
    assert.ok(p.splash && t < 20, `fell for ${t} s`);
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
