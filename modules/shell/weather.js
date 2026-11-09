.pragma library

// The real weather in both shells' scenes, pure (tests/weather-test.js).
// rice-weather (modules/weather) writes the file every 20 min; Weather.qml
// reads it once a minute and eases between the scenes below. Shared with
// Umbriel (modules/umbriel copies it in).

var KINDS = ["clear", "cloudy", "fog", "drizzle", "rain", "storm", "snow"];

// Older than this (s) and the file is no weather at all: the shells go back
// to their own scenes until rice-weather reaches the network again.
var STALE = 3 * 3600;

// RICE_WEATHER=<kind> forces a kind, at these strengths, file or no file.
var FORCED = {
    clear: { intensity: 0, wind: 0.1 },
    cloudy: { intensity: 0.7, wind: 0.2 },
    fog: { intensity: 0.7, wind: 0.05 },
    drizzle: { intensity: 0.4, wind: 0.2 },
    rain: { intensity: 0.6, wind: 0.3 },
    storm: { intensity: 1, wind: 0.8 },
    snow: { intensity: 0.6, wind: 0.2 }
};

function clamp01(v) {
    return Math.min(Math.max(+v || 0, 0), 1);
}

// The file's text (rice-weather's JSON) at `now` (epoch s), and the
// RICE_WEATHER override: {kind, intensity, wind, isDay, updated}, or null
// for no weather (missing, garbled, stale, or an unknown kind).
function parse(text, now, env) {
    if (FORCED[env])
        return { kind: env, intensity: FORCED[env].intensity, wind: FORCED[env].wind, isDay: true, updated: now, forced: true };
    var w;
    try {
        w = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!w || KINDS.indexOf(w.kind) < 0 || typeof w.updated !== "number" || now - w.updated > STALE)
        return null;
    return { kind: w.kind, intensity: clamp01(w.intensity), wind: clamp01(w.wind), isDay: w.isDay !== false, updated: w.updated };
}

// What the scenes draw, as numbers so they can ease:
//   rain    Umbriel's hydrangea rain streaks, 1 = its usual rain, 0 = none
//   slant   extra lean on the streaks (the wind)
//   fall    how fast they fall, 1 = usual
//   mist    the misty light's breathing, 1 = usual
//   skyRain streaks over Umbriel's stormy ruins (0 = none, as before)
//   flash   lightning over the ruins, a rate multiplier (1 = usual)
//   drops   raindrops on niri's koi pond, per second (0 = its own dimples)
//   fog     a soft fog tint over the pond, 0..1
// No weather is exactly the scenes as they were before.
function scene(w) {
    var s = { rain: 1, slant: 0, fall: 1, mist: 1, fog: 0, drops: 0, flash: 1, skyRain: 0 };
    if (!w)
        return s;
    var i = clamp01(w.intensity), wind = clamp01(w.wind);
    switch (w.kind) {
    case "clear":
    case "cloudy":
        // Mist only; the pond is as it always is.
        s.rain = 0;
        s.flash = w.kind === "clear" ? 0.35 : 0.5;
        break;
    case "fog":
        s.rain = 0;
        s.mist = 1.2 + 0.8 * i;
        s.fog = 0.25 + 0.6 * i;
        s.flash = 0.35;
        break;
    case "drizzle":
        s.rain = 0.25 + 0.35 * i;
        s.slant = 0.05 * wind;
        s.fall = 0.8;
        s.drops = 0.6 + 1.4 * i;
        s.flash = 0.6;
        s.skyRain = 0.25 + 0.3 * i;
        break;
    case "rain":
        s.rain = 0.65 + 0.6 * i;
        s.slant = 0.12 * wind;
        s.drops = 2 + 6 * i;
        s.skyRain = 0.6 + 0.5 * i;
        break;
    case "storm":
        s.rain = 1.4 + 0.6 * i;
        s.slant = 0.15 + 0.35 * wind;
        s.fall = 1.25;
        s.drops = 7 + 7 * i;
        s.flash = 1.6 + 0.8 * i;
        s.skyRain = 1.2 + 0.6 * i;
        break;
    case "snow":
        // Slow flakes rather than streaks; they land softly on the pond.
        s.rain = 0.4 + 0.5 * i;
        s.slant = 0.1 * wind;
        s.fall = 0.2;
        s.mist = 1.1;
        s.drops = 0.4 + 1.2 * i;
        s.flash = 0.3;
        s.skyRain = 0.4 + 0.5 * i;
        break;
    }
    return s;
}

// One step of `dt` ms from scene `cur` toward `target`: about EASE ms end to
// end, gentle at the finish. A stalled timer counts as one second at most.
var EASE = 10000;
var TAU = 2000;
function ease(cur, target, dt) {
    var k = 1 - Math.exp(-Math.min(Math.max(dt, 0), 1000) / TAU);
    var out = {};
    for (var key in target)
        out[key] = cur[key] + (target[key] - cur[key]) * k;
    return settled(out, target) ? copy(target) : out;
}

// Close enough to stop easing (and land exactly).
function settled(a, b) {
    for (var key in b)
        if (Math.abs(a[key] - b[key]) > 0.01 * Math.max(1, Math.abs(b[key])))
            return false;
    return true;
}

function copy(s) {
    var out = {};
    for (var key in s)
        out[key] = s[key];
    return out;
}

// Ms until the next raindrop on the pond at `drops` a second, jittered by
// rand() in [0, 1); null when it isn't raining (the pond's own dimples).
function dropGap(drops, rand) {
    if (!(drops >= 0.05))
        return null;
    return 1000 / drops * (0.5 + rand());
}
