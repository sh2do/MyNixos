.pragma library

// Fuzzy ranking for the launcher (tests/fuzzy-test.js).
//
// rank(query, entries) -> the entries whose name contains the query's letters
// in order (any case), best first. Each letter scores; a letter right after
// the last one, at a word start, or at the very start scores more, and each
// letter skipped between two matched ones costs a little. A tie goes to the
// name that sorts first. An empty query keeps everything, by name.
// Plain loops only: Qt's JS engine lacks some newer array methods.

function isWordStart(name, i) {
    if (i === 0)
        return true;
    var prev = name.charAt(i - 1), c = name.charAt(i);
    if (!/[A-Za-z0-9]/.test(prev))
        return true;
    // camelCase: "qBittorrent", "OBS StudioPro"
    return prev === prev.toLowerCase() && c !== c.toLowerCase();
}

// The query matched from `start` on, each later letter taking the nearest
// place after the last; null if it doesn't fit.
function scoreFrom(name, lower, q, start) {
    var score = 0, last = -1;
    for (var k = 0, i = start; k < q.length; k++, i++) {
        i = lower.indexOf(q.charAt(k), i);
        if (i < 0)
            return null;
        score += 1;
        if (k > 0)
            score += i === last + 1 ? 6 : -(i - last - 1);
        if (isWordStart(name, i))
            score += 6;
        if (i === 0)
            score += 10;
        last = i;
    }
    return score;
}

// The best of every place the first letter could go; null if none fits.
function score(name, q) {
    var lower = name.toLowerCase(), best = null;
    for (var i = lower.indexOf(q.charAt(0)); i >= 0; i = lower.indexOf(q.charAt(0), i + 1)) {
        var s = scoreFrom(name, lower, q, i);
        if (s !== null && (best === null || s > best))
            best = s;
    }
    return best;
}

function byName(a, b) {
    var x = a.name.toLowerCase(), y = b.name.toLowerCase();
    return x < y ? -1 : x > y ? 1 : 0;
}

function rank(query, entries) {
    var q = (query || "").toLowerCase(), found = [];
    for (var i = 0; i < entries.length; i++) {
        var e = entries[i];
        var s = q.length ? score(e.name || "", q) : 0;
        if (s !== null)
            found.push({ entry: e, score: s });
    }
    found.sort(function (a, b) {
        return b.score - a.score || byName(a.entry, b.entry);
    });
    var out = [];
    for (var j = 0; j < found.length; j++)
        out.push(found[j].entry);
    return out;
}
