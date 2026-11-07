.pragma library
// Groups notifications into one card per app for Notifications.qml. Pure
// functions, so tests can run them in node.

// Shown when no notification in a group names an icon (a bell glyph).
var GENERIC_ICON = "󰂚";
var MAX_GROUPS = 4;
var MAX_STACK = 2;

// list: [{id, app, icon, summary, body, time, urgency, actions}], in the
// server's order (oldest first). Returns at most MAX_GROUPS groups, newest
// first: {app, icon, count, latest, stack, critical}. `stack` holds up to
// MAX_STACK older notifications, newest first; `critical` is true when any
// notification in the group is critical.
function group(list) {
    if (!list || !list.length)
        return [];
    // Newest first; of equal stamps the later one in the list is newer.
    var sorted = list.map(function (n, i) { return { n: n, i: i }; });
    sorted.sort(function (a, b) { return (b.n.time - a.n.time) || (b.i - a.i); });

    var groups = [];
    var byApp = {};
    for (var k = 0; k < sorted.length; k++) {
        var n = sorted[k].n;
        var app = n.app ? String(n.app) : "unknown";
        var g = byApp[app];
        if (!g) {
            g = byApp[app] = { app: app, icon: "", count: 0, latest: n, stack: [], critical: false };
            groups.push(g);
        } else if (g.stack.length < MAX_STACK) {
            g.stack.push(n);
        }
        g.count++;
        if (!g.icon && n.icon)
            g.icon = String(n.icon);
        if (n.urgency === "critical")
            g.critical = true;
    }
    for (var j = 0; j < groups.length; j++)
        if (!groups[j].icon)
            groups[j].icon = GENERIC_ICON;
    return groups.slice(0, MAX_GROUPS);
}

// A short age label: "now" under a minute, then "2m", "1h", "3d".
function age(now, time) {
    var s = Math.floor((now - time) / 1000);
    if (!(s >= 60))
        return "now";
    var m = Math.floor(s / 60);
    if (m < 60)
        return m + "m";
    var h = Math.floor(m / 60);
    if (h < 24)
        return h + "h";
    return Math.floor(h / 24) + "d";
}
