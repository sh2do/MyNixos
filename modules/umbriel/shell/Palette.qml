pragma Singleton

// The Umbriel slate palette: one cold grey ramp and a single accent, `bright`,
// which is only ever used with a glow. No hue anywhere.
//
// QtQuick has a `Palette` type of its own that wins over this one, so use it
// through a qualified import of this directory: `import "." as U`, then
// `U.Palette.bg`.
import QtQuick
import Quickshell

Singleton {
    readonly property color bg: "#0a0b0e"
    readonly property color panel: Qt.rgba(6 / 255, 7 / 255, 9 / 255, 0.9) // #060709 at 0.9
    readonly property color raised: "#14161b"
    readonly property color line: "#262a31"
    readonly property color muted: "#7d8796"
    readonly property color text: "#d6dbe3"
    readonly property color bright: "#eef1f5"
    readonly property color slate: "#4a4f58"

    // The viper
    readonly property color viperBody: "#4a4f58"
    readonly property color viperBlotch: "#262a31"
    readonly property color viperKeel: "#8b94a3"
    readonly property color viperOutline: "#0d0f12"
    readonly property color viperEye: "#c7ccd4"

    readonly property string font: "JetBrainsMono Nerd Font"
}
