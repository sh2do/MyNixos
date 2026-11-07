pragma Singleton

// The paired phone, from KDE Connect's daemon (kdeconnectd) on the session
// bus: its name, whether it's reachable, and its battery. Polled every 30 s
// (a few busctl calls) and right after an action; nothing is paired, or no
// daemon runs: `phone` is null and the chip and glyph hide. Shared by both
// shells (modules/umbriel copies it in).
import QtQuick
import Quickshell
import Quickshell.Io
import "phone.js" as P

Singleton {
    id: root

    property var devices: []
    readonly property var phone: P.pick(devices)
    readonly property bool paired: phone !== null
    readonly property bool reachable: phone?.reachable ?? false
    readonly property int charge: phone?.charge ?? -1
    readonly property bool charging: phone?.charging ?? false
    // "87%", "40%+" while charging, "" when unknown or away.
    readonly property string battery: P.label(phone)

    function refresh() {
        if (!probe.running)
            probe.running = true;
    }

    // Find my phone: it rings until it's found.
    function ring() {
        if (phone)
            Quickshell.execDetached(["kdeconnect-cli", "-d", phone.id, "--ring"]);
    }

    // Send a file: choose one with zenity, then share it.
    function sendFile() {
        if (phone)
            Quickshell.execDetached(["sh", "-c",
                'f=$(zenity --file-selection --title="Send to $2") && exec kdeconnect-cli -d "$1" --share "$f"',
                "sh", phone.id, phone.name]);
    }

    Process {
        id: probe
        running: true
        command: ["sh", "-c", `
            k() { busctl --user get-property org.kde.kdeconnect "$@" 2>/dev/null; }
            out=$(busctl --user call org.kde.kdeconnect /modules/kdeconnect \
                org.kde.kdeconnect.daemon devices bb false true 2>/dev/null) || exit 0
            echo "devices $out"
            for id in $(printf '%s\\n' "$out" | cut -d' ' -f3- | tr -d '"'); do
                d=/modules/kdeconnect/devices/$id
                echo "id $id"
                echo "name $(k "$d" org.kde.kdeconnect.device name)"
                echo "reachable $(k "$d" org.kde.kdeconnect.device isReachable)"
                echo "charge $(k "$d/battery" org.kde.kdeconnect.device.battery charge)"
                echo "charging $(k "$d/battery" org.kde.kdeconnect.device.battery isCharging)"
            done`]
        stdout: StdioCollector {
            onStreamFinished: root.devices = P.parse(text)
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: root.refresh()
    }
}
