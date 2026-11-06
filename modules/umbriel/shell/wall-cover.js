.pragma library

// Is a live wallpaper's moving part hidden? Pure geometry, no QML, so
// tests/wall-cover-test.js can run it under node.
//
// windows: Umbriel's `windows` snapshot (layout coordinates).
// out:     the output, {name, x, y, w, h} in layout coordinates.
// area:    the moving part, {x, y, w, h} as fractions of the output.
//
// A fullscreen or maximized window over the output's centre hides everything
// (a maximized column can be scrolled off and still be "visible"). Otherwise
// the area counts as hidden only when the windows cover all of it: the area's
// edges and every window edge inside it cut it into cells, each cell lies
// wholly inside or outside each window, so testing one point per cell is
// exact. A gap of any width between windows keeps the wallpaper running.

// The cut positions along one axis, sorted, clipped to [lo, hi].
function cuts(lo, hi, edges) {
    const inside = edges.filter(e => e > lo && e < hi);
    return [lo, hi].concat(inside).sort((a, b) => a - b);
}

function covered(windows, out, area) {
    const shown = windows.filter(w => w.output === out.name && w.visible && !w.minimized);
    const cx = out.x + out.w / 2, cy = out.y + out.h / 2;
    if (shown.some(w => (w.fullscreen || w.maximized) && cx >= w.x && cx < w.x + w.w && cy >= w.y && cy < w.y + w.h))
        return true;
    if (!shown.length)
        return false;
    const x0 = out.x + area.x * out.w, x1 = x0 + area.w * out.w;
    const y0 = out.y + area.y * out.h, y1 = y0 + area.h * out.h;
    // (No Array.flatMap: Qt's JS engine lacks it.)
    const ex = [], ey = [];
    for (const w of shown) {
        ex.push(w.x, w.x + w.w);
        ey.push(w.y, w.y + w.h);
    }
    const xs = cuts(x0, x1, ex);
    const ys = cuts(y0, y1, ey);
    for (let i = 0; i + 1 < xs.length; i++) {
        if (xs[i + 1] === xs[i])
            continue;
        const px = (xs[i] + xs[i + 1]) / 2;
        for (let j = 0; j + 1 < ys.length; j++) {
            if (ys[j + 1] === ys[j])
                continue;
            const py = (ys[j] + ys[j + 1]) / 2;
            if (!shown.some(w => px >= w.x && px < w.x + w.w && py >= w.y && py < w.y + w.h))
                return false;
        }
    }
    return true;
}

// Is the output switched off (DPMS)? outputs: Umbriel's `outputs` snapshot.
// Unknown outputs count as on, so nothing pauses before the first event.
function outputOff(outputs, name) {
    return outputs.some(o => o.name === name && o.powered === false);
}

// Does a window hide the screen point (fractions of the output)? Same
// "visible" windows as `covered`, so it means the active workspace.
function pointCovered(windows, out, fx, fy) {
    const px = out.x + fx * out.w, py = out.y + fy * out.h;
    return windows.some(w => w.output === out.name && w.visible && !w.minimized && px >= w.x && px < w.x + w.w && py >= w.y && py < w.y + w.h);
}
