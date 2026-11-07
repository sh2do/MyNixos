.pragma library
// Helpers for the media pill in TopPill.qml: cava's raw output, the progress
// line, and the two lines of text. Pure functions, so tests can run them in node.

// cava's ascii_max_range; the pill's cava config uses the same value.
var CAVA_MAX = 1000;

function zeros(n) {
    var out = [];
    for (var i = 0; i < n; i++)
        out.push(0);
    return out;
}

// One frame of cava raw ascii output ("12;340;0;77;5;") as `bars` values in
// 0..1. Anything that isn't exactly `bars` numbers gives all zeros.
function parseCava(line, bars) {
    if (typeof line !== "string")
        return zeros(bars);
    var parts = line.trim().split(";");
    if (parts.length && parts[parts.length - 1] === "")
        parts.pop();
    if (parts.length !== bars)
        return zeros(bars);
    var out = [];
    for (var i = 0; i < bars; i++) {
        if (!/^\d+$/.test(parts[i]))
            return zeros(bars);
        out.push(Math.min(1, Number(parts[i]) / CAVA_MAX));
    }
    return out;
}

// How far through the track, 0..1; 0 when the length is unknown.
function progress(position, length) {
    if (!(length > 0) || !(position > 0))
        return 0;
    return Math.min(1, position / length);
}

// The pill's two lines: the title on top, "artist · album" below. Without a
// title the artist moves up; without an artist it is the title alone. With
// neither, `windowTitle` or else `identity` (the player's name) stands in, so a
// player with no metadata still shows something.
function fmtArtist(title, artist, album, windowTitle, identity) {
    title = title || "";
    artist = artist || "";
    if (!title && !artist)
        return { top: windowTitle || identity || "", bottom: "" };
    if (!title)
        return { top: artist, bottom: "" };
    if (!artist)
        return { top: title, bottom: "" };
    return { top: title, bottom: album ? artist + " · " + album : artist };
}

// Whether a cava exit means it can't run. `wanted`: the pill still wants it;
// `stopAsked`: we stopped it ourselves (a re-show can land before the exit
// signal); `runMs`: how long it ran.
function cavaFailed(wanted, stopAsked, code, runMs) {
    if (!wanted || stopAsked)
        return false;
    return code !== 0 || runMs < 1000;
}

// A gentle stand-in for the visualiser when cava can't run: each bar breathes
// at its own rate. `t` is seconds, e.g. the playback position.
function pulse(t, bars) {
    var out = [];
    for (var i = 0; i < bars; i++)
        out.push(0.4 + 0.25 * Math.sin(t * (2.1 + i * 0.7) + i * 1.3) + 0.1 * Math.sin(t * 5.3 + i));
    return out;
}

// Which player the pill shows. A playing one always wins. The last one that
// played (held) stays while it is paused and `keep` is true (the pointer is on
// the pill, or it was paused moments ago), so the pill's play button can
// resume it instead of the pill collapsing the moment you pause.
function pickPlayer(players, held, keep, playingState, pausedState) {
    for (var i = 0; i < players.length; i++)
        if (players[i].playbackState === playingState)
            return players[i];
    if (held && keep && held.playbackState === pausedState && players.indexOf(held) >= 0)
        return held;
    return null;
}
