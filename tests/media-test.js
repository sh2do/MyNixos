// Tests for modules/shell/media.js (run: nix run nixpkgs#nodejs -- tests/media-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/media.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const Media = {};
vm.createContext(Media);
vm.runInContext(src, Media);

// vm arrays come from another realm, so compare them as plain arrays.
const plain = a => Array.from(a);

const tests = {
  test_pick_player_keeps_paused_player() {
    const a = { playbackState: "Playing" }, b = { playbackState: "Paused" }, c = { playbackState: "Stopped" };
    // A playing player always wins.
    assert.strictEqual(Media.pickPlayer([b, a], b, true, "Playing", "Paused"), a);
    // Paused after playing: kept while asked to keep it, so the pill can resume it.
    assert.strictEqual(Media.pickPlayer([b], b, true, "Playing", "Paused"), b);
    // Not kept once the grace and hover are over.
    assert.strictEqual(Media.pickPlayer([b], b, false, "Playing", "Paused"), null);
    // A stopped or vanished player is never kept.
    assert.strictEqual(Media.pickPlayer([c], c, true, "Playing", "Paused"), null);
    assert.strictEqual(Media.pickPlayer([], b, true, "Playing", "Paused"), null);
    assert.strictEqual(Media.pickPlayer([], null, true, "Playing", "Paused"), null);
  },
  test_parse_cava() {
    const max = Media.CAVA_MAX;
    assert.deepStrictEqual(plain(Media.parseCava(`0;${max / 2};${max};${max / 4};0;`, 5)), [0, 0.5, 1, 0.25, 0]);
    // No trailing delimiter, and a stray newline, are fine too.
    assert.deepStrictEqual(plain(Media.parseCava(`${max};0;0;0;${max}\n`, 5)), [1, 0, 0, 0, 1]);
    // Values beyond the range are clamped.
    assert.deepStrictEqual(plain(Media.parseCava(`${max * 3};0;0;0;0;`, 5)), [1, 0, 0, 0, 0]);
  },

  test_parse_cava_garbage() {
    const zeros = [0, 0, 0, 0, 0];
    for (const line of ["", "hello", "1;2;3;", "1;2;3;4;5;6;", "1;x;3;4;5;", ";;;;;", null, undefined])
      assert.deepStrictEqual(plain(Media.parseCava(line, 5)), zeros, `line ${JSON.stringify(line)}`);
  },

  test_progress_unknown_length() {
    assert.strictEqual(Media.progress(30, 0), 0);
    assert.strictEqual(Media.progress(30, -1), 0);
    assert.strictEqual(Media.progress(30, undefined), 0);
    assert.strictEqual(Media.progress(30, NaN), 0);
    assert.strictEqual(Media.progress(undefined, 200), 0);
    assert.strictEqual(Media.progress(50, 200), 0.25);
    assert.strictEqual(Media.progress(500, 200), 1);
    assert.strictEqual(Media.progress(-5, 200), 0);
  },

  test_artist_fallback() {
    assert.deepStrictEqual({ ...Media.fmtArtist("Blink", "Hiroshi Yoshimura") }, { top: "Blink", bottom: "Hiroshi Yoshimura" });
    assert.deepStrictEqual({ ...Media.fmtArtist("Blink", "Hiroshi Yoshimura", "Wet Land") }, { top: "Blink", bottom: "Hiroshi Yoshimura · Wet Land" });
    assert.deepStrictEqual({ ...Media.fmtArtist("Blink", "") }, { top: "Blink", bottom: "" });
    assert.deepStrictEqual({ ...Media.fmtArtist("Blink", undefined, "") }, { top: "Blink", bottom: "" });
    // No title: the artist moves up rather than leaving the top line empty.
    assert.deepStrictEqual({ ...Media.fmtArtist("", "Hiroshi Yoshimura") }, { top: "Hiroshi Yoshimura", bottom: "" });
  },

  test_pulse_stays_in_range_and_moves() {
    const a = plain(Media.pulse(10, 5)), b = plain(Media.pulse(10.3, 5));
    assert.strictEqual(a.length, 5);
    for (const v of a.concat(b)) assert.ok(v >= 0 && v <= 1, `value ${v}`);
    assert.notDeepStrictEqual(a, b);
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try {
    fn();
    console.log(`PASS ${name}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${name}\n    ${e.message}`);
  }
}
console.log(`${Object.keys(tests).length - failed}/${Object.keys(tests).length} passed`);
process.exit(failed ? 1 : 0);
