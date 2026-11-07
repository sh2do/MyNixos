// Tests for modules/umbriel/shell/python-pose.js (run: nix run nixpkgs#nodejs -- tests/python-pose-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/python-pose.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Pose = {};
vm.createContext(Pose);
vm.runInContext(src, Pose);

const BW = 22;

// The status row sits at bottom 14 / right 20 of the screen, as Status did:
// a row `w` wide, `h` tall, centred in a 28 px band, 8 px in from its right.
function statusBox(win, w, h) {
  return { x: win.w - 28 - w, y: win.h - 42 + (28 - h) / 2, w: w, h: h };
}
const windows = [{ w: 340, h: 230 }, { w: 420, h: 280 }];
const sizes = [[40, 15], [62, 15], [72, 19]];
const cases = [];
for (const win of windows)
  for (const [w, h] of sizes)
    cases.push([win, statusBox(win, w, h)]);

const coilChains = c => c.back.concat(c.front);
const allChains = c => coilChains(c).concat([c.neck, c.tail]);

const tests = {
  test_python_pose_keeps_clear_of_status_box() {
    for (const [win, box] of cases) {
      const c = Pose.coils(box, 0, 0, win);
      assert.strictEqual(c.back.length, 3);
      assert.strictEqual(c.front.length, 3);
      const g = BW / 2;
      for (const chain of allChains(c)) {
        assert.ok(chain.length >= 2);
        for (const p of chain) {
          const inside = p.x > box.x - g && p.x < box.x + box.w + g && p.y > box.y - g && p.y < box.y + box.h + g;
          assert.ok(!inside, `point ${p.x.toFixed(1)},${p.y.toFixed(1)} inside box ${JSON.stringify(box)}`);
          // Nothing cropped by the screen's edges.
          assert.ok(p.x - g >= 0 && p.x + g <= win.w && p.y - g >= 0 && p.y + g <= win.h,
            `point ${p.x.toFixed(1)},${p.y.toFixed(1)} leaves the ${win.w}x${win.h} window`);
        }
      }
      // The coils sit left of the row, over it.
      for (const r of c.rings)
        assert.ok(r.cx < box.x + box.w / 2, `coil centre ${r.cx} not left of the row`);
    }
  },

  test_coils_are_a_cone_of_flat_ellipses() {
    const c = Pose.coils(cases[1][1], 0, 0, cases[1][0]);
    for (const r of c.rings)
      assert.ok(r.rx / r.ry >= 3 && r.rx / r.ry <= 3.7, `aspect ${(r.rx / r.ry).toFixed(2)}`);
    for (let k = 1; k < 3; k++) {
      assert.ok(c.rings[k].rx < c.rings[k - 1].rx, "each coil narrower than the one below");
      assert.ok(c.rings[k].cy < c.rings[k - 1].cy, "each coil above the one below");
    }
  },

  test_back_and_front_meet() {
    for (const [win, box] of cases) {
      for (const breath of [0, 1, -1]) {
        const c = Pose.coils(box, 0, breath, win);
        // The same coil's halves scale together, so they meet exactly.
        for (let k = 0; k < 3; k++) {
          const b = c.back[k][c.back[k].length - 1], f = c.front[k][0];
          assert.ok(Math.hypot(b.x - f.x, b.y - f.y) <= 0.5, `coil ${k}: back ends ${b.x},${b.y}, front starts ${f.x},${f.y}`);
        }
        // The body is one piece: tail into the bottom back, each front into
        // the next back up, the top front into the neck. Across coils the
        // breath moves the ends apart only slightly.
        const seams = [[c.tail, c.back[0]], [c.front[0], c.back[1]], [c.front[1], c.back[2]], [c.front[2], c.neck]];
        for (const [a, b] of seams) {
          const p = a[a.length - 1], q = b[0];
          assert.ok(Math.hypot(p.x - q.x, p.y - q.y) <= (breath ? 0.6 : 0.5), `seam ${p.x},${p.y} -> ${q.x},${q.y} at breath ${breath}`);
        }
      }
    }
  },

  test_breath_changes_radius_only_slightly() {
    for (const [win, box] of cases) {
      const a = allChains(Pose.coils(box, 0, 1, win)), b = allChains(Pose.coils(box, 0, -1, win));
      let worst = 0;
      for (let i = 0; i < a.length; i++) {
        assert.strictEqual(a[i].length, b[i].length);
        for (let j = 0; j < a[i].length; j++)
          worst = Math.max(worst, Math.hypot(a[i][j].x - b[i][j].x, a[i][j].y - b[i][j].y));
      }
      assert.ok(worst > 0.5, "breath should move the coils at all");
      assert.ok(worst <= 4, `moved ${worst.toFixed(2)} px`);
    }
  },

  test_head_rests_level_with_top_coil() {
    for (const [win, box] of cases) {
      const c = Pose.coils(box, 0, 0, win);
      const top = c.back[2].concat(c.front[2]);
      const crest = top.reduce((m, p) => p.y < m.y ? p : m), left = top.reduce((m, p) => p.x < m.x ? p : m);
      const h = Pose.headPose(Pose.neckEnd(c.neck), 0, 0);
      assert.ok(Math.abs(h.y - crest.y) <= BW, `head at y ${h.y.toFixed(1)}, crest at ${crest.y.toFixed(1)}`);
      assert.ok(h.x < left.x, `head ${h.x.toFixed(1)} not left of the top coil (${left.x.toFixed(1)})`);
      assert.ok(left.x - h.x <= BW * 1.5, `head ${(left.x - h.x).toFixed(1)} px from the top coil`);
      const deg = ((h.angle % 360) + 360) % 360;
      assert.ok(deg >= 150 && deg <= 210, `head faces ${deg.toFixed(1)}°`);
    }
  },

  test_neck_bends_toward_lift_and_look_from_its_root() {
    const [win, box] = cases[1];
    const rest = Pose.coils(box, 0, 0, win).neck;
    const up = Pose.neckFor(rest, 0, 1, null, 0);
    // The root stays on the coil; the head end rises.
    assert.ok(Math.hypot(up[0].x - rest[0].x, up[0].y - rest[0].y) < 1e-9);
    assert.ok(up[up.length - 1].y < rest[rest.length - 1].y - 10);
    // A strike reaches the target with the head end.
    const t = { x: rest[rest.length - 1].x - 60, y: rest[rest.length - 1].y - 50 };
    const hit = Pose.neckFor(rest, 0, 0, t, 1);
    const e = hit[hit.length - 1];
    assert.ok(Math.hypot(e.x - t.x, e.y - t.y) < 1, `strike ends ${e.x},${e.y}`);
    assert.strictEqual(Pose.neckFor(rest, 0, 0, null, 0).length, rest.length);
  },

  test_width_tapers_only_along_the_tail() {
    const c = Pose.bodyChains(Pose.coils(cases[1][1], 0, 0, cases[1][0]));
    const tail = c[c.length - 1];
    assert.strictEqual(tail.name, "tail");
    // Full width all round the coils, then down to a blunt tip.
    // (past the neck's thickening, over the first 8% of the body).
    for (const ch of c.slice(1, -1))
      for (let k = 0; k <= 10; k++) {
        const u = ch.u0 + (ch.u1 - ch.u0) * k / 10;
        if (u >= 0.08)
          assert.ok(Pose.widthAt(u, tail.u0, []) > 0.98, `${ch.name} at ${u.toFixed(3)}`);
      }
    const tip = Pose.widthAt(1, tail.u0, []);
    assert.ok(tip > 0.1 && tip < 0.2, `tip ${tip}`);
    assert.ok(Pose.widthAt(0, tail.u0, []) < 0.9, "the neck is slimmer");
    assert.ok(Pose.widthAt(0.5, tail.u0, [{ u: 0.5, size: 0.4 }]) > 1.3, "a bulge swells");
  },

  test_clock_keeps_speed_at_any_rate() {
    // One second of ticks advances one second, at 10, 30 or 144 Hz...
    for (const hz of [10, 15, 30, 144]) {
      let t = 0;
      for (let i = 0; i < hz; i++)
        t += Pose.clockStep(1 / hz, hz);
      assert.ok(Math.abs(t - 1) < 1e-9, `${hz} Hz advanced ${t}`);
    }
    // ...so ten seconds at 10 Hz hold two 5 s breaths.
    let t = 0;
    for (let i = 0; i < 100; i++)
      t += Pose.clockStep(0.1, 10);
    assert.ok(Math.abs(t / 5 - 2) < 1e-9);
    // A stall is clamped; time never runs backwards.
    assert.strictEqual(Pose.clockStep(3, 10), 0.2);
    assert.strictEqual(Pose.clockStep(-1, 144), 0);
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try { fn(); console.log("PASS " + name); } catch (e) { failed++; console.log("FAIL " + name + ": " + e.message); }
}
console.log((Object.keys(tests).length - failed) + "/" + Object.keys(tests).length + " passed");
process.exit(failed ? 1 : 0);
