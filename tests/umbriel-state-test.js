// Tests for modules/umbriel/shell/umbriel-state.js (run: nix run nixpkgs#nodejs -- tests/umbriel-state-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/umbriel-state.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const State = {};
vm.createContext(State);
vm.runInContext(src, State);

function ws(output, index, over) {
  return Object.assign({ id: output + ":" + index, index, output, active: false, occupied: false, name: String(index) }, over);
}
function win(over) {
  return Object.assign({ output: "eDP-2", workspace: "eDP-2:1", focused: false, fullscreen: false, visible: true, minimized: false }, over);
}

const tests = {
  keeps_only_the_output() {
    const r = State.workspacesFor([ws("WL-1", 1, { active: true }), ws("eDP-2", 1, { active: true })], "eDP-2");
    assert.deepStrictEqual(Array.from(r.map(w => w.id)), ["eDP-2:1"]);
  },
  sorts_by_index() {
    const r = State.workspacesFor([ws("eDP-2", 3), ws("eDP-2", 1), ws("eDP-2", 2, { active: true })], "eDP-2");
    assert.deepStrictEqual(Array.from(r.map(w => w.index)), [1, 2, 3]);
  },
  keeps_only_the_four_fields() {
    const r = State.workspacesFor([ws("eDP-2", 2, { active: true, occupied: true, layout: "scrolling" })], "eDP-2");
    assert.deepStrictEqual(JSON.parse(JSON.stringify(r)), [{ id: "eDP-2:2", index: 2, active: true, occupied: true }]);
  },
  active_and_occupied_are_booleans() {
    const r = State.workspacesFor([{ id: "eDP-2:1", index: 1, output: "eDP-2" }], "eDP-2");
    assert.strictEqual(r[0].active, false);
    assert.strictEqual(r[0].occupied, false);
  },
  empty_or_bad_input_is_empty() {
    assert.strictEqual(State.workspacesFor([], "eDP-2").length, 0);
    assert.strictEqual(State.workspacesFor(null, "eDP-2").length, 0);
  },
  no_windows_not_fullscreen() {
    assert.strictEqual(State.fullscreenFocused([], "eDP-2"), false);
  },
  focused_fullscreen_hides() {
    assert.strictEqual(State.fullscreenFocused([win({ focused: true, fullscreen: true })], "eDP-2"), true);
  },
  unfocused_fullscreen_does_not_hide() {
    assert.strictEqual(State.fullscreenFocused([win({ fullscreen: true })], "eDP-2"), false);
  },
  focused_plain_window_does_not_hide() {
    assert.strictEqual(State.fullscreenFocused([win({ focused: true })], "eDP-2"), false);
  },
  fullscreen_on_another_output_does_not_hide() {
    assert.strictEqual(State.fullscreenFocused([win({ focused: true, fullscreen: true, output: "WL-1" })], "eDP-2"), false);
  },
  hidden_fullscreen_does_not_hide() {
    assert.strictEqual(State.fullscreenFocused([win({ focused: true, fullscreen: true, visible: false })], "eDP-2"), false);
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try { fn(); console.log("PASS " + name); } catch (e) { failed++; console.log("FAIL " + name + ": " + e.message); }
}
console.log((Object.keys(tests).length - failed) + "/" + Object.keys(tests).length + " passed");
process.exit(failed ? 1 : 0);
