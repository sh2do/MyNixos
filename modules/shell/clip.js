.pragma library
// The clipboard panel's pure logic: reading `cliphist list` and searching it.

// "[[ binary data 321 KiB png 422x429 ]]", cliphist's preview of an image.
const IMAGE = /^\[\[ binary data (\d+(?:\.\d+)? \S+) (\w+) (\d+)x(\d+) \]\]$/;

// One entry per line of `cliphist list` (newest first): { id, line, text, image },
// where line is the raw row (what `cliphist decode`/`delete` take back) and image
// is null for text or { ext, width, height, size }.
function parse(text) {
    const out = [];
    for (const line of String(text).split("\n")) {
        const tab = line.indexOf("\t");
        if (tab < 1)
            continue;
        const id = line.slice(0, tab);
        if (!/^\d+$/.test(id))
            continue;
        const preview = line.slice(tab + 1);
        const m = IMAGE.exec(preview);
        const image = m ? {
            ext: m[2] === "jpeg" ? "jpg" : m[2],
            width: Number(m[3]),
            height: Number(m[4]),
            size: m[1]
        } : null;
        out.push({ id: id, line: line, text: preview, image: image });
    }
    return out;
}

// Where an image entry's thumbnail is decoded to (rice-clip thumbs), or "" for text.
function thumbPath(dir, entry) {
    return entry.image ? dir + "/" + entry.id + "." + entry.image.ext : "";
}

// The text a row shows.
function label(entry) {
    const i = entry.image;
    return i ? i.ext + " image · " + i.width + "×" + i.height + " · " + i.size : entry.text;
}

// Entries holding every word of the query (any case), newest first.
// Images also answer to "image" and their format.
function filter(entries, query) {
    const words = String(query).toLowerCase().split(/\s+/).filter(w => w.length);
    if (!words.length)
        return entries.slice();
    return entries.filter(e => {
        const hay = (e.image ? "image " + e.image.ext + " " + e.text : e.text).toLowerCase();
        return words.every(w => hay.indexOf(w) >= 0);
    });
}
