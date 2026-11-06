// The curled cobra in the bottom bar. Original art in assets/, white on
// transparent, tinted with the wallpaper colours. It breathes, sways its hood
// and now and then flicks its tongue. Everything stops while `running` is false.
// One 25 fps tick drives it all: the moves are slow, and repainting the bar
// at the screen's 144 Hz cost ~15% CPU for no visible gain.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property bool running: false

    implicitWidth: 34
    implicitHeight: 34

    // One tinted SVG layer filling the 64x64 art box.
    component Layer: Item {
        property alias source: img.source
        property color tint: Theme.primary

        anchors.fill: parent

        Image {
            id: img
            anchors.fill: parent
            sourceSize: Qt.size(root.width * 2, root.height * 2)
            smooth: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: img
            colorization: 1
            colorizationColor: parent.tint
        }
    }

    // Art units (64 per side) to pixels.
    readonly property real unit: width / 64

    // Milliseconds of animation so far, and when the next tongue flick starts.
    property real t: 0
    property real nextFlick: 8000
    readonly property real flickPhase: Math.max(0, Math.min(1, (t - nextFlick + 300) / 300))

    Timer {
        running: root.running
        repeat: true
        interval: 40
        onTriggered: {
            root.t += interval;
            if (root.t > root.nextFlick)
                root.nextFlick = root.t + 8000 + Math.random() * 7000;
        }
    }

    Layer {
        id: body
        source: "assets/cobra-body.svg"
        transformOrigin: Item.Bottom
        // 1.00 -> 1.03 -> 1.00 every 4 s
        scale: 1 + 0.015 * (1 - Math.cos(2 * Math.PI * root.t / 4000))
    }

    // Head, hood markings and tongue sway together around the neck point (33, 34).
    Item {
        id: head
        anchors.fill: parent

        // -4 deg <-> +4 deg every 6 s
        transform: Rotation {
            origin.x: 33 * root.unit
            origin.y: 34 * root.unit
            angle: 4 * Math.sin(2 * Math.PI * root.t / 6000)
        }

        // Drawn under the head so it hides when pulled back in.
        Layer {
            id: tongue
            source: "assets/cobra-tongue.svg"
            tint: Theme.tertiary
            anchors.fill: undefined
            width: parent.width
            height: parent.height
            // out and back in over the 300 ms before each flick time
            x: -9 * root.unit * (1 - Math.sin(Math.PI * root.flickPhase))
        }

        Layer {
            source: "assets/cobra-head.svg"
        }

        Layer {
            source: "assets/cobra-marks.svg"
            tint: Theme.tertiary
        }
    }
}
