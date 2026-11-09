.pragma library

// When a sound plays, pure (tests/sound-test.js). Sound.qml asks; nothing
// here touches audio. The kinds: "notify" (a water drop), "critical" (a low
// caw, never held back), "tick" (a ripple tick for volume steps, at most one
// per 150 ms). A burst of notifications gives one drop, not one each.

var TICK_GAP = 150;
var DROP_GAP = 1500;
var NAMES = { notify: "drop", critical: "caw", tick: "tick" };

function soundFor(kind) {
    return NAMES[kind] || "";
}

// s: { env: RICE_SOUNDS, night, muted (default sink), kind, now (ms),
// lastTick, lastDrop (ms of the last tick / drop played) }.
function shouldPlay(s) {
    if (s.env === "0" || s.night || s.muted)
        return false;
    if (!NAMES[s.kind])
        return false;
    if (s.kind === "tick" && s.now - s.lastTick < TICK_GAP)
        return false;
    if (s.kind === "notify" && s.now - s.lastDrop < DROP_GAP)
        return false;
    return true;
}
