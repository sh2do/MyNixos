// The shells' sounds. `play("notify" | "critical" | "tick")` starts one short
// `rice-sound` process (a pw-play) when sound.js allows it: not with
// RICE_SOUNDS=0, not at night (raven-mood.js's clock), not while the default
// sink is muted, and ticks no closer than 150 ms. Nothing runs while idle.
// Shared by both shells; Umbriel's build copies it in from modules/shell.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "sound.js" as Snd
import "raven-mood.js" as Mood

Scope {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    property real lastTick: -1e9

    PwObjectTracker {
        objects: [root.sink]
    }

    function play(kind) {
        const now = Date.now();
        const go = Snd.shouldPlay({
            env: Quickshell.env("RICE_SOUNDS") ?? "",
            night: Mood.isNight(new Date()),
            muted: root.sink?.audio?.muted ?? false,
            kind: kind,
            now: now,
            lastTick: root.lastTick
        });
        if (!go)
            return;
        if (kind === "tick")
            root.lastTick = now;
        Quickshell.execDetached(["rice-sound", Snd.soundFor(kind)]);
    }
}
