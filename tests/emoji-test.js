// Tests for modules/shell/emoji.js (run: nix run nixpkgs#nodejs -- tests/emoji-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
// The data is Unicode's emoji-test.txt (nixpkgs unicode-emoji); a slice of it is inlined here.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/emoji.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const E = {};
vm.createContext(E);
vm.runInContext(src, E);

const DATA = `# emoji-test.txt
# group: Smileys & Emotion

# subgroup: face-smiling
1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face
1F604                                                  ; fully-qualified     # 😄 E0.6 grinning face with smiling eyes
263A FE0F                                              ; fully-qualified     # ☺️ E0.6 smiling face
263A                                                   ; unqualified         # ☺ E0.6 smiling face

# group: People & Body

# subgroup: hand-fingers-open
1F44B                                                  ; fully-qualified     # 👋 E0.6 waving hand
1F44B 1F3FB                                            ; fully-qualified     # 👋🏻 E1.0 waving hand: light skin tone

# group: Component

# subgroup: skin-tone
1F3FB                                                  ; component           # 🏻 E1.0 light skin tone

# group: Animals & Nature

# subgroup: animal-marine
1F41F                                                  ; fully-qualified     # 🐟 E0.6 fish
1F420                                                  ; fully-qualified     # 🐠 E0.6 tropical fish

# group: Symbols

# subgroup: keycap
0023 FE0F 20E3                                         ; fully-qualified     # #️⃣ E0.6 keycap: #

# group: Flags

# subgroup: country-flag
1F1FA 1F1F8                                            ; fully-qualified     # 🇺🇸 E0.6 flag: United States
`;

const chars = list => Array.from(list, e => e.char);

const tests = {
  parses_fully_qualified_emoji_with_names_and_groups() {
    const l = E.parse(DATA);
    assert.strictEqual(l[0].char, "😀");
    assert.strictEqual(l[0].name, "grinning face");
    assert.strictEqual(l[0].group, "Smileys & Emotion");
    assert.strictEqual(l[0].sub, "face-smiling");
  },
  drops_unqualified_components_and_skin_tones() {
    assert.deepStrictEqual(chars(E.parse(DATA)), ["😀", "😄", "☺️", "👋", "🐟", "🐠", "#️⃣", "🇺🇸"]);
  },
  keeps_multi_codepoint_sequences_intact() {
    const l = E.parse(DATA);
    assert.strictEqual(l.find(e => e.name === "flag: United States").char, "\u{1F1FA}\u{1F1F8}");
    assert.strictEqual(l.find(e => e.name === "keycap: #").char, "#️⃣");
  },
  empty_query_lists_everything() {
    assert.strictEqual(E.search(E.parse(DATA), " ").length, 8);
  },
  exact_name_first_then_word_starts() {
    // "fish": fish itself, then tropical fish.
    assert.deepStrictEqual(chars(E.search(E.parse(DATA), "fish")), ["🐟", "🐠"]);
    // "smil": smiling face (name starts with it), then grinning face with smiling eyes,
    // then grinning face, which only its subgroup (face-smiling) matches.
    assert.deepStrictEqual(chars(E.search(E.parse(DATA), "smil")), ["☺️", "😄", "😀"]);
  },
  every_word_must_match() {
    assert.deepStrictEqual(chars(E.search(E.parse(DATA), "grin eyes")), ["😄"]);
    assert.deepStrictEqual(chars(E.search(E.parse(DATA), "Grin fish")), []);
  },
  subgroups_and_groups_match_too() {
    // "marine" is only in the subgroup; "flag" in the name and the group.
    assert.deepStrictEqual(chars(E.search(E.parse(DATA), "marine")), ["🐟", "🐠"]);
    assert.deepStrictEqual(chars(E.search(E.parse(DATA), "united")), ["🇺🇸"]);
  },
  lists_groups_in_order_with_their_first_index() {
    const g = E.groups(E.parse(DATA));
    assert.deepStrictEqual(Array.from(g, x => x.name), ["Smileys & Emotion", "People & Body", "Animals & Nature", "Symbols", "Flags"]);
    assert.deepStrictEqual(Array.from(g, x => x.index), [0, 3, 4, 6, 7]);
    assert.strictEqual(g[0].icon, "😀");
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
