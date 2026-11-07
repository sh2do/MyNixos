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
    cases.push(statusBox(win, w, h));

const coilChains = c => c.back.concat(c.front);
const allChains = c => coilChains(c).concat([c.neck, c.tail]);

const tests = {
  test_python_pose_wraps_status_box() {
    for (const box of cases) {
      const c = Pose.coils(box, 0, 0);
      assert.strictEqual(c.back.length, 3);
      assert.strictEqual(c.front.length, 3);
      const g = BW / 2;
      for (const chain of allChains(c)) {
        assert.ok(chain.length >= 2);
        for (const p of chain) {
          const inside = p.x > box.x - g && p.x < box.x + box.w + g && p.y > box.y - g && p.y < box.y + box.h + g;
          assert.ok(!inside, `point ${p.x.toFixed(1)},${p.y.toFixed(1)} inside box ${JSON.stringify(box)}`);
        }
      }
      for (const r of c.rings)
        assert.ok(r.cx >= box.x && r.cx <= box.x + box.w, `coil centre ${r.cx} outside ${box.x}..${box.x + box.w}`);
    }
  },

  test_back_and_front_meet() {
    for (const box of cases) {
      const c = Pose.coils(box, 0, 0);
      for (let k = 0; k < 3; k++) {
        const b = c.back[k][c.back[k].length - 1], f = c.front[k][0];
        assert.ok(Math.hypot(b.x - f.x, b.y - f.y) <= 0.5, `coil ${k}: back ends ${b.x},${b.y}, front starts ${f.x},${f.y}`);
      }
      // And the body is one piece: tail into the bottom back, each front into
      // the next back up, the top front into the neck.
      const seams = [[c.tail, c.back[0]], [c.front[0], c.back[1]], [c.front[1], c.back[2]], [c.front[2], c.neck]];
      for (const [a, b] of seams) {
        const p = a[a.length - 1], q = b[0];
        assert.ok(Math.hypot(p.x - q.x, p.y - q.y) <= 0.5, `seam ${p.x},${p.y} -> ${q.x},${q.y}`);
      }
    }
  },

  test_breath_changes_radius_only_slightly() {
    for (const box of cases) {
      const a = allChains(Pose.coils(box, 0, 1)), b = allChains(Pose.coils(box, 0, -1));
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

  test_head_rests_on_top_coil() {
    for (const box of cases) {
      const c = Pose.coils(box, 0, 0);
      const top = c.back[2].concat(c.front[2]).reduce((m, p) => p.y < m.y ? p : m);
      const h = Pose.headPose(Pose.neckEnd(c.neck), 0, 0);
      const d = Math.hypot(h.x - top.x, h.y - top.y);
      assert.ok(d <= BW, `head ${h.x.toFixed(1)},${h.y.toFixed(1)} is ${d.toFixed(1)} px from the crest ${top.x.toFixed(1)},${top.y.toFixed(1)}`);
      const deg = ((h.angle % 360) + 360) % 360;
      assert.ok(deg >= 150 && deg <= 210, `head faces ${deg.toFixed(1)}°`);
    }
  },

  test_neck_bends_toward_lift_and_look_from_its_root() {
    const box = cases[1];
    const rest = Pose.coils(box, 0, 0).neck;
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
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try { fn(); console.log("PASS " + name); } catch (e) { failed++; console.log("FAIL " + name + ": " + e.message); }
}
console.log((Object.keys(tests).length - failed) + "/" + Object.keys(tests).length + " passed");
process.exit(failed ? 1 : 0);
