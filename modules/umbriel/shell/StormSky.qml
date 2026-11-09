// The stormy ruins: the whole picture drifts and breathes in scale very
// slowly (40 s each way), and now and then (8–20 s, random) a faint flash of
// distant lightning brightens the sky top-right (walls.json `flash`).
// `time` comes from Background's clock; nothing moves while `paused`.
// The real weather (Weather.scene, via Background) lays rain over it when
// it rains (`rain`, leaning by `slant`), and makes lightning more or less
// frequent (`flashRate`, 1 = as above).
import QtQuick
import QtQuick.Shapes

Item {
    id: storm

    property url source
    property var flash
    property real time: 0
    property bool paused: false
    property real fallen: time
    property real rain: 0
    property real slant: 0
    property real fall: 1
    property real flashRate: 1

    // 0 → 1 → 0 over 80 s, eased at both ends.
    readonly property real drift: 0.5 - 0.5 * Math.cos(time * 2 * Math.PI / 80)

    anchors.fill: parent

    Image {
        anchors.fill: parent
        source: storm.source
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.round(parent.width * 1.08), Math.round(parent.height * 1.08))
        asynchronous: true
        smooth: true
        // Scaled up 3–6% about the centre, so the small shift never shows an edge.
        transform: [
            Scale {
                origin.x: storm.width / 2
                origin.y: storm.height / 2
                xScale: 1.03 + 0.03 * storm.drift
                yScale: xScale
            },
            Translate {
                x: -12 + 24 * storm.drift
                y: 6 - 12 * storm.drift
            }
        ]
    }

    // Rain over the whole sky, only while it rains for real.
    Loader {
        anchors.fill: parent
        active: storm.rain > 0.02
        sourceComponent: RainFrame {
            rect: ({ x: 0, y: 0, w: 1, h: 1 })
            glow: ({ x: 0.5, y: 0.5, r: 0.1 })
            time: storm.time
            fallen: storm.fallen
            amount: storm.rain
            slant: storm.slant
            fall: storm.fall
            mist: 0
        }
    }

    Shape {
        id: bolt
        anchors.fill: parent
        opacity: 0
        visible: opacity > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: storm.flash.x * storm.width
                centerY: storm.flash.y * storm.height
                centerRadius: storm.flash.r * storm.width
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0; color: Qt.rgba(0.933, 0.945, 0.961, 0.26) }
                GradientStop { position: 0.45; color: Qt.rgba(0.933, 0.945, 0.961, 0.08) }
                GradientStop { position: 1; color: "transparent" }
            }
            PathRectangle {
                width: storm.width
                height: storm.height
            }
        }
    }

    // A double flicker, then a slow fade.
    SequentialAnimation {
        id: strike
        NumberAnimation { target: bolt; property: "opacity"; to: 1; duration: 60 }
        NumberAnimation { target: bolt; property: "opacity"; to: 0.3; duration: 110 }
        NumberAnimation { target: bolt; property: "opacity"; to: 0.85; duration: 70 }
        NumberAnimation { target: bolt; property: "opacity"; to: 0; duration: 900; easing.type: Easing.OutQuad }
    }

    Timer {
        running: !storm.paused
        repeat: true
        interval: (8000 + Math.random() * 12000) / Math.max(storm.flashRate, 0.1)
        onTriggered: {
            strike.restart();
            interval = (8000 + Math.random() * 12000) / Math.max(storm.flashRate, 0.1);
        }
    }
}
