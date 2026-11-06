pragma Singleton

// Windows and workspaces from `umbriel subscribe workspaces,windows` (JSON
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
    // name, output, active, focused, occupied, window_count…
    property var windows: []
    property var workspaces: []

    function handle(event) {
        if (event.event === "windows")
            windows = event.data;
        else if (event.event === "workspaces")
            workspaces = event.data;
    }

    Process {
        id: stream
        command: ["umbriel", "subscribe", "workspaces,windows"]
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
