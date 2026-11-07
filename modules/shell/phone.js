.pragma library
// The phone link (KDE Connect) for Phone.qml: parsing what its probe prints,
// choosing the phone to show, and the gate for forwarding notifications.
// Pure functions, so tests can run them in node.

// The probe prints, for the daemon's paired devices, busctl's own text output:
//   devices as 1 "a1b2_c3"
//   id a1b2_c3
//   name s "Pixel 8"
//   reachable b true
//   charge i 87          (empty when the battery plugin is off or unreachable)
//   charging b false
// Returns [{id, name, reachable, charge, charging}]; charge is -1 when unknown.
// Lines it doesn't understand are ignored, and so is a device whose id isn't a
// D-Bus path element (it would not be one KDE Connect made).
function parse(text) {
    var out = [];
    var dev = null;
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var m = /^(\w+) ?(.*)$/.exec(lines[i]);
        if (!m)
            continue;
        var key = m[1], rest = m[2];
        if (key === "id") {
            dev = null;
            if (/^[A-Za-z0-9_]+$/.test(rest)) {
                dev = { id: rest, name: rest, reachable: false, charge: -1, charging: false };
                out.push(dev);
            }
            continue;
        }
        if (!dev)
            continue;
        if (key === "name") {
            var s = /^s "((?:[^"\\]|\\.)*)"$/.exec(rest);
            if (s && s[1].length)
                dev.name = s[1].replace(/\\(.)/g, "$1");
        } else if (key === "reachable" || key === "charging") {
            var b = /^b (true|false)$/.exec(rest);
            if (b)
                dev[key] = b[1] === "true";
        } else if (key === "charge") {
            var n = /^i (-?\d+)$/.exec(rest);
            if (n) {
                var v = parseInt(n[1], 10);
                dev.charge = v >= 0 && v <= 100 ? v : -1;
            }
        }
    }
    return out;
}

// The phone to show: the first reachable one, else the first paired one.
function pick(list) {
    if (!list || !list.length)
        return null;
    for (var i = 0; i < list.length; i++)
        if (list[i].reachable)
            return list[i];
    return list[0];
}

// The battery shown next to the phone: "87%", "40%+" while charging, or ""
// when unknown or the phone is away (its last charge would be stale).
function label(phone) {
    if (!phone || !phone.reachable || !(phone.charge >= 0))
        return "";
    return phone.charge + "%" + (phone.charging ? "+" : "");
}

// RICE_PHONE_FORWARD: "critical" (the default, also when unset or empty)
// sends critical notifications to the phone; "off", or anything else, sends
// none. Notifications that came from the phone (KDE Connect's own) never go
// back to it.
function shouldForward(mode, app, desktopEntry, urgency) {
    var m = String(mode || "critical").toLowerCase();
    if (m !== "critical" || urgency !== "critical")
        return false;
    if (/kde ?connect/i.test(String(app || "")) || /kdeconnect/i.test(String(desktopEntry || "")))
        return false;
    return true;
}

// A notification as one short line for the phone: "summary: body", markup
// stripped, at most 300 characters.
function alertText(summary, body) {
    function plain(t) {
        return String(t || "").replace(/<[^>]*>/g, "")
            .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
            .replace(/&#39;|&apos;/g, "'").replace(/&amp;/g, "&")
            .replace(/\s+/g, " ").trim();
    }
    var parts = [plain(summary), plain(body)].filter(function (p) { return p.length > 0; });
    var t = parts.join(": ");
    return t.length > 300 ? t.slice(0, 299) + "…" : t;
}
