pragma Singleton

// Colours and sizes for the whole shell. Colours come from
// ~/.cache/rice/colors.json (written by rice-wall); any missing or broken
// value falls back to the rain + hydrangea palette.
import QtQuick
import Quickshell
import Quickshell.Io

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

    readonly property color primary: pick("primary")
    readonly property color textOnPrimary: pick("onPrimary")
    readonly property color primaryContainer: pick("primaryContainer")
    readonly property color secondary: pick("secondary")
    readonly property color tertiary: pick("tertiary")
    readonly property color surface: pick("surface")
    readonly property color surfaceContainer: pick("surfaceContainer")
    readonly property color surfaceContainerHigh: pick("surfaceContainerHigh")
    readonly property color text: pick("onSurface")
    readonly property color textMuted: pick("onSurfaceVariant")
    readonly property color outline: pick("outline")
    readonly property color error: pick("error")
    readonly property string wallpaper: typeof colours.wallpaper === "string" ? colours.wallpaper : ""

    readonly property int radius: 14
    readonly property int barHeight: 38
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
