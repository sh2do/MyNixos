// Tests for modules/shell/notify-group.js (run: nix run nixpkgs#nodejs -- tests/notify-group-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/notify-group.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const G = {};
vm.createContext(G);
vm.runInContext(src, G);

let nextId = 1;
function note(app, time, extra) {
  return Object.assign({ id: nextId++, app, icon: app + "-icon", summary: "s", body: "b", time, urgency: "normal", actions: [] }, extra || {});
}

const tests = {
  test_groups_by_app_newest_first() {
    const list = [note("discord", 1000), note("firefox", 2000), note("discord", 3000)];
    const out = G.group(list);
    assert.strictEqual(out.length, 2);
    assert.strictEqual(out[0].app, "discord");
    assert.strictEqual(out[0].count, 2);
    assert.strictEqual(out[0].latest.time, 3000);
    assert.deepStrictEqual(Array.from(out[0].stack, n => n.time), [1000]);
    assert.strictEqual(out[0].icon, "discord-icon");
    assert.strictEqual(out[1].app, "firefox");
    assert.strictEqual(out[1].count, 1);
    assert.strictEqual(out[1].stack.length, 0);
  },

  test_equal_times_keep_list_order() {
    // The server lists oldest first, so of two equal stamps the later one is newer.
    const a = note("x", 500), b = note("x", 500);
    assert.strictEqual(G.group([a, b])[0].latest.id, b.id);
  },

  test_stack_caps_at_two() {
    const list = [1, 2, 3, 4, 5].map(t => note("discord", t * 1000));
    const out = G.group(list);
    assert.strictEqual(out[0].count, 5);
    assert.strictEqual(out[0].latest.time, 5000);
    assert.deepStrictEqual(Array.from(out[0].stack, n => n.time), [4000, 3000]);
  },

  test_max_four_groups() {
    const list = ["a", "b", "c", "d", "e", "f"].map((app, i) => note(app, i * 1000));
    const out = G.group(list);
    assert.strictEqual(out.length, 4);
    assert.deepStrictEqual(Array.from(out, g => g.app), ["f", "e", "d", "c"]);
  },

  test_missing_app_and_icon() {
    const out = G.group([note("", 1000, { icon: "" }), note(undefined, 2000, { icon: undefined })]);
    assert.strictEqual(out.length, 1, "nameless notifications share one group");
    assert.strictEqual(out[0].app, "unknown");
    assert.strictEqual(out[0].icon, G.GENERIC_ICON);
    assert.ok(G.GENERIC_ICON.length > 0);
    // An icon from any notification in the group is better than the glyph.
    const mixed = G.group([note("app", 1000, { icon: "app-icon" }), note("app", 2000, { icon: "" })]);
    assert.strictEqual(mixed[0].icon, "app-icon");
  },

  test_critical_flag() {
    const out = G.group([note("power", 1000, { urgency: "critical" }), note("power", 2000), note("mail", 3000)]);
    const power = out.find(g => g.app === "power");
    const mail = out.find(g => g.app === "mail");
    assert.strictEqual(power.critical, true, "one critical message keeps the whole card");
    assert.strictEqual(mail.critical, false);
  },

  test_critical_group_always_visible() {
    const list = [note("old", 100, { urgency: "critical" })]
      .concat(["a", "b", "c", "d", "e"].map((app, i) => note(app, 1000 + i)));
    const out = G.group(list);
    assert.strictEqual(out.length, 4);
    assert.ok(out.some(g => g.app === "old"), "the old critical card is pinned");
    assert.deepStrictEqual(Array.from(out, g => g.app), ["e", "d", "c", "old"], "still newest first");
  },

  test_empty_and_bad_input() {
    assert.deepStrictEqual(Array.from(G.group([])), []);
    assert.deepStrictEqual(Array.from(G.group(null)), []);
  },

  test_age_labels() {
    const now = 10 * 86400000;
    assert.strictEqual(G.age(now, now), "now");
    assert.strictEqual(G.age(now, now - 59000), "now");
    assert.strictEqual(G.age(now, now + 5000), "now", "clock skew reads as now");
    assert.strictEqual(G.age(now, now - 2 * 60000), "2m");
    assert.strictEqual(G.age(now, now - 59 * 60000), "59m");
    assert.strictEqual(G.age(now, now - 3600000), "1h");
    assert.strictEqual(G.age(now, now - 23 * 3600000), "23h");
    assert.strictEqual(G.age(now, now - 3 * 86400000), "3d");
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log(`ok   ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${name}: ${e.message}`);
  }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
