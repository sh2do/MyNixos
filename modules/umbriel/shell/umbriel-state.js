.pragma library

// Pure helpers over Umbriel's IPC snapshots (see UmbrielIpc.qml). No flatMap
// or other newer methods: Qt's JS engine lacks some of them.

// The workspaces of one output, in order, as {id, index, active, occupied}.
// Umbriel lists only workspaces that exist (occupied or active).
function workspacesFor(list, output) {
    var r = [];
    for (var i = 0; i < (list || []).length; i++) {
        var w = list[i];
        if (w.output === output)
            r.push({ id: w.id, index: w.index, active: !!w.active, occupied: !!w.occupied });
    }
    r.sort(function (a, b) { return a.index - b.index; });
    return r;
}

// True while the focused window on that output is fullscreen and showing.
function fullscreenFocused(windows, output) {
    for (var i = 0; i < (windows || []).length; i++) {
        var w = windows[i];
        if (w.output === output && w.focused && w.fullscreen && w.visible)
            return true;
    }
    return false;
}
