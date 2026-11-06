pragma Singleton

// Workspaces and the focused window, from `niri msg --json event-stream`.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: niri

    // [{ id, idx, output, isActive, isFocused }], sorted by idx
    property var workspaces: []
    property var windows: ({})
    property int focusedWindowId: -1

    readonly property var focusedWindow: windows[focusedWindowId] ?? null
    readonly property string focusedTitle: focusedWindow?.title ?? ""
    readonly property string focusedAppId: focusedWindow?.app_id ?? ""

    function focusWorkspace(idx) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }

    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output);
    }

    function setWorkspaces(list) {
        workspaces = list.map(w => ({
            id: w.id,
            idx: w.idx,
            output: w.output,
            isActive: w.is_active,
            isFocused: w.is_focused
        })).sort((a, b) => a.idx - b.idx);
    }

    function activate(id, focused) {
        const target = workspaces.find(w => w.id === id);
        if (!target)
            return;
        workspaces = workspaces.map(w => Object.assign({}, w, {
            isActive: w.output === target.output ? w.id === id : w.isActive,
            isFocused: focused ? w.id === id : w.isFocused
        }));
    }

    function putWindow(w) {
        const next = Object.assign({}, windows);
        next[w.id] = w;
        windows = next;
        if (w.is_focused)
            focusedWindowId = w.id;
    }

    function handle(event) {
        if (event.WorkspacesChanged) {
            setWorkspaces(event.WorkspacesChanged.workspaces);
        } else if (event.WorkspaceActivated) {
            activate(event.WorkspaceActivated.id, event.WorkspaceActivated.focused);
        } else if (event.WindowsChanged) {
            const next = {};
            let focused = -1;
            for (const w of event.WindowsChanged.windows) {
                next[w.id] = w;
                if (w.is_focused)
                    focused = w.id;
            }
            windows = next;
            focusedWindowId = focused;
        } else if (event.WindowOpenedOrChanged) {
            putWindow(event.WindowOpenedOrChanged.window);
        } else if (event.WindowClosed) {
            const next = Object.assign({}, windows);
            delete next[event.WindowClosed.id];
            windows = next;
            if (focusedWindowId === event.WindowClosed.id)
                focusedWindowId = -1;
        } else if (event.WindowFocusChanged) {
            focusedWindowId = event.WindowFocusChanged.id ?? -1;
        }
    }

    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    niri.handle(JSON.parse(line));
                } catch (e) {}
            }
        }
        // Reconnect if niri restarts the stream.
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 1000
        onTriggered: stream.running = true
    }
}
