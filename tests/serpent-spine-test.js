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
// Thirteen points on three quarters of a circle of radius 100 about (0, 0),
// 22.5 degrees apart. A chord's midpoint sits 1.9 px inside the circle; the
// curve through them must not.
const R = 100;
const ARC = Array.from({ length: 13 }, (_, i) => {
  const a = i * Math.PI / 8;
  return { x: R * Math.cos(a), y: R * Math.sin(a) };
});
const radius = p => Math.hypot(p.x, p.y);

const tests = {
  catmull_passes_through_points() {
    for (let i = 0; i < S.length; i++) {
      const p = Spine.catmull(S, i / (S.length - 1));
      near(p.x, S[i].x, 1e-6); near(p.y, S[i].y, 1e-6);
    }
  },
  catmull_bends_between_points() {
    // Midway between two points the curve stays on the circle, off the chord.
    for (let i = 1; i < ARC.length - 2; i++) {
      const p = Spine.catmull(ARC, (i + 0.5) / (ARC.length - 1));
      near(radius(p), R, 0.3);
    }
  },
  sample_follows_the_curve_not_its_chords() {
    // Every sample comes from the curve itself, so the samples between
    // control points lie on the circle too (away from the clamped ends,
    // where the curve leaves it a little).
    const r = Spine.sample(ARC, 40);
    const len = r[r.length - 1].s;
    const inner = r.filter(p => p.s > len / 12 && p.s < len * 11 / 12);
    assert.ok(inner.length > 25);
    inner.forEach(p => near(radius(p), R, 0.3));
    // Its length is the curve's: the chords alone would come to 1.3% less.
    const arc = R * 1.5 * Math.PI;
    assert.ok(Math.abs(len - arc) / arc < 0.006, "length " + len + " vs " + arc);
  },
  sample_tangent_follows_the_curve() {
    // On the circle the tangent is square to the radius. Sampled from the
    // curve it stays within a couple of degrees of that; a chord's
    // direction is up to 11 degrees off at the control points.
    const r = Spine.sample(ARC, 60);
    const len = r[r.length - 1].s;
    r.filter(p => p.s > len / 12 && p.s < len * 11 / 12).forEach(p => {
      // |sin| of the angle between radius and tangent: 1 when square.
      const cross = Math.abs(p.x * p.ty - p.y * p.tx) / radius(p);
      const off = Math.acos(Math.min(1, cross)) * 180 / Math.PI;
      assert.ok(off < 2.5, "tangent " + off.toFixed(2) + " degrees off");
    });
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
