pragma Singleton

// A game in GameMode (gamemoderun), from gamemoded on the session bus: how
// many games it serves (its ClientCount). Polled every 10 s, a couple of
// busctl calls: first whether gamemoded is on the bus at all (NameHasOwner,
// which never starts it), and only then the count. Nothing else runs; with
// no game `on` is false. While on, both shells go calm (Focus.qml's `calm`)
// and show a controller chip. Shared by both shells (modules/umbriel copies
// it in). RICE_GAME_PROBE swaps the probe for another command (tests).
import QtQuick
import Quickshell
import Quickshell.Io
import "game.js" as G

Singleton {
    id: root

    property var state: ({ up: false, clients: 0 })
    readonly property int clients: state.clients
    readonly property bool on: clients > 0
    // "game", "2 games", "" with none.
    readonly property string label: G.label(clients)

    readonly property string override: Quickshell.env("RICE_GAME_PROBE") ?? ""

    Process {
        id: probe
        running: true
        command: ["sh", "-c", root.override || `
            o=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus \
                org.freedesktop.DBus NameHasOwner s com.feralinteractive.GameMode 2>/dev/null) || exit 0
            echo "owner $o"
            case $o in *true) ;; *) exit 0 ;; esac
            echo "clients $(busctl --user get-property com.feralinteractive.GameMode \
                /com/feralinteractive/GameMode com.feralinteractive.GameMode ClientCount 2>/dev/null)"`]
        stdout: StdioCollector {
            onStreamFinished: root.state = G.parse(text)
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 10000
        onTriggered: if (!probe.running) probe.running = true
    }
}
