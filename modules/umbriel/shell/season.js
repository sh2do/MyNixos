.pragma library

// The one season clock for both shells, pure (tests/season-test.js): which
// season a date is, what it touches, and the few sprites it drifts. Lives
// beside raven-mood.js; the niri bar copies it in (modules/shell/default.nix)
// with Season.qml, SeasonField.qml and SeasonTrinkets.qml.
//
//   spring (Mar-May)  a few petals drift down and settle (on the pond)
//   summer (Jun-Aug)  fireflies, at night only
//   October           a pumpkin and a candle in the raven's hoard
//   December          sparse snow, melting where it lands
//   otherwise         nothing
//
// Real rain or a storm (Weather.qml) keeps the sky clear, and focus mode
// pauses it all (the trinkets stay; the candle holds still).

// The shells' clock for the sprites (Hz): Umbriel's Timer runs at this,
// only while a season shows; the niri pond rides the koi's own tick.
var HZ = 15;

// How many of each, at most: sparse on purpose.
var COUNT = { petals: 5, snow: 9, fireflies: 5 };

var NAMES = ["spring", "summer", "october", "december", "none"];

function seasonOf(date) {
    var m = date.getMonth();
    if (m >= 2 && m <= 4)
        return "spring";
    if (m >= 5 && m <= 7)
        return "summer";
    if (m === 9)
        return "october";
    if (m === 11)
        return "december";
    return "none";
}

// RICE_SEASON (spring, summer, october, december or none) forces one;
// anything else is the clock.
function season(date, env) {
    return NAMES.indexOf(env) >= 0 ? env : seasonOf(date);
}

// What `name` shows now. c: {night, weather (Weather.kind), focus}.
// Returns {sprite: "petals"|"snow"|"fireflies"|"", count, trinkets, flicker}.
function touches(name, c) {
    var out = { sprite: "", count: 0, trinkets: name === "october", flicker: name === "october" && !c.focus };
    if (c.focus || c.weather === "rain" || c.weather === "storm")
        return out;
    if (name === "spring")
        out.sprite = "petals";
    else if (name === "december")
        out.sprite = "snow";
    else if (name === "summer" && c.night)
        out.sprite = "fireflies";
    out.count = out.sprite ? COUNT[out.sprite] : 0;
    return out;
}

// The sprites. A box is where they live, in the owner's coordinates:
// {x, y, w, h, k (size and sway scale), drift (px/s a settled petal
// floats), land: [lo, hi] (the band, as fractions of h, they land in)}.
// A sprite is a plain object the owner draws: x, y (its centre), rot (deg),
// opacity, scale; `splash` is true on the one step it lands (a ring on the
// pond). It waits, falls (or flies), lands, and goes round again.

function sprites(touch, box, rand) {
    var out = [];
    for (var i = 0; i < touch.count; i++)
        out.push(spawn(touch.sprite, box, rand));
    return out;
}

// A new sprite, waiting a while first so they don't all come at once.
function spawn(sprite, box, rand) {
    var first = sprite === "petals" ? 8 : sprite === "snow" ? 6 : 4;
    return {
        state: "wait", t: 0, wait: rand() * first,
        x: box.x + rand() * box.w, y: box.y + rand() * box.h, x0: 0,
        vx: 0, vy: 0, landY: 0, life: 0, phase: rand() * 6.28, sway: 1, spin: 0,
        rot: rand() * 360, opacity: 0, scale: 1, splash: false
    };
}

function clampX(x, box) {
    return Math.min(Math.max(x, box.x), box.x + box.w);
}

function begin(p, sprite, box, rand) {
    var k = box.k || 1;
    p.t = 0;
    if (sprite === "fireflies") {
        p.state = "fly";
        p.x = box.x + rand() * box.w;
        p.y = box.y + rand() * box.h;
        p.phase = rand();
        p.spin = rand() * 6.28; // its heading
        p.vx = (4 + 4 * rand()) * k; // its speed
        p.life = 3 + 3 * rand(); // its blink's period, s
        p.scale = 0.8 + 0.4 * rand();
        return;
    }
    var snow = sprite === "snow";
    p.state = "fall";
    p.x0 = box.x + rand() * box.w;
    p.x = p.x0;
    p.y = box.y - 4 * k;
    var lo = box.land[0], hi = box.land[1];
    p.landY = box.y + box.h * (lo + (hi - lo) * rand());
    // Seconds to land, whatever the box's height.
    p.vy = (p.landY - p.y) / (snow ? 4 + 3 * rand() : 5 + 3 * rand());
    p.vx = (rand() - 0.5) * 3 * k;
    p.sway = (snow ? 2.5 : 4) * k;
    p.spin = snow ? 0 : (rand() - 0.5) * 80;
    p.scale = snow ? 0.7 + 0.5 * rand() : 0.85 + 0.3 * rand();
}

function step(p, sprite, dt, box, rand) {
    dt = Math.min(Math.max(dt, 0), 2 / HZ);
    p.splash = false;
    p.t += dt;
    switch (p.state) {
    case "wait":
        p.opacity = 0;
        if (p.t >= p.wait)
            begin(p, sprite, box, rand);
        return p;
    case "fall":
        p.phase += dt * (sprite === "snow" ? 1.1 : 1.5);
        p.x0 = clampX(p.x0 + p.vx * dt, box);
        p.x = p.x0 + p.sway * Math.sin(p.phase);
        p.y = Math.min(p.y + p.vy * dt, p.landY);
        p.rot += p.spin * dt;
        p.opacity = Math.min(1, p.t / 0.6) * (sprite === "snow" ? 0.9 : 0.85);
        if (p.y >= p.landY) {
            p.splash = true;
            p.t = 0;
            p.state = sprite === "snow" ? "melt" : "float";
            p.life = 6 + 6 * rand();
            p.vx = (rand() < 0.5 ? -1 : 1) * (box.drift || 0);
        }
        return p;
    case "float":
        // Settled on the water: it drifts with it, turning a little, and fades.
        p.x = clampX(p.x + p.vx * dt, box);
        p.rot += 6 * dt;
        p.opacity = 0.85 * Math.min(1, Math.max(0, (p.life - p.t) / 2));
        if (p.t >= p.life)
            rest(p, 3 + 6 * rand());
        return p;
    case "melt":
        var u = Math.min(1, p.t / 0.7);
        p.opacity = 0.9 * (1 - u);
        p.scale *= 1 - 0.5 * dt;
        if (u >= 1)
            rest(p, 0.5 + 3.5 * rand());
        return p;
    case "fly":
        // A slow wander, turning a little at random, bouncing off the edges;
        // it glows for a third of each blink and is dark the rest.
        p.spin += (rand() - 0.5) * 3 * dt;
        var nx = p.x + Math.cos(p.spin) * p.vx * dt;
        var ny = p.y + Math.sin(p.spin) * p.vx * 0.6 * dt;
        if (nx < box.x || nx > box.x + box.w)
            p.spin = Math.PI - p.spin;
        if (ny < box.y || ny > box.y + box.h)
            p.spin = -p.spin;
        p.x = Math.min(Math.max(nx, box.x), box.x + box.w);
        p.y = Math.min(Math.max(ny, box.y), box.y + box.h);
        p.phase = (p.phase + dt / p.life) % 1;
        var g = p.phase < 0.35 ? Math.sin(p.phase / 0.35 * Math.PI) : 0;
        p.opacity = g * g;
        return p;
    }
    return p;
}

function rest(p, secs) {
    p.state = "wait";
    p.t = 0;
    p.wait = secs;
    p.opacity = 0;
}
