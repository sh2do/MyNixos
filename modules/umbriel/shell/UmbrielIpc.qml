pragma Singleton

// Windows, workspaces and outputs from `umbriel subscribe` (JSON
// lines on $UMBRIEL_SOCKET). Each event is a full snapshot of its family, so
// the newest one simply replaces the list; nothing is merged.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ipc

    // Umbriel's entries as they arrive (see its docs/user/ipc.md): windows
    // carry id, output, workspace, x/y/w/h (layout coordinates), visible,
    // minimized, fullscreen, maximized, focused…; workspaces carry id, index,
    // name, output, active, focused, occupied, window_count…; outputs carry
    // name, enabled, powered (false while DPMS has it off), focused…
    property var windows: []
    property var workspaces: []
    property var outputs: []

    function handle(event) {
        if (event.event === "windows")
            windows = event.data;
        else if (event.event === "workspaces")
            workspaces = event.data;
        else if (event.event === "outputs")
            outputs = event.data;
    }

    Process {
        id: stream
        command: ["umbriel", "subscribe", "workspaces,windows,outputs"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    ipc.handle(JSON.parse(line));
                } catch (e) {}
            }
        }
        // Umbriel restarted or the stream broke (or it never started): try
        // again in a second. The first events of a new stream are snapshots.
        onRunningChanged: if (!running) restart.start()
    }

    Timer {
        id: restart
        interval: 1000
        onTriggered: stream.running = true
    }
}
