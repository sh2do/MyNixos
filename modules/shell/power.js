.pragma library

// The power profile glyph and click-to-cycle order, and fan boost's state
// from `rice-fan status`; pure (tests/power-test.js). Used by the niri bar's
// toggles and Umbriel's status corner (Fan.qml, copied into both shells).
// Profiles are power-profiles-daemon's names: power-saver, balanced, performance.

function glyph(name) {
    if (name === "power-saver")
        return "󰾆";
    if (name === "performance")
        return "󰓅";
    return "󰾅";
}

// The profile after `name`: saver, balanced, performance (if the machine has
// it), then round again. Anything unknown starts at saver.
function next(name, hasPerformance) {
    const order = ["power-saver", "balanced"];
    if (hasPerformance)
        order.push("performance");
    const i = order.indexOf(name);
    return i < 0 ? order[0] : order[(i + 1) % order.length];
}

// "max", "auto" or "manual"; "" when the fans can't be driven.
function fanMode(text) {
    const m = /^fan (max|auto|manual)\b/.exec(text || "");
    return m ? m[1] : "";
}
