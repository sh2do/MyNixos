.pragma library

// Focus mode, pure (tests/focus-test.js). Focus.qml reads rice-focus's
// state file with `parse`; the notification servers (Notifications.qml,
// Umbriel's Island.qml) ask `route` and keep what it holds with `hold`, and
// show `summary` once focus ends. Shared by both shells.

// The most notifications kept while focused; past it the oldest go.
var MAX_HELD = 200;
// App lines on the summary card; the rest are counted in `more`.
var MAX_LINES = 4;

// The state file: "on <epoch seconds>" or "off". Returns {on, since (ms)}.
function parse(text) {
    var m = /^on (\d+)\s*$/.exec(String(text === null || text === undefined ? "" : text).trim());
    if (!m)
        return { on: false, since: 0 };
    return { on: true, since: Number(m[1]) * 1000 };
}

// "show" or "hold": while focused only critical notifications show.
function route(on, urgency) {
    return on && urgency !== "critical" ? "hold" : "show";
}

// The held list with `entry` ({app, icon, summary, body, time}) added;
// a new array, at most MAX_HELD long.
function hold(list, entry) {
    var out = (list || []).concat([entry]);
    return out.length > MAX_HELD ? out.slice(out.length - MAX_HELD) : out;
}

// The card for the held list, or null when nothing was held:
// {count, title, groups: [{app, icon, count, latest}] newest first (at most
// MAX_LINES), more: how many apps are left off}.
function summary(list) {
    if (!list || !list.length)
        return null;
    var groups = [], byApp = {};
    for (var i = list.length - 1; i >= 0; i--) {
        var n = list[i];
        var app = n.app ? String(n.app) : "unknown";
        var g = byApp[app];
        if (!g) {
            g = byApp[app] = { app: app, icon: "", count: 0, latest: n };
            groups.push(g);
        }
        g.count++;
        if (!g.icon && n.icon)
            g.icon = String(n.icon);
    }
    return {
        count: list.length,
        title: list.length + " held while you focused",
        groups: groups.slice(0, MAX_LINES),
        more: Math.max(0, groups.length - MAX_LINES)
    };
}

// The summary as one line, for Umbriel's island: "Discord 2 · Mail 1".
function line(s) {
    if (!s)
        return "";
    var parts = s.groups.map(function (g) { return g.app + " " + g.count; });
    if (s.more > 0)
        parts.push("+" + s.more + " more");
    return parts.join(" · ");
}

// The bar chip's label: "0m", "25m", "1h 05m". `since` 0 is unknown.
function elapsed(now, since) {
    var m = since > 0 ? Math.max(0, Math.floor((now - since) / 60000)) : 0;
    if (m < 60)
        return m + "m";
    var r = m % 60;
    return Math.floor(m / 60) + "h " + (r < 10 ? "0" : "") + r + "m";
}
