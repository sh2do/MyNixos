// Tests for modules/shell/focus.js (run: nix run nixpkgs#nodejs -- tests/focus-test.js).
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/focus.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const F = {};
vm.createContext(F);
vm.runInContext(src, F);

// JSON round trip: vm objects come from another realm.
const plain = v => JSON.parse(JSON.stringify(v));
const note = (app, summary, time, extra) =>
  Object.assign({ app: app, icon: "", summary: summary, body: "", time: time }, extra || {});

const tests = {
  test_parse_on_with_start() {
    assert.deepStrictEqual(plain(F.parse("on 1700000000\n")), { on: true, since: 1700000000000 });
  },
  test_parse_off_missing_and_junk() {
    for (const t of ["off\n", "", null, undefined, "maybe 12", "on", "on abc"])
      assert.strictEqual(F.parse(t).on, false, JSON.stringify(t));
  },

  test_route_shows_everything_when_off() {
    assert.strictEqual(F.route(false, "normal"), "show");
    assert.strictEqual(F.route(false, "critical"), "show");
  },
  test_route_holds_normal_while_on() {
    assert.strictEqual(F.route(true, "normal"), "hold");
    assert.strictEqual(F.route(true, "low"), "hold");
  },
  test_route_critical_still_shows_while_on() {
    assert.strictEqual(F.route(true, "critical"), "show");
  },

  test_hold_appends_a_copy() {
    const a = [note("a", "x", 1)];
    const b = F.hold(a, note("b", "y", 2));
    assert.strictEqual(a.length, 1);
    assert.deepStrictEqual(plain(b).map(n => n.app), ["a", "b"]);
  },
  test_hold_is_capped_dropping_the_oldest() {
    let list = [];
    for (let i = 0; i < F.MAX_HELD + 5; i++)
      list = F.hold(list, note("a", "n" + i, i));
    assert.strictEqual(list.length, F.MAX_HELD);
    assert.strictEqual(list[0].summary, "n5");
  },

  test_summary_of_nothing_is_null() {
    assert.strictEqual(F.summary([]), null);
    assert.strictEqual(F.summary(null), null);
  },
  test_summary_title_counts_all() {
    const s = F.summary([note("a", "1", 1), note("b", "2", 2), note("a", "3", 3)]);
    assert.strictEqual(s.count, 3);
    assert.strictEqual(s.title, "3 held while you focused");
  },
  test_summary_title_names_the_game() {
    const s = F.summary([note("a", "1", 1), note("b", "2", 2)], "game");
    assert.strictEqual(s.title, "2 held while you played");
    assert.strictEqual(F.summary([note("a", "1", 1)], "focus").title, "1 held while you focused");
  },

  test_why_focus_wins_then_game_then_nothing() {
    assert.strictEqual(F.why(true, false), "focus");
    assert.strictEqual(F.why(true, true), "focus");
    assert.strictEqual(F.why(false, true), "game");
    assert.strictEqual(F.why(false, false), "");
  },
  test_summary_groups_by_app_newest_first() {
    const s = plain(F.summary([note("Discord", "hi", 1), note("Mail", "inbox", 5), note("Discord", "yo", 9)]));
    assert.deepStrictEqual(s.groups.map(g => [g.app, g.count, g.latest.summary]),
      [["Discord", 2, "yo"], ["Mail", 1, "inbox"]]);
  },
  test_summary_keeps_an_icon_and_names_unknown_apps() {
    const s = plain(F.summary([note("", "x", 1), note("Mail", "a", 2, { icon: "mail" }), note("Mail", "b", 3)]));
    assert.deepStrictEqual(s.groups.map(g => [g.app, g.icon]), [["Mail", "mail"], ["unknown", ""]]);
  },
  test_summary_shows_four_apps_and_counts_the_rest() {
    const list = ["a", "b", "c", "d", "e", "f"].map((app, i) => note(app, "m", i));
    const s = F.summary(list);
    assert.strictEqual(s.groups.length, F.MAX_LINES);
    assert.strictEqual(s.more, 2);
    assert.strictEqual(s.groups[0].app, "f");
  },

  test_line_names_each_app_and_count() {
    const s = F.summary([note("Discord", "a", 1), note("Mail", "b", 2), note("Discord", "c", 3)]);
    assert.strictEqual(F.line(s), "Discord 2 · Mail 1");
  },
  test_line_counts_apps_left_off() {
    const s = F.summary(["a", "b", "c", "d", "e"].map((app, i) => note(app, "m", i)));
    assert.strictEqual(F.line(s), "e 1 · d 1 · c 1 · b 1 · +1 more");
    assert.strictEqual(F.line(null), "");
  },

  test_elapsed_label() {
    const t0 = 1700000000000;
    assert.strictEqual(F.elapsed(t0 + 10000, t0), "0m");
    assert.strictEqual(F.elapsed(t0 + 25 * 60000, t0), "25m");
    assert.strictEqual(F.elapsed(t0 + 65 * 60000, t0), "1h 05m");
    assert.strictEqual(F.elapsed(t0 + 3 * 3600000 + 12 * 60000, t0), "3h 12m");
  },
  test_elapsed_never_negative() {
    assert.strictEqual(F.elapsed(1000, 5000), "0m");
    assert.strictEqual(F.elapsed(1000, 0), "0m");
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
