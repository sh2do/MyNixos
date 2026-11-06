// The lock screen: its own Quickshell config, so it keeps working if the bar
// crashes. Started by `rice-lock` (swayidle, Super+Alt+L, before sleep).
//
//   RICE_LOCK_TEST=1     real lock that also unlocks itself after 15 s
//   RICE_LOCK_PREVIEW=1  no lock at all, just the screen in a normal window
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    readonly property bool testMode: Quickshell.env("RICE_LOCK_TEST") === "1"
    readonly property bool preview: Quickshell.env("RICE_LOCK_PREVIEW") === "1"

    // Shared by every screen's surface.
    property string password: ""
    property bool busy: false
    signal failed

    function submit() {
        if (busy || password.length === 0)
            return;
        busy = true;
        pam.start();
    }

    // rice-lock waits for this file before it returns (see rice-lock.sh).
    readonly property string marker: Quickshell.env("XDG_RUNTIME_DIR") + "/rice-lock.secure"

    function unlock() {
        Quickshell.execDetached(["rm", "-f", marker]);
        lock.locked = false;
        Qt.quit();
    }

    PamContext {
        id: pam
        config: "rice-lock"

        onPamMessage: {
            if (responseRequired)
                respond(root.password);
        }

        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.unlock();
            } else {
                root.password = "";
                root.failed();
            }
        }
    }

    WlSessionLock {
        id: lock
        locked: !root.preview
        onSecureChanged: if (secure) Quickshell.execDetached(["touch", root.marker])

        WlSessionLockSurface {
            color: "black"

            LockSurface {
                anchors.fill: parent
                lockRoot: root
            }
        }
    }

    LazyLoader {
        active: root.preview

        FloatingWindow {
            implicitWidth: 1280
            implicitHeight: 800
            color: "black"

            LockSurface {
                anchors.fill: parent
                lockRoot: root
            }
        }
    }

    Timer {
        running: root.testMode
        interval: 15000
        onTriggered: root.unlock()
    }
}
