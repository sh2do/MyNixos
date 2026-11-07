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
// title the artist moves up; without an artist it is the title alone.
function fmtArtist(title, artist, album) {
    title = title || "";
    artist = artist || "";
    if (!title)
        return { top: artist, bottom: "" };
    if (!artist)
        return { top: title, bottom: "" };
    return { top: title, bottom: album ? artist + " · " + album : artist };
}

// A gentle stand-in for the visualiser when cava can't run: each bar breathes
// at its own rate. `t` is seconds, e.g. the playback position.
function pulse(t, bars) {
    var out = [];
    for (var i = 0; i < bars; i++)
        out.push(0.4 + 0.25 * Math.sin(t * (2.1 + i * 0.7) + i * 1.3) + 0.1 * Math.sin(t * 5.3 + i));
    return out;
}
