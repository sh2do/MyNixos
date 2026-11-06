// Tests for modules/umbriel/shell/wall-cover.js (run: nix run nixpkgs#nodejs -- tests/wall-cover-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/wall-cover.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Cover = {};
vm.createContext(Cover);
vm.runInContext(src, Cover);

// The output as Umbriel reports it next to a nested one: eDP-2 sits at x 1280.
const out = { name: "eDP-2", x: 1280, y: 0, w: 1920, h: 1200 };
const rain = { x: 0.1193, y: 0.2408, w: 0.762, h: 0.5175 };
const whole = { x: 0, y: 0, w: 1, h: 1 };

function win(over) {
  return Object.assign({
    output: "eDP-2", visible: true, minimized: false, fullscreen: false, maximized: false,
    x: 1280 + 400, y: 100, w: 700, h: 700,
  }, over);
}

const tests = {
  no_windows_runs() {
    assert.strictEqual(Cover.covered([], out, rain), false);
  },
  small_window_runs() {
    assert.strictEqual(Cover.covered([win()], out, rain), false);
  },
  fullscreen_pauses() {
    assert.strictEqual(Cover.covered([win({ fullscreen: true })], out, whole), true);
  },
  maximized_pauses_even_with_gaps() {
    assert.strictEqual(Cover.covered([win({ maximized: true, x: 1290, y: 10, w: 1900, h: 1180 })], out, whole), true);
  },
  window_over_the_rain_area_pauses() {
    // Tiled, not maximized, with gaps: the black border shows but the rain is hidden.
    assert.strictEqual(Cover.covered([win({ x: 1290, y: 10, w: 1900, h: 1180 })], out, rain), true);
  },
  same_window_does_not_cover_the_whole_screen() {
    assert.strictEqual(Cover.covered([win({ x: 1290, y: 10, w: 1900, h: 1180 })], out, whole), false);
  },
  two_columns_together_cover() {
    const left = win({ x: 1290, y: 10, w: 950, h: 1180 });
    const right = win({ x: 1280 + 950, y: 10, w: 960, h: 1180 });
    assert.strictEqual(Cover.covered([left], out, rain), false);
    assert.strictEqual(Cover.covered([left, right], out, rain), true);
  },
  gap_between_columns_keeps_running() {
    // A 1/3 + 2/3 split: the 16 px gap at local x 640-656 falls between grid lines.
    const left = win({ x: 1290, y: 10, w: 630, h: 1180 });
    const right = win({ x: 1280 + 656, y: 10, w: 1254, h: 1180 });
    assert.strictEqual(Cover.covered([left, right], out, rain), false);
  },
  gap_between_stacked_windows_keeps_running() {
    const top = win({ x: 1290, y: 10, w: 1900, h: 517 });
    const bottom = win({ x: 1290, y: 537, w: 1900, h: 653 });
    assert.strictEqual(Cover.covered([top, bottom], out, rain), false);
  },
  two_columns_touching_cover() {
    const left = win({ x: 1290, y: 10, w: 630, h: 1180 });
    const right = win({ x: 1280 + 640, y: 10, w: 1270, h: 1180 });
    assert.strictEqual(Cover.covered([left, right], out, rain), true);
  },
  powered_off_output_is_off() {
    const outputs = [{ name: "WL-1", powered: true }, { name: "eDP-2", powered: false }];
    assert.strictEqual(Cover.outputOff(outputs, "eDP-2"), true);
    assert.strictEqual(Cover.outputOff(outputs, "WL-1"), false);
  },
  unknown_output_is_not_off() {
    // Before the first outputs event, or outside Umbriel.
    assert.strictEqual(Cover.outputOff([], "eDP-2"), false);
  },
  other_output_ignored() {
    assert.strictEqual(Cover.covered([win({ output: "WL-1", fullscreen: true })], out, whole), false);
  },
  hidden_and_minimized_ignored() {
    assert.strictEqual(Cover.covered([win({ visible: false, fullscreen: true })], out, whole), false);
    assert.strictEqual(Cover.covered([win({ minimized: true, maximized: true })], out, whole), false);
  },
  maximized_but_scrolled_away_runs() {
    assert.strictEqual(Cover.covered([win({ maximized: true, x: 1280 + 1930, y: 10, w: 1900, h: 1180 })], out, whole), false);
  },
  scrolled_out_of_view_ignored() {
    // A "visible" scrolling-layout column that sits off the right edge.
    assert.strictEqual(Cover.covered([win({ x: 1280 + 1930, y: 10, w: 1900, h: 1180 })], out, rain), false);
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log("PASS " + name);
  } catch (e) {
    failed++;
    console.log("FAIL " + name + "\n    " + e.message);
  }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
