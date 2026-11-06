// A hidden detail: now and then, in a dark corner of the wallpaper, a pair of
// small pale eyes opens, blinks once and closes. The spots are the current
// wallpaper's `eyes` in walls.json, as fractions of the screen. It skips a
// turn while the wallpaper is hidden (`paused`) or a window sits on the spot.
// One single-shot timer waits between appearances; nothing runs in between.
//
// UMBRIEL_HIDDEN_DEBUG=1 shortens the wait to 10 s.
import QtQuick
import Quickshell
import "." as U
import "wall-cover.js" as Cover

Item {
    id: eyes

    // The Background this sits in.
    required property var bg

    readonly property bool debug: Quickshell.env("UMBRIEL_HIDDEN_DEBUG") === "1"
    property real spotX: 0
    property real spotY: 0
    // 0 shut, 1 open; the blink dips it.
    property real lid: 0

    anchors.fill: parent

    function waitMs() {
        return debug ? 10000 : (25 + Math.random() * 35) * 60000;
    }

    function rest() {
        wait.interval = waitMs();
        wait.restart();
    }

    // The wallpaper's spots that no window covers.
    function freeSpots() {
        const out = {
            name: bg.screen?.name ?? "",
            x: bg.screen?.x ?? 0,
            y: bg.screen?.y ?? 0,
            w: bg.screen?.width ?? 0,
            h: bg.screen?.height ?? 0
        };
        return (bg.wall?.eyes ?? []).filter(p => !Cover.pointCovered(UmbrielIpc.windows, out, p.x, p.y));
    }

    Timer {
        id: wait
        interval: eyes.waitMs()
        running: true
        onTriggered: {
            const spots = bg.paused ? [] : eyes.freeSpots();
            if (spots.length === 0) {
                eyes.rest();
                return;
            }
            const p = spots[Math.floor(Math.random() * spots.length)];
            eyes.spotX = p.x * eyes.width;
            eyes.spotY = p.y * eyes.height;
            glance.start();
        }
    }

    // About 1.2 s: open, blink once, shut.
    SequentialAnimation {
        id: glance
        NumberAnimation { target: eyes; property: "lid"; to: 1; duration: 300; easing.type: Easing.OutSine }
        PauseAnimation { duration: 250 }
        NumberAnimation { target: eyes; property: "lid"; to: 0.05; duration: 90 }
        NumberAnimation { target: eyes; property: "lid"; to: 1; duration: 110 }
        PauseAnimation { duration: 100 }
        NumberAnimation { target: eyes; property: "lid"; to: 0; duration: 350; easing.type: Easing.InSine }
        onFinished: eyes.rest()
    }

    Repeater {
        model: [-5.5, 2.5]

        Rectangle {
            required property real modelData
            x: eyes.spotX + modelData
            y: eyes.spotY - 1.5
            width: 3
            height: 3
            radius: 1.5
            color: U.Palette.viperEye
            opacity: eyes.lid
            visible: opacity > 0
        }
    }
}
