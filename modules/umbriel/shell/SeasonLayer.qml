// The season over the desktop (Season.qml, season.js): petals in spring,
// fireflies on summer nights, sparse snow in December, drifting down the
// right of the screen from under the island to the raven's corner, where
// they settle on the status row's level or melt. On the Bottom layer: over
// the wallpaper, under every window, and click-through.
//
// shell.qml loads it only while a season has sprites, so outside one there is
// no window and no clock. Its clock is a 15 Hz Timer (season.js's HZ),
// running only while it can be seen: not fullscreen, locked, with the screen
// off, or with windows covering all of it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as U
import "season.js" as S
import "raven-mood.js" as Mood
import "wall-cover.js" as Cover

PanelWindow {
    id: layer

    visible: !U.UmbrielIpc.fullscreen

    // The right part of the screen: the island's right half down to the
    // raven's corner.
    readonly property real share: 0.55
    anchors {
        top: true
        right: true
        bottom: true
    }
    implicitWidth: Math.round((screen?.width ?? 1920) * share)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "umbriel-season"
    mask: Region {}

    readonly property var touch: U.Season.touch(U.Palette.night > 0.5)

    readonly property bool covered: Cover.covered(U.UmbrielIpc.windows, {
        name: screen?.name ?? "",
        x: screen?.x ?? 0,
        y: screen?.y ?? 0,
        w: screen?.width ?? 0,
        h: screen?.height ?? 0
    }, { x: 1 - share, y: 0, w: share, h: 1 })
    readonly property bool running: visible && !locked && !covered && !Cover.outputOff(U.UmbrielIpc.outputs, screen?.name ?? "")

    // Umbriel's IPC doesn't report the session lock; the rice-lock locker
    // keeps this file while it is secure (as Raven.qml reads it).
    property bool locked: false
    FileView {
        id: lockFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/rice-lock.secure"
        printErrors: false
        onLoaded: layer.locked = true
        onLoadFailed: layer.locked = false
    }
    Timer {
        interval: 2000
        repeat: true
        running: layer.visible
        onTriggered: lockFile.reload()
    }

    Timer {
        property real last: 0
        interval: 1000 / S.HZ
        repeat: true
        running: layer.running && field.active
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            field.step(Mood.clockStep((now - last) / 1000, S.HZ));
            last = now;
        }
    }

    SeasonField {
        id: field
        anchors.fill: parent
        touch: layer.touch
        // Below the island, above the status row; petals and flakes come
        // down low, near the raven, before they settle or melt.
        box: ({ x: 24, y: 70, w: layer.width - 48, h: layer.height - 70 - 48, k: 2, drift: 0, land: [0.6, 1] })
        petal: Qt.tint("#f2c3d1", Qt.alpha(U.Palette.slate, 0.2))
    }
}
