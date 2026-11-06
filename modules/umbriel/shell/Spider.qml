// A hidden detail: every few minutes a small spider lowers itself on a silk
// line from the island's underside, hangs there swaying, and climbs back.
// It only comes while the island is collapsed and shown (not fullscreen).
// One single-shot timer waits between visits; nothing runs while it is away.
//
// UMBRIEL_HIDDEN_DEBUG=1 shortens the wait to 10 s.
import QtQuick
import Quickshell
import "." as U

Item {
    id: spider

    // The Island window this hangs from.
    required property var island

    readonly property bool debug: Quickshell.env("UMBRIEL_HIDDEN_DEBUG") === "1"
    // Whether a visit may start, or go on.
    readonly property bool allowed: island.visible && !island.expanded && !UmbrielIpc.fullscreen
    // The silk's length: 0 is home, up in the island.
    property real drop: 0

    // The anchor is in screen coordinates; the window sits at margins.top.
    x: island.width / 2
    y: island.anchorBottom.y - island.margins.top - 1
    visible: drop > 0

    function waitMs() {
        return debug ? 10000 : (3 + Math.random() * 5) * 60000;
    }

    Timer {
        id: wait
        interval: spider.waitMs()
        running: true
        onTriggered: {
            if (spider.allowed)
                spider.visit();
            else
                spider.rest();
        }
    }

    function rest() {
        wait.interval = waitMs();
        wait.restart();
    }

    // Something changed under the spider (the launcher opened, a fullscreen
    // window came): it is gone at once.
    onAllowedChanged: {
        if (!allowed && (lower.running || hang.running || climb.running)) {
            lower.stop();
            hang.stop();
            climb.stop();
            sway.stop();
            body.rotation = 0;
            drop = 0;
            rest();
        }
    }

    function visit() {
        lower.start();
    }

    NumberAnimation {
        id: lower
        target: spider
        property: "drop"
        from: 0
        to: 60
        duration: 1200
        easing.type: Easing.InOutSine
        onFinished: {
            hang.interval = 2000 + Math.random() * 2000;
            hang.start();
            sway.start();
        }
    }

    Timer {
        id: hang
        onTriggered: {
            sway.stop();
            body.rotation = 0;
            climb.start();
        }
    }

    NumberAnimation {
        id: climb
        target: spider
        property: "drop"
        to: 0
        duration: 1200
        easing.type: Easing.InOutSine
        onFinished: spider.rest()
    }

    SequentialAnimation {
        id: sway
        loops: Animation.Infinite
        NumberAnimation { target: body; property: "rotation"; to: 3; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: body; property: "rotation"; to: -3; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { target: body; property: "rotation"; to: 0; duration: 700; easing.type: Easing.InOutSine }
    }

    // The thread and the spider swing together from the top of the thread.
    Item {
        id: body
        transformOrigin: Item.Top
        width: 13
        height: spider.drop
        x: -width / 2

        Rectangle {
            x: 6
            width: 1
            height: parent.height - 5
            color: U.Palette.muted
            opacity: 0.7
        }

        // 13 px across: a round abdomen, a small head, eight legs.
        Item {
            id: bug
            x: 0
            y: body.height - 10
            width: 13
            height: 10

            // Four legs a side, hinged at the body's middle.
            Repeater {
                model: [-1, 1, -1, 1, -1, 1, -1, 1]

                Rectangle {
                    required property int index
                    required property int modelData
                    readonly property real tilt: [-38, -38, -14, -14, 12, 12, 34, 34][index]
                    x: modelData < 0 ? 0.5 : 6.5
                    y: 6
                    width: 6
                    height: 1
                    color: U.Palette.viperKeel
                    transformOrigin: modelData < 0 ? Item.Right : Item.Left
                    rotation: modelData < 0 ? -tilt : tilt
                }
            }

            Rectangle {
                x: 4
                y: 4
                width: 5
                height: 6
                radius: 2.5
                color: U.Palette.viperKeel
            }
            Rectangle {
                x: 5
                y: 1
                width: 3
                height: 3
                radius: 1.5
                color: U.Palette.viperKeel
            }
        }
    }
}
