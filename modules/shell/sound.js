.pragma library

// When a sound plays, pure (tests/sound-test.js). Sound.qml asks; nothing
// here touches audio. The kinds: "notify" (a water drop), "critical" (a low
// caw), "tick" (a ripple tick for volume steps, at most one per 150 ms).

var TICK_GAP = 150;
var NAMES = { notify: "drop", critical: "caw", tick: "tick" };

function soundFor(kind) {
    return NAMES[kind] || "";
}

// s: { env: RICE_SOUNDS, night, muted (default sink), kind, now (ms),
// lastTick (ms of the last tick played) }.
function shouldPlay(s) {
    if (s.env === "0" || s.night || s.muted)
        return false;
    if (!NAMES[s.kind])
        return false;
    if (s.kind === "tick" && s.now - s.lastTick < TICK_GAP)
        return false;
    return true;
}
