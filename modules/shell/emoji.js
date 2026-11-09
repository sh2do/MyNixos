.pragma library
// The emoji panel's pure logic: reading Unicode's emoji-test.txt (nixpkgs
// unicode-emoji) and searching it.

// "1F44B 1F3FB ; fully-qualified # 👋🏻 E1.0 waving hand: light skin tone"
const LINE = /^([0-9A-F ]+?)\s*;\s*fully-qualified\s*#\s*\S+\s+E\d+\.\d+\s+(.+)$/;
const TONE = /\b1F3F[B-F]\b/;

// Every fully-qualified emoji, in Unicode's order: { char, name, group, sub }.
// Skin-tone variants and bare components are left out, to keep the grid short.
function parse(text) {
    const out = [];
    let group = "", sub = "";
    for (const line of String(text).split("\n")) {
        if (line.startsWith("# group: ")) {
            group = line.slice(9).trim();
            continue;
        }
        if (line.startsWith("# subgroup: ")) {
            sub = line.slice(12).trim();
            continue;
        }
        if (group === "Component")
            continue;
        const m = LINE.exec(line);
        if (!m || TONE.test(m[1]))
            continue;
        const char = String.fromCodePoint.apply(null, m[1].trim().split(/\s+/).map(h => parseInt(h, 16)));
        out.push({ char: char, name: m[2].trim(), group: group, sub: sub });
    }
    return out;
}

// Whether word starts a word of s (after a space, '-', ':' or the start).
function startsWord(s, word) {
    let i = s.indexOf(word);
    while (i >= 0) {
        if (i === 0 || /[\s:\-&]/.test(s[i - 1]))
            return true;
        i = s.indexOf(word, i + 1);
    }
    return false;
}

// How well one query word fits an emoji: lower is better, -1 for no match.
function wordScore(e, name, word) {
    if (name.startsWith(word))
        return 1;
    if (startsWord(name, word))
        return 2;
    if (name.indexOf(word) >= 0)
        return 3;
    if (startsWord(e.sub, word) || startsWord(e.group.toLowerCase(), word))
        return 4;
    return -1;
}

// Emoji matching every word of the query, best first: the exact name, then names
// starting with it, then word starts, then subgroup and group matches. Ties keep
// Unicode's order. An empty query gives everything.
function search(list, query) {
    const q = String(query).toLowerCase().trim();
    const words = q.split(/\s+/).filter(w => w.length);
    if (!words.length)
        return list.slice();
    const hits = [];
    for (let i = 0; i < list.length; i++) {
        const e = list[i], name = e.name.toLowerCase();
        let score = 0;
        for (const w of words) {
            const s = wordScore(e, name, w);
            if (s < 0) {
                score = -1;
                break;
            }
            score += s;
        }
        if (score < 0)
            continue;
        hits.push({ e: e, i: i, score: name === q ? -1 : score });
    }
    hits.sort((a, b) => a.score - b.score || a.i - b.i);
    return hits.map(h => h.e);
}

// The groups in order: { name, index (of its first emoji), icon (that emoji) }.
function groups(list) {
    const out = [];
    for (let i = 0; i < list.length; i++) {
        if (!out.length || out[out.length - 1].name !== list[i].group)
            out.push({ name: list[i].group, index: i, icon: list[i].char });
    }
    return out;
}
