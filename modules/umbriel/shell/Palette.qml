pragma Singleton

// The Umbriel slate palette: one cold grey ramp and a single accent, `bright`,
// which is only ever used with a glow. No hue anywhere.
//
// QtQuick has a `Palette` type of its own that wins over this one, so use it
// through a qualified import of this directory: `import "." as U`, then
// `U.Palette.bg`.
//
// Night shift: after dark (raven-mood.js's isNight, the raven's clock; or
// always with UMBRIEL_NIGHT=1) `night` eases 0 -> 1 over two minutes, in 2 s
// steps, and the chrome (panel, lines, text, the accent) dims about 12% and
// cools toward `bg`; text only a little, so it keeps its contrast. The
// viper and raven keep their own colours; the hanging viper reads `night`.
import QtQuick
import Quickshell
import "raven-mood.js" as Mood

Singleton {
    id: palette

    // ---- Night: 0 by day .. 1 by night, eased (fade is the linear part).
    // UMBRIEL_NIGHT=1 forces night, =0 day.
    readonly property string nightForced: Quickshell.env("UMBRIEL_NIGHT") ?? ""
    property real fade: 0
    readonly property real night: Mood.nightEase(fade)
    function dusk(c, k) {
        if (night <= 0)
            return c;
        const d = Mood.dusk(Qt.color(c), night, Qt.color("#0a0b0e"), k);
        return Qt.rgba(d.r, d.g, d.b, d.a);
    }
    Component.onCompleted: {
        Mood.forceNight(nightForced);
        fade = Mood.isNight(new Date()) ? 1 : 0;
    }
    Timer {
        // A look once a minute; every 2 s while it fades.
        interval: palette.fade > 0 && palette.fade < 1 ? 2000 : 60000
        running: true
        repeat: true
        onTriggered: palette.fade = Mood.nightFade(palette.fade, Mood.isNight(new Date()), 2000)
    }

    readonly property color bg: "#0a0b0e"
    readonly property color panel: dusk(Qt.rgba(6 / 255, 7 / 255, 9 / 255, 0.9), 1) // #060709 at 0.9
    readonly property color raised: dusk("#14161b", 1)
    readonly property color line: dusk("#262a31", 1)
    readonly property color muted: dusk("#7d8796", Mood.TEXT_DUSK)
    readonly property color text: dusk("#d6dbe3", Mood.TEXT_DUSK)
    readonly property color bright: dusk("#eef1f5", Mood.TEXT_DUSK)
    readonly property color slate: dusk("#4a4f58", 1)

    // The viper
    readonly property color viperBody: "#4a4f58"
    readonly property color viperBlotch: "#262a31"
    readonly property color viperKeel: "#8b94a3"
    readonly property color viperOutline: "#0d0f12"
    readonly property color viperEye: "#c7ccd4"
    // The hanging viper's venom: the accent, always with a glow.
    readonly property color venom: bright

    // The raven: near-black, a slate edge on its feathers, a pale catch-light
    // in its eye and a paler nictitating membrane. Its hoard's trinkets are
    // the accent, always with a glow.
    readonly property color ravenBody: "#121419"
    readonly property color ravenEdge: "#3a404b"
    readonly property color ravenBeak: "#1b1e24"
    readonly property color ravenEye: "#c7ccd4"
    readonly property color ravenMembrane: "#8b94a3"
    readonly property color trinket: bright

    readonly property string font: "JetBrainsMono Nerd Font"
}
