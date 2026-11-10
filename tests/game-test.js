// Tests for modules/shell/game.js (run: nix run nixpkgs#nodejs -- tests/game-test.js).
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/game.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const G = {};
vm.createContext(G);
vm.runInContext(src, G);

const plain = o => JSON.parse(JSON.stringify(o));

const tests = {
  // What Game.qml's probe prints: busctl's own text, one value a line.
  test_parse_a_running_game() {
    assert.deepStrictEqual(plain(G.parse("owner b true\nclients i 1\n")), { up: true, clients: 1 });
  },
  test_parse_two_games() {
    assert.deepStrictEqual(plain(G.parse("owner b true\nclients i 2")), { up: true, clients: 2 });
  },
  test_parse_daemon_up_but_idle() {
    assert.deepStrictEqual(plain(G.parse("owner b true\nclients i 0\n")), { up: true, clients: 0 });
  },
  test_parse_no_daemon() {
    // Not on the bus: the probe stops before asking for the count.
    assert.deepStrictEqual(plain(G.parse("owner b false\n")), { up: false, clients: 0 });
  },
  test_parse_empty_and_junk() {
    for (const t of ["", null, undefined, "clients i lots", "owner b maybe\nclients i -3", "garbage"])
      assert.deepStrictEqual(plain(G.parse(t)), { up: false, clients: 0 }, JSON.stringify(t));
  },
  test_parse_count_without_owner_is_not_trusted() {
    assert.strictEqual(G.parse("clients i 1").clients, 0);
  },

  test_label() {
    assert.strictEqual(G.label(0), "");
    assert.strictEqual(G.label(1), "game");
    assert.strictEqual(G.label(3), "3 games");
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
