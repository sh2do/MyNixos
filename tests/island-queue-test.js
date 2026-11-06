// Tests for modules/umbriel/shell/IslandQueue.js (run: nix run nixpkgs#nodejs -- tests/island-queue-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/IslandQueue.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Q = {};
vm.createContext(Q);
vm.runInContext(src, Q);

const notify = (id, critical) => ({ type: "notify", payload: { id, critical: !!critical } });
const osd = value => ({ type: "osd", payload: { kind: "volume", value } });
const music = title => ({ type: "music", payload: { title } });
const tick = { type: "tick" };
const dismiss = id => ({ type: "dismiss", payload: { id } });

// Feed events in order; each is [atMs, event].
function run(steps, state) {
  let s = state || Q.initial();
  for (const [t, e] of steps)
    s = Q.next(s, e, t);
  return s;
}

const tests = {
  starts_on_the_clock() {
    const s = Q.initial();
    assert.strictEqual(s.view, "clock");
    assert.strictEqual(s.pending.length, 0);
  },
  test_osd_preempts_notify_then_returns() {
    let s = run([[0, notify(1)], [1000, osd(0.5)]]);
    assert.strictEqual(s.view, "osd");
    assert.strictEqual(s.until, 2500);
    s = Q.next(s, tick, 2500);
    assert.strictEqual(s.view, "notify");
    assert.strictEqual(s.item.id, 1);
    // It keeps the 4 s it had left.
    assert.strictEqual(s.until, 6500);
    s = Q.next(s, tick, 6500);
    assert.strictEqual(s.view, "clock");
  },
  osd_repeats_extend_the_osd() {
    const s = run([[0, osd(0.1)], [1000, osd(0.2)]]);
    assert.strictEqual(s.view, "osd");
    assert.strictEqual(s.item.value, 0.2);
    assert.strictEqual(s.until, 2500);
    assert.strictEqual(s.pending.length, 0);
  },
  notify_waits_behind_the_osd() {
    let s = run([[0, osd(0.1)], [500, notify(7)]]);
    assert.strictEqual(s.view, "osd");
    s = Q.next(s, tick, 1500);
    assert.strictEqual(s.view, "notify");
    assert.strictEqual(s.until, 6500);
  },
  notifications_show_one_after_another() {
    let s = run([[0, notify(1)], [1000, notify(2)]]);
    assert.strictEqual(s.item.id, 1);
    s = Q.next(s, tick, 5000);
    assert.strictEqual(s.item.id, 2);
    assert.strictEqual(s.until, 10000);
  },
  test_critical_notify_stays_until_dismissed() {
    let s = run([[0, notify(3, true)], [60000, tick], [600000, tick]]);
    assert.strictEqual(s.view, "notify");
    assert.strictEqual(s.item.id, 3);
    s = Q.next(s, dismiss(3), 600001);
    assert.strictEqual(s.view, "clock");
  },
  same_id_replaces_the_shown_notice() {
    const s = run([[0, notify(1)], [3000, { type: "notify", payload: { id: 1, critical: false, body: "60%" } }]]);
    assert.strictEqual(s.item.body, "60%");
    assert.strictEqual(s.until, 8000);
    assert.strictEqual(s.pending.length, 0);
  },
  same_id_replaces_a_waiting_notice() {
    let s = run([[0, notify(1)], [100, notify(2)], [200, { type: "notify", payload: { id: 2, critical: false, body: "new" } }]]);
    assert.strictEqual(s.pending.length, 1);
    s = Q.next(s, tick, 5000);
    assert.strictEqual(s.item.body, "new");
  },
  critical_cuts_ahead_of_ordinary_notices() {
    let s = run([[0, notify(1)], [100, notify(2)], [1000, notify(3, true)]]);
    assert.strictEqual(s.item.id, 3);
    s = Q.next(s, dismiss(3), 2000);
    // The interrupted notice comes back first, with the 4 s it had left.
    assert.strictEqual(s.item.id, 1);
    assert.strictEqual(s.until, 6000);
  },
  critical_queues_behind_a_critical() {
    const s = run([[0, notify(1, true)], [100, notify(2, true)]]);
    assert.strictEqual(s.item.id, 1);
  },
  critical_returns_after_an_osd() {
    let s = run([[0, notify(3, true)], [1000, osd(0.4)], [2500, tick]]);
    assert.strictEqual(s.view, "notify");
    assert.strictEqual(s.until, Infinity);
  },
  dismissing_a_waiting_notification_drops_it() {
    let s = run([[0, notify(1)], [100, notify(2)], [200, dismiss(2)], [5000, tick]]);
    assert.strictEqual(s.view, "clock");
  },
  dismissing_the_shown_notification_moves_on() {
    let s = run([[0, notify(1)], [100, notify(2)], [200, dismiss(1)]]);
    assert.strictEqual(s.view, "notify");
    assert.strictEqual(s.item.id, 2);
    assert.strictEqual(s.until, 5200);
  },
  test_music_shows_on_track_change_then_clock() {
    let s = run([[0, music("a")]]);
    assert.strictEqual(s.view, "music");
    assert.strictEqual(s.until, 4000);
    s = Q.next(s, tick, 4000);
    assert.strictEqual(s.view, "clock");
  },
  a_new_track_restarts_the_music_view() {
    const s = run([[0, music("a")], [3000, music("b")]]);
    assert.strictEqual(s.item.title, "b");
    assert.strictEqual(s.until, 7000);
  },
  music_waits_behind_a_notification() {
    let s = run([[0, notify(1)], [1000, music("a")]]);
    assert.strictEqual(s.view, "notify");
    s = Q.next(s, tick, 5000);
    assert.strictEqual(s.view, "music");
    assert.strictEqual(s.until, 9000);
  },
  notify_preempts_music() {
    const s = run([[0, music("a")], [1000, notify(1)]]);
    assert.strictEqual(s.view, "notify");
  },
  only_the_newest_track_waits() {
    let s = run([[0, notify(1)], [100, music("a")], [200, music("b")], [5000, tick]]);
    assert.strictEqual(s.item.title, "b");
    s = Q.next(s, tick, 9000);
    assert.strictEqual(s.view, "clock");
  },
  test_tick_expires_view() {
    let s = run([[0, osd(0.3)]]);
    s = Q.next(s, tick, 1499);
    assert.strictEqual(s.view, "osd");
    s = Q.next(s, tick, 1500);
    assert.strictEqual(s.view, "clock");
    assert.strictEqual(s.until, Infinity);
  },
  tick_on_the_clock_changes_nothing() {
    const s0 = Q.initial();
    const s = Q.next(s0, tick, 99999);
    assert.strictEqual(s.view, "clock");
    assert.strictEqual(s.pending.length, 0);
  },
  does_not_mutate_the_old_state() {
    const s0 = run([[0, notify(1)]]);
    Q.next(s0, osd(0.5), 100);
    assert.strictEqual(s0.view, "notify");
    assert.strictEqual(s0.pending.length, 0);
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log("PASS " + name);
  } catch (e) {
    failed++;
    console.log("FAIL " + name + ": " + e.message);
  }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
