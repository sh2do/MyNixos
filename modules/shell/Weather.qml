pragma Singleton

// The real weather, from rice-weather's file (modules/weather): read once a
// minute, and the scene (weather.js) eased toward it over about 10 s in
// half-second steps, only while it changes. No file, a stale one (3 h), or
// no network: `scene` is the shells' own, as before. RICE_WEATHER=storm (or
// clear, cloudy, fog, drizzle, rain, snow) forces a kind. Shared by both
// shells (modules/umbriel copies it in).
import QtQuick
import Quickshell
import Quickshell.Io
import "weather.js" as W

Singleton {
    id: root

    readonly property string forced: Quickshell.env("RICE_WEATHER") ?? ""
    readonly property string path: Quickshell.env("RICE_WEATHER_FILE")
        || (Quickshell.env("RICE_STATE_DIR") || Quickshell.env("HOME") + "/.cache/rice") + "/weather.json"

    property string text: ""
    property real now: Date.now() / 1000
    // {kind, intensity, wind, isDay, updated}, or null.
    readonly property var current: W.parse(text, now, forced)
    readonly property string kind: current?.kind ?? ""
    readonly property var target: W.scene(current)
    // The scene as drawn, easing toward `target`.
    property var scene: W.scene(null)

    FileView {
        id: file
        path: root.path
        printErrors: false
        onLoaded: {
            root.text = text();
            root.prime();
        }
        onLoadFailed: {
            root.text = "";
            root.prime();
        }
    }

    // The first reading (or a forced kind) is there from the start, not eased in.
    property bool primed: false
    function prime() {
        if (!primed)
            scene = target;
        primed = true;
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            root.now = Date.now() / 1000;
            file.reload();
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: !W.settled(root.scene, root.target)
        onTriggered: root.scene = W.ease(root.scene, root.target, interval)
    }
}
