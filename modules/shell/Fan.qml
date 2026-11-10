pragma Singleton

// Fan boost (rice-fan, modules/power): `mode` is "max", "auto" or "manual",
// "" where the fans can't be driven. Polled slowly (30 s) and right after a
// toggle; boost stays on until turned off or a reboot, so the bars show it.
// Shared by both shells (modules/umbriel copies it in, with power.js).
import QtQuick
import Quickshell
import Quickshell.Io
import "power.js" as P

Singleton {
    id: root

    property string mode: ""
    readonly property bool available: mode !== ""
    readonly property bool boost: mode === "max"

    function refresh() {
        probe.running = true;
    }

    function toggle() {
        toggler.running = true;
    }

    Process {
        id: probe
        running: true
        command: ["rice-fan", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.mode = P.fanMode(text)
        }
    }

    Process {
        id: toggler
        command: ["rice-fan", "toggle"]
        onExited: root.refresh()
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.refresh()
    }
}
