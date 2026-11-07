.pragma library
// Beats in the bass, for the koi: a level jumping clear of its own recent
// running average is a beat, at most one per REFRACTORY ms, and only once
// per rise (the level has to fall back before the next one counts). Pure, so
// tests can run it in node.

// How far above the running average a beat must reach, and how loud at least.
var MARGIN = 0.15;
var FLOOR = 0.12;
// The running average follows over about this many ms.
var TAU = 900;
// At most 2 beats a second.
var REFRACTORY = 500;

function num(v, d) {
    return typeof v === "number" && isFinite(v) ? v : d;
}

// One step with the bass level (0..1) at time t (ms): {state, beat}. State may
// be null to start; a bad level leaves the state as it was, with no beat.
function beatStep(state, bass, t) {
    var s = state && typeof state === "object" ? state : {};
    var avg = num(s.avg, NaN), last = num(s.last, -1e12), at = num(s.t, NaN);
    var high = s.high === true;
    t = num(t, isFinite(at) ? at : 0);
    var ok = typeof bass === "number" && isFinite(bass);
    if (!ok)
        return { state: { avg: isFinite(avg) ? avg : 0, last: last, t: isFinite(at) ? at : t, high: high }, beat: false };
    bass = Math.max(0, Math.min(1, bass));
    if (!isFinite(avg))
        return { state: { avg: bass, last: last, t: t, high: false }, beat: false };
    var dt = isFinite(at) ? Math.max(0, t - at) : 0;
    var over = bass > avg + MARGIN && bass > FLOOR;
    var beat = over && !high && t - last >= REFRACTORY;
    // Re-armed once it falls back toward the average.
    var nowHigh = over || (high && bass > avg + MARGIN / 2);
    return {
        state: {
            avg: avg + (bass - avg) * Math.min(1, dt / TAU),
            last: beat ? t : last,
            t: t,
            high: nowHigh
        },
        beat: beat
    };
}

// The raven's gate: may it bob its head to a beat now? Only when it is awake
// and free (not asleep, hopping, in a long action such as a caw, ruffle or
// preen, watching the pointer, or already moving its head), and at most 2 a
// second (sinceBob: ms since its last bob). Anything else is a no.
var BOB_GAP = 500;

function bobAllowed(s) {
    if (!s || typeof s !== "object")
        return false;
    if (s.asleep || s.busy || s.hop || s.watching || s.headBusy)
        return false;
    return typeof s.sinceBob === "number" && s.sinceBob >= BOB_GAP;
}
