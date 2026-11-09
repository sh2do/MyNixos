pragma Singleton

// Colours and sizes for the whole shell. Colours come from
// ~/.cache/rice/colors.json (written by rice-wall); any missing or broken
// value falls back to the rain + hydrangea palette.
//
// Night shift: after dark (raven-mood.js's isNight, the ravens' clock; or
// always with RICE_NIGHT=1) `night` eases 0 -> 1 over two minutes, in 2 s
// steps, and every colour below dims about 12% and cools toward the dim
// surface; text only a little, so it keeps its contrast. Consumers follow
// through these properties; nothing repaints between steps.
import QtQuick
import Quickshell
import Quickshell.Io
import "raven-mood.js" as Mood

Singleton {
    id: theme

    readonly property var fallback: ({
        primary: "#dbbce5",
        onPrimary: "#3e2848",
        primaryContainer: "#62496c",
        secondary: "#d2c1d4",
        tertiary: "#f6b6c1",
        surface: "#151315",
        surfaceContainer: "#211f21",
        surfaceContainerHigh: "#2c292c",
        onSurface: "#e7e1e4",
        onSurfaceVariant: "#cec3ce",
        outline: "#978e97",
        error: "#ffb4ab",
        wallpaper: ""
    })

    // JSON keys keep matugen's names; QML properties can't start with "on"
    // (that prefix means a signal handler), hence text / textMuted / textOnPrimary.
    property var colours: fallback

    function pick(key) {
        const v = colours[key];
        return (typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v)) ? v : fallback[key];
    }

    // ---- Night: 0 by day .. 1 by night, eased (fade is the linear part).
    // RICE_NIGHT=1 forces night, =0 day.
    readonly property string nightForced: Quickshell.env("RICE_NIGHT") ?? ""
    property real fade: 0
    readonly property real night: Mood.nightEase(fade)
    // The tone night cools toward: matugen's surface-dim if colors.json has
    // it, else the surface (the same tone in a dark scheme).
    readonly property color duskTone: {
        const v = colours.surfaceDim;
        return typeof v === "string" && /^#[0-9a-fA-F]{6}$/.test(v) ? v : pick("surface");
    }
    function dusk(c, k) {
        if (night <= 0)
            return c;
        const d = Mood.dusk(Qt.color(c), night, duskTone, k);
        return Qt.rgba(d.r, d.g, d.b, d.a);
    }
    Component.onCompleted: {
        Mood.forceNight(nightForced);
        fade = Mood.isNight(new Date()) ? 1 : 0;
    }
    Timer {
        // A look once a minute; every 2 s while it fades.
        interval: theme.fade > 0 && theme.fade < 1 ? 2000 : 60000
        running: true
        repeat: true
        onTriggered: theme.fade = Mood.nightFade(theme.fade, Mood.isNight(new Date()), 2000)
    }

    readonly property color primary: dusk(pick("primary"), 1)
    readonly property color textOnPrimary: dusk(pick("onPrimary"), 1)
    readonly property color primaryContainer: dusk(pick("primaryContainer"), 1)
    readonly property color secondary: dusk(pick("secondary"), 1)
    readonly property color tertiary: dusk(pick("tertiary"), 1)
    readonly property color surface: dusk(pick("surface"), 1)
    readonly property color surfaceContainer: dusk(pick("surfaceContainer"), 1)
    readonly property color surfaceContainerHigh: dusk(pick("surfaceContainerHigh"), 1)
    readonly property color text: dusk(pick("onSurface"), Mood.TEXT_DUSK)
    readonly property color textMuted: dusk(pick("onSurfaceVariant"), Mood.TEXT_DUSK)
    readonly property color outline: dusk(pick("outline"), 1)
    readonly property color error: dusk(pick("error"), Mood.TEXT_DUSK)
    readonly property string wallpaper: typeof colours.wallpaper === "string" ? colours.wallpaper : ""

    readonly property int radius: 14
    readonly property int barHeight: 42
    readonly property int fontSize: 13
    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    FileView {
        path: Quickshell.env("HOME") + "/.cache/rice/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                theme.colours = JSON.parse(text());
            } catch (e) {
                theme.colours = theme.fallback;
            }
        }
        onLoadFailed: theme.colours = theme.fallback
    }
}
