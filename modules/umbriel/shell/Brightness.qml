pragma Singleton

// Screen brightness (0..1) from /sys/class/backlight, the same way as the
// niri shell's modules/shell/Brightness.qml. sysfs doesn't send change
// events, so it is re-read twice a second while `watching` (the island sets
// it false while it is hidden); the file is tiny.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string device: ""
    property real max: 1
    property real current: 0
    readonly property bool available: device.length > 0
    property bool watching: true
    readonly property real value: max > 0 ? current / max : 0

    function change(step) {
        Quickshell.execDetached(["brightnessctl", "--class=backlight", "set", step > 0 ? "5%+" : "5%-"]);
    }

    Process {
        command: ["sh", "-c", "ls /sys/class/backlight | head -n 1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    FileView {
        path: root.available ? `/sys/class/backlight/${root.device}/max_brightness` : ""
        onLoaded: root.max = parseInt(text()) || 1
    }

    FileView {
        id: now
        path: root.available ? `/sys/class/backlight/${root.device}/brightness` : ""
        onLoaded: root.current = parseInt(text()) || 0
    }

    Timer {
        running: root.available && root.watching
        repeat: true
        interval: 500
        onTriggered: now.reload()
    }
}
