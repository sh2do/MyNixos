.pragma library
// What the lock screen's extras (LockExtras.qml) show, pure so tests can run
// it in node (tests/lock-extras-test.js). Media, phone and weather logic is
// shared with the shell (media.js, phone.js, weather.js).

var GLYPHS = {
    clear: "󰖙", cloudy: "󰖐", fog: "󰖑", drizzle: "󰖗",
    rain: "󰖖", storm: "󰖓", snow: "󰖘"
};

// The weather's glyph; "" when there is no weather (or an unknown kind).
function weatherGlyph(kind, isDay) {
    if (!GLYPHS.hasOwnProperty(kind))
        return "";
    if (kind === "clear" && isDay === false)
        return "󰖔";
    return GLYPHS[kind];
}

function weatherWord(kind) {
    return GLYPHS.hasOwnProperty(kind) ? kind : "";
}

function hasMedia(player) {
    return !!player;
}

// The card's two lines: title over artist; the artist moves up without a
// title; the player's name stands in with neither.
function cardLines(title, artist, album, identity) {
    if (!title && !artist)
        return { top: identity || "", bottom: "" };
    if (!title)
        return { top: artist, bottom: "" };
    return { top: title, bottom: artist || "" };
}

// The phone chip: a paired phone that is reachable (its battery is known).
function showPhone(paired, battery) {
    return !!paired && String(battery || "").length > 0;
}
