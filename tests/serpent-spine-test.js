// Tests for modules/umbriel/shell/serpent-spine.js (run: nix run nixpkgs#nodejs -- tests/serpent-spine-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/serpent-spine.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Spine = {};
vm.createContext(Spine);
vm.runInContext(src, Spine);

const S = [{ x: 0, y: 0 }, { x: 40, y: 30 }, { x: 90, y: 40 }, { x: 140, y: 10 }, { x: 190, y: -20 }, { x: 240, y: 0 }];
const near = (a, b, eps) => assert.ok(Math.abs(a - b) <= eps, a + " vs " + b);

const tests = {
  catmull_passes_through_points() {
    for (let i = 0; i < S.length; i++) {
      const p = Spine.catmull(S, i / (S.length - 1));
      near(p.x, S[i].x, 1e-6); near(p.y, S[i].y, 1e-6);
    }
  },
  sample_is_evenly_spaced() {
    const r = Spine.sample(S, 30);
    assert.strictEqual(r.length, 30);
    const gaps = r.slice(1).map((p, i) => p.s - r[i].s);
    const mean = gaps.reduce((a, b) => a + b) / gaps.length;
    gaps.forEach(g => assert.ok(Math.abs(g - mean) / mean < 0.02));
    r.forEach(p => near(Math.hypot(p.tx, p.ty), 1, 1e-9));
  },
  sample_spans_the_ends_in_24_points() {
    const r = Spine.sample(S, Spine.SPINE_POINTS);
    assert.strictEqual(r.length, 24);
    assert.strictEqual(Spine.SPINE_POINTS, 24);
    near(r[0].x, S[0].x, 1e-9); near(r[0].y, S[0].y, 1e-9);
    near(r[23].x, 240, 1e-6); near(r[23].y, 0, 1e-6);
  },
  width_tapers_to_tail() {
    near(Spine.widthAt(1, []), 0.2, 1e-9);
    near(Spine.widthAt(0.4, []), 1, 1e-9);
    near(Spine.widthAt(0, []), 0.85, 1e-9);
  },
  bulge_adds_width_locally() {
    const b = [{ u: 0.5, size: 0.6 }];
    assert.ok(Spine.widthAt(0.5, b) >= 1.55);
    assert.ok(Spine.widthAt(0.7, b) < 1.01);
  },
  step_clamps_dt() {
    assert.strictEqual(Spine.step(3), 0.05);
    assert.strictEqual(Spine.step(-1), 0);
    assert.strictEqual(Spine.step(0.007), 0.007);
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try { fn(); console.log("PASS " + name); } catch (e) { failed++; console.log("FAIL " + name + ": " + e.message); }
}
console.log((Object.keys(tests).length - failed) + "/" + Object.keys(tests).length + " passed");
process.exit(failed ? 1 : 0);
