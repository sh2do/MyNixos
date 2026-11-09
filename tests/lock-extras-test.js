// Tests for modules/lock/lock.js: what the lock screen's extras show
// (weather glyph and word, the media card's buttons, which player to show).
// Run: nix run nixpkgs#nodejs -- tests/lock-extras-test.js
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

function load() {
  const src = fs.readFileSync(path.join(__dirname, "../modules/lock/lock.js"), "utf8")
    .replace(/^\.pragma library.*$/m, "");
  const L = {};
  vm.createContext(L);
  vm.runInContext(src, L);
  return L;
}
const L = load();

const tests = {
  test_every_weather_kind_has_a_glyph_and_word() {
    for (const k of ["clear", "cloudy", "fog", "drizzle", "rain", "storm", "snow"]) {
      assert.ok(L.weatherGlyph(k).length > 0, k);
      assert.strictEqual(L.weatherWord(k), k);
    }
  },

  test_no_weather_shows_nothing() {
    assert.strictEqual(L.weatherGlyph(""), "");
    assert.strictEqual(L.weatherWord(""), "");
    assert.strictEqual(L.weatherGlyph("tornado"), "");
    assert.strictEqual(L.weatherWord(undefined), "");
  },

  test_night_clear_is_a_moon() {
    assert.notStrictEqual(L.weatherGlyph("clear", false), L.weatherGlyph("clear", true));
  },

  test_card_shows_only_with_a_player() {
    assert.strictEqual(L.hasMedia(null), false);
    assert.strictEqual(L.hasMedia({ trackTitle: "x" }), true);
  },

  test_card_title_falls_back() {
    assert.strictEqual(JSON.stringify(L.cardLines("Song", "Band", "Album", "Player")), JSON.stringify({ top: "Song", bottom: "Band" }));
    assert.strictEqual(JSON.stringify(L.cardLines("", "", "", "Player")), JSON.stringify({ top: "Player", bottom: "" }));
    assert.strictEqual(JSON.stringify(L.cardLines("", "Band", "", "Player")), JSON.stringify({ top: "Band", bottom: "" }));
  },

  test_phone_chip_needs_a_paired_phone() {
    assert.strictEqual(L.showPhone(false, ""), false);
    assert.strictEqual(L.showPhone(true, ""), false, "away: no stale battery");
    assert.strictEqual(L.showPhone(true, "87%"), true);
  },
};

let failed = 0;
for (const [name, fn] of Object.entries(tests)) {
  try { fn(); console.log("ok  " + name); } catch (e) { failed++; console.log("FAIL " + name + "\n  " + e.message); }
}
process.exit(failed ? 1 : 0);
