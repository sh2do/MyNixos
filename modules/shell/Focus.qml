pragma Singleton

// Focus mode, as rice-focus leaves it in $RICE_STATE_DIR/focus (focus.js
// reads it). The file is watched, so a toggle shows at once; a 60 s re-read
// covers a file made after start (nothing to watch yet). `label` is the
// elapsed time, stepped once a minute only while focused. Shared by both
// shells (modules/umbriel copies it in). RICE_FOCUS_FILE points it elsewhere.
import QtQuick
import Quickshell
import Quickshell.Io
import "focus.js" as F

Singleton {
    id: root

    readonly property string path: Quickshell.env("RICE_FOCUS_FILE")
        || (Quickshell.env("RICE_STATE_DIR") || Quickshell.env("HOME") + "/.cache/rice") + "/focus"

    property string text: ""
    readonly property var state: F.parse(text)
    readonly property bool on: state.on
    readonly property real since: state.since
    property real now: Date.now()
    readonly property string label: F.elapsed(now, since)

    function toggle() {
        Quickshell.execDetached(["rice-focus", "toggle"]);
    }

    onOnChanged: now = Date.now()

    FileView {
        id: file
        path: root.path
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.text = text()
        onLoadFailed: root.text = ""
    }

    // Re-reads only while the file is missing (no watch can be set on it).
    Timer {
        interval: 60000
        repeat: true
        running: root.text === ""
        onTriggered: file.reload()
    }

    Timer {
        interval: 60000
        repeat: true
        running: root.on
        onTriggered: root.now = Date.now()
    }
}
