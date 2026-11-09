// Tests for modules/shell/clip.js (run: nix run nixpkgs#nodejs -- tests/clip-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/clip.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const C = {};
vm.createContext(C);
vm.runInContext(src, C);

// What `cliphist list` prints: newest first, "id<TAB>preview".
const LIST = [
  "72\t[[ binary data 321 KiB png 422x429 ]]",
  "71\tgit commit -m \"rice: pond glass\"",
  "70\thttps://example.org/a?b=c\td",
  "69\t[[ binary data 12 KiB jpeg 64x32 ]]",
  "",
  "garbage without a tab",
  "68\tHello World",
].join("\n");

const tests = {
  parses_ids_text_and_the_raw_line() {
    const e = C.parse(LIST);
    assert.deepStrictEqual(Array.from(e, x => x.id), ["72", "71", "70", "69", "68"]);
    assert.strictEqual(e[1].text, "git commit -m \"rice: pond glass\"");
    assert.strictEqual(e[1].line, "71\tgit commit -m \"rice: pond glass\"");
    assert.strictEqual(e[1].image, null);
  },
  keeps_tabs_inside_the_preview() {
    assert.strictEqual(C.parse(LIST)[2].text, "https://example.org/a?b=c\td");
  },
  reads_image_entries() {
    const e = C.parse(LIST);
    assert.strictEqual(e[0].image.ext, "png");
    assert.strictEqual(e[0].image.width, 422);
    assert.strictEqual(e[0].image.height, 429);
    assert.strictEqual(e[0].image.size, "321 KiB");
    assert.strictEqual(e[3].image.ext, "jpg");
  },
  skips_blank_and_malformed_lines() {
    assert.strictEqual(C.parse("").length, 0);
    assert.strictEqual(C.parse("\n\nnope\n").length, 0);
    assert.strictEqual(C.parse("abc\tnot a number id").length, 0);
  },
  thumb_paths_only_for_images() {
    const e = C.parse(LIST);
    assert.strictEqual(C.thumbPath("/run/x", e[0]), "/run/x/72.png");
    assert.strictEqual(C.thumbPath("/run/x", e[1]), "");
  },
  empty_query_keeps_everything_in_order() {
    const e = C.parse(LIST);
    assert.deepStrictEqual(Array.from(C.filter(e, "  "), x => x.id), ["72", "71", "70", "69", "68"]);
  },
  every_word_must_match_case_insensitively() {
    const e = C.parse(LIST);
    assert.deepStrictEqual(Array.from(C.filter(e, "POND rice"), x => x.id), ["71"]);
    assert.deepStrictEqual(Array.from(C.filter(e, "pond hello"), x => x.id), []);
  },
  images_match_image_and_their_format() {
    const e = C.parse(LIST);
    assert.deepStrictEqual(Array.from(C.filter(e, "image"), x => x.id), ["72", "69"]);
    assert.deepStrictEqual(Array.from(C.filter(e, "jpg"), x => x.id), ["69"]);
  },
  labels_images_readably() {
    const e = C.parse(LIST);
    assert.strictEqual(C.label(e[0]), "png image · 422×429 · 321 KiB");
    assert.strictEqual(C.label(e[4]), "Hello World");
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
