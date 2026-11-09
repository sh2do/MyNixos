pragma Singleton

// The season (season.js): what it is, and what it touches given the night,
// the real weather (Weather.qml) and focus mode (Focus.qml). The date is
// stepped by Weather's minute clock, so it has no timer of its own.
// RICE_SEASON=spring (summer, october, december, none) forces one. Shared by
// both shells: the niri bar copies it in with season.js, SeasonField.qml and
// SeasonTrinkets.qml (modules/shell/default.nix).
import QtQuick
import Quickshell
import "season.js" as S

Singleton {
    readonly property string forced: Quickshell.env("RICE_SEASON") ?? ""
    readonly property string name: S.season(new Date(Weather.now * 1000), forced)

    // {sprite, count, trinkets, flicker}; `night` is the caller's own
    // (Theme.night on niri, Palette.night on Umbriel).
    function touch(night) {
        return S.touches(name, { night: night, weather: Weather.kind, focus: Focus.on });
    }
}
