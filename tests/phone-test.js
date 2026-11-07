// Tests for modules/shell/phone.js (run: nix run nixpkgs#nodejs -- tests/phone-test.js).
// The library is a QML `.pragma library` file; strip that line and run it in a vm context.
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const src = fs.readFileSync(path.join(__dirname, "../modules/shell/phone.js"), "utf8")
  .replace(/^\.pragma library.*$/m, "");
const P = {};
vm.createContext(P);
vm.runInContext(src, P);

// What Phone.qml's probe prints: busctl's own text output, one property a line.
const pixel = [
  'devices as 2 "a1b2c3d4_e5f6" "0099_ff"',
  "id a1b2c3d4_e5f6",
  'name s "Pixel 8"',
  "reachable b true",
  "charge i 87",
  "charging b false",
  "id 0099_ff",
  'name s "Old \\"tab\\""',
  "reachable b false",
  "charge i -1",
  "charging b false",
].join("\n");

const plain = o => JSON.parse(JSON.stringify(o));

const tests = {
  test_parses_paired_devices() {
    const out = plain(P.parse(pixel));
    assert.deepStrictEqual(out, [
      { id: "a1b2c3d4_e5f6", name: "Pixel 8", reachable: true, charge: 87, charging: false },
      { id: "0099_ff", name: 'Old "tab"', reachable: false, charge: -1, charging: false },
    ]);
  },

  test_no_device_paired() {
    assert.strictEqual(P.parse("devices as 0\n").length, 0);
    assert.strictEqual(P.pick(P.parse("devices as 0\n")), null);
  },

  test_no_daemon_prints_nothing() {
    assert.strictEqual(P.parse("").length, 0);
    assert.strictEqual(P.parse(null).length, 0);
    assert.strictEqual(P.parse(undefined).length, 0);
  },

  test_paired_but_unreachable() {
    // An unreachable phone's battery plugin is unloaded, so busctl fails and
    // the charge lines come back empty.
    const out = P.parse(["devices as 1 \"abc\"", "id abc", 'name s "Pixel"', "reachable b false", "charge ", "charging "].join("\n"));
    assert.strictEqual(out.length, 1);
    assert.strictEqual(out[0].reachable, false);
    assert.strictEqual(out[0].charge, -1);
    assert.strictEqual(out[0].charging, false);
    const p = P.pick(out);
    assert.strictEqual(p.id, "abc");
    assert.strictEqual(P.label(p), "");
  },

  test_missing_name_falls_back_to_id() {
    const out = P.parse("id abc\nname \nreachable b true\n");
    assert.strictEqual(out[0].name, "abc");
    assert.strictEqual(out[0].charge, -1);
  },

  test_garbage_is_ignored() {
    const junk = [
      "Call failed: The name org.kde.kdeconnect was not provided by any .service files",
      "id ../../etc", // not a D-Bus path element: dropped, with its properties
      'name s "evil"',
      "reachable b true",
      "\u0000ÿ random",
      "charge i lots",
      "id ok_1",
      "reachable b maybe",
      "charge i 250",
      "charging q 1",
    ].join("\n");
    const out = plain(P.parse(junk));
    assert.deepStrictEqual(out, [{ id: "ok_1", name: "ok_1", reachable: false, charge: -1, charging: false }]);
  },

  test_charge_range() {
    assert.strictEqual(P.parse("id a\ncharge i 0")[0].charge, 0);
    assert.strictEqual(P.parse("id a\ncharge i 100")[0].charge, 100);
    assert.strictEqual(P.parse("id a\ncharge i 101")[0].charge, -1);
  },

  test_pick_prefers_reachable() {
    const list = P.parse(pixel);
    assert.strictEqual(P.pick(list).id, "a1b2c3d4_e5f6");
    const flipped = [list[1], list[0]];
    assert.strictEqual(P.pick(flipped).id, "a1b2c3d4_e5f6", "the reachable one even when listed second");
    assert.strictEqual(P.pick([list[1]]).id, "0099_ff", "else the first paired one");
  },

  test_label() {
    assert.strictEqual(P.label({ reachable: true, charge: 87, charging: false }), "87%");
    assert.strictEqual(P.label({ reachable: true, charge: 40, charging: true }), "40%+");
    assert.strictEqual(P.label({ reachable: true, charge: -1, charging: false }), "");
    assert.strictEqual(P.label({ reachable: false, charge: 87, charging: false }), "", "no stale battery when away");
    assert.strictEqual(P.label(null), "");
  },

  test_forward_gate_default_is_critical() {
    assert.strictEqual(P.shouldForward(undefined, "power", "", "critical"), true);
    assert.strictEqual(P.shouldForward("", "power", "", "critical"), true);
    assert.strictEqual(P.shouldForward("critical", "power", "", "critical"), true);
    assert.strictEqual(P.shouldForward("critical", "power", "", "normal"), false, "ordinary ones stay on the desktop");
    assert.strictEqual(P.shouldForward("critical", "power", "", "low"), false);
  },

  test_forward_gate_off() {
    assert.strictEqual(P.shouldForward("off", "power", "", "critical"), false);
    assert.strictEqual(P.shouldForward("OFF", "power", "", "critical"), false);
    assert.strictEqual(P.shouldForward("bogus", "power", "", "critical"), false, "an unknown mode forwards nothing");
  },

  test_forward_gate_never_loops_phone_notifications() {
    for (const app of ["KDE Connect", "kdeconnect", "kdeconnectd", "KDEConnect"])
      assert.strictEqual(P.shouldForward("critical", app, "", "critical"), false, app);
    assert.strictEqual(P.shouldForward("critical", "Signal", "org.kde.kdeconnect.daemon", "critical"), false, "by desktop entry");
    assert.strictEqual(P.shouldForward("critical", "Signal", "org.signal.Signal", "critical"), true);
  },

  test_alert_text() {
    assert.strictEqual(P.alertText("Battery low", "5% left"), "Battery low: 5% left");
    assert.strictEqual(P.alertText("Battery low", ""), "Battery low");
    assert.strictEqual(P.alertText("", "only body"), "only body");
    assert.strictEqual(P.alertText("a <b>bold</b>", "x&amp;y"), "a bold: x&y", "markup stripped");
    assert.strictEqual(P.alertText("", ""), "");
    assert.ok(P.alertText("s", "x".repeat(1000)).length <= 300, "kept short");
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
