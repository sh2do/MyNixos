// Tests for modules/umbriel/shell/fuzzy.js (run: nix run nixpkgs#nodejs -- tests/fuzzy-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/umbriel/shell/fuzzy.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const F = {};
vm.createContext(F);
vm.runInContext(src, F);

const apps = names => names.map(name => ({ name }));
const names = entries => Array.from(entries, e => e.name);

const tests = {
  test_prefix_beats_substring() {
    // Profile Manager and Wifi have "fi" mid-word; Thunderbird has no f at all.
    const r = names(F.rank("fi", apps(["Profile Manager", "Thunderbird", "Wifi", "Firefox", "Files", "Text Finder"])));
    assert.deepStrictEqual(r.slice(0, 2), ["Files", "Firefox"]);
    assert.ok(!r.includes("Thunderbird"));
    // A word start ranks above a mid-word match.
    assert.ok(r.indexOf("Text Finder") < r.indexOf("Wifi"));
    assert.ok(r.indexOf("Text Finder") < r.indexOf("Profile Manager"));
  },
  test_no_match_returns_empty() {
    assert.strictEqual(F.rank("xqzv", apps(["Firefox", "Files", "foot"])).length, 0);
  },
  test_case_insensitive() {
    assert.deepStrictEqual(names(F.rank("FIR", apps(["firefox", "Kate"]))), ["firefox"]);
    assert.deepStrictEqual(names(F.rank("fir", apps(["FIREFOX", "Kate"]))), ["FIREFOX"]);
  },
  letters_together_beat_a_later_word_start() {
    // "fir": Firefox has it whole; File Roller only as Fi… R.
    assert.deepStrictEqual(names(F.rank("fir", apps(["File Roller", "Firefox"]))), ["Firefox", "File Roller"]);
  },
  subsequence_matches_count() {
    // f…r…x, scattered, still matches.
    assert.deepStrictEqual(names(F.rank("frx", apps(["Firefox", "Files"]))), ["Firefox"]);
    // However far apart.
    assert.strictEqual(F.rank("bz", apps(["b" + "o".repeat(40) + "z"])).length, 1);
  },
  closer_letters_rank_higher() {
    // "ste" together in Steam beats s…t…e spread through System Settings.
    assert.deepStrictEqual(names(F.rank("ste", apps(["System Settings", "Steam"]))), ["Steam", "System Settings"]);
  },
  ties_are_broken_by_name() {
    assert.deepStrictEqual(names(F.rank("k", apps(["kew", "Kate", "kitty"]))), ["Kate", "kew", "kitty"]);
  },
  empty_query_lists_everything_by_name() {
    assert.deepStrictEqual(names(F.rank("", apps(["foot", "Discord", "btop"]))), ["btop", "Discord", "foot"]);
  },
  does_not_mutate_the_input() {
    const list = apps(["foot", "Discord"]);
    F.rank("", list);
    assert.deepStrictEqual(names(list), ["foot", "Discord"]);
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
