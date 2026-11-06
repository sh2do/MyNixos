// The wallpaper: a still image cover-cropped to the screen, on the Background
// layer. Two are live (walls.json `live`): "rain" adds RainFrame over the
// picture, "storm" swaps the still for StormSky. Their one clock ticks at
// 30 Hz (15 for the storm) and stops while `paused`, so a hidden wallpaper
// costs no frames.
//
// The current id is umbriel-wall's state file; the picker writes it and this
// reloads when it changes. Task 7's eyes read `wallId` (and `walls`).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as U
import "wall-cover.js" as Cover

PanelWindow {
    id: bg

    readonly property string home: Quickshell.env("HOME")
    readonly property string wallDir: Quickshell.env("UMBRIEL_WALL_DIR") || home + "/.local/share/wallpapers/umbriel"
    readonly property string stateDir: Quickshell.env("UMBRIEL_STATE_DIR") || home + "/.local/state/umbriel"
    readonly property string defaultId: "xe9223"

    property var walls: ({})
    property string stateText: ""
    readonly property string wallId: walls[stateText.trim()] ? stateText.trim() : defaultId
    readonly property var wall: walls[wallId] ?? null
    readonly property string live: wall?.live ?? ""

    // The part that moves, as screen fractions: the rain's frame, or all of it.
    readonly property var liveArea: live === "rain" ? wall.rainRect : ({ x: 0, y: 0, w: 1, h: 1 })
    readonly property bool paused: live !== "" && Cover.covered(UmbrielIpc.windows, {
        name: screen?.name ?? "",
        x: screen?.x ?? 0,
        y: screen?.y ?? 0,
        w: screen?.width ?? 0,
        h: screen?.height ?? 0
    }, liveArea)

    // Seconds, wrapped hourly (a multiple of every period used) to keep the
    // shader's floats precise.
    property real clock: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "umbriel-background"
    color: U.Palette.bg

    FileView {
        path: Quickshell.shellDir + "/walls.json"
        blockLoading: true
        onLoaded: bg.walls = JSON.parse(text())
    }

    FileView {
        id: state
        path: bg.stateDir + "/current"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: bg.stateText = text()
        onLoadFailed: {
            bg.stateText = "";
            // The watcher only sees a file that exists, so on the first login
            // write the default once and load that.
            if (!seed.tried) {
                seed.tried = true;
                seed.running = true;
            }
        }
    }

    Process {
        id: seed
        property bool tried: false
        command: ["umbriel-wall", "set", bg.defaultId]
        onExited: state.reload()
    }

    // Rain needs 30 Hz to read as falling; the storm's slow drift is smooth at 15.
    Timer {
        interval: bg.live === "storm" ? 66 : 33
        repeat: true
        running: bg.live !== "" && !bg.paused
        onTriggered: bg.clock = (bg.clock + interval / 1000) % 3600
    }

    Item {
        id: stage
        anchors.fill: parent

        Image {
            id: still
            anchors.fill: parent
            visible: bg.live !== "storm"
            source: bg.wall && bg.live !== "storm" ? "file://" + bg.wallDir + "/" + bg.wall.file : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(bg.width, bg.height)
            asynchronous: true
            smooth: true
        }

        Loader {
            anchors.fill: parent
            active: bg.live === "rain"
            sourceComponent: RainFrame {
                rect: bg.wall.rainRect
                glow: bg.wall.glow
                time: bg.clock
            }
        }

        Loader {
            anchors.fill: parent
            active: bg.live === "storm"
            sourceComponent: StormSky {
                source: "file://" + bg.wallDir + "/" + bg.wall.file
                flash: bg.wall.flash
                time: bg.clock
                paused: bg.paused
            }
        }
    }

    // Fade the new picture in from the background colour.
    onWallIdChanged: fadeIn.restart()

    NumberAnimation {
        id: fadeIn
        target: stage
        property: "opacity"
        from: 0
        to: 1
        duration: 500
        easing.type: Easing.OutCubic
    }
}
