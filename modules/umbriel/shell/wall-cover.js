.pragma library

// Is a live wallpaper's moving part hidden by windows? Pure geometry, no QML,
// so tests/wall-cover-test.js can run it under node.
//
// windows: Umbriel's `windows` snapshot (layout coordinates).
// out:     the output, {name, x, y, w, h} in layout coordinates.
// area:    the moving part, {x, y, w, h} as fractions of the output.
//
// A fullscreen or maximized window over the output's centre hides everything
// (a maximized column can be scrolled off and still be "visible"). Otherwise
// the area counts as hidden when every point of a grid over it (edges
// included, so gaps between windows count) is under some window; two tiled
// columns side by side can hide it together.

const GRID_X = 17;
const GRID_Y = 11;

function covered(windows, out, area) {
    const shown = windows.filter(w => w.output === out.name && w.visible && !w.minimized);
    const cx = out.x + out.w / 2, cy = out.y + out.h / 2;
    if (shown.some(w => (w.fullscreen || w.maximized) && cx >= w.x && cx < w.x + w.w && cy >= w.y && cy < w.y + w.h))
        return true;
    if (!shown.length)
        return false;
    // Half a pixel in from the area's edges.
    const ax = out.x + area.x * out.w + 0.5, ay = out.y + area.y * out.h + 0.5;
    const aw = area.w * out.w - 1, ah = area.h * out.h - 1;
    for (let i = 0; i < GRID_X; i++) {
        const px = ax + i * aw / (GRID_X - 1);
        for (let j = 0; j < GRID_Y; j++) {
            const py = ay + j * ah / (GRID_Y - 1);
            if (!shown.some(w => px >= w.x && px < w.x + w.w && py >= w.y && py < w.y + w.h))
                return false;
        }
    }
    return true;
}
