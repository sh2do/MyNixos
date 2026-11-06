// The reticulated python wrapped around the bottom bar pill. BottomBar places
// two of these: side "back" under the pill (masked out wherever the pill
// covers it) and side "front" over it (only the crossings, plus the head).
// Geometry comes from python-geometry.js; colours from the wallpaper (Theme).
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "python-geometry.js" as Geo

Item {
    id: root

    required property Item pill
    property var gaps: []
    property string side: "back"
    property bool running: false
    // Animation clock in ms; driven by the front instance, bound into the back one.
    property real t: 0
    // Pointer x in pill coordinates, or NaN when it isn't over the pill.
    property real hoverX: NaN

    readonly property int bodyW: Math.round(Theme.barHeight * 0.4)
    readonly property var geo: Geo.layout(pill.width, pill.height, gaps, bodyW)
    // Breathing: the coils loosen and tighten a little every 5 s. A scale of
    // the finished image, so the body isn't redrawn every tick.
    readonly property real breath: 1 + 0.025 * Math.sin(2 * Math.PI * t / 5000) - 0.04 * squeeze
    readonly property var box: geo.bounds

    // The python's own frame is the pill's, shifted so the bounds start at 0, 0.
    x: pill.x + box.x
    y: pill.y + box.y
    width: box.w
    height: box.h
    opacity: pill.opacity

    readonly property string svgPath: {
        let d = "";
        for (const s of geo.path) {
            if (d === "")
                d = `M ${s.x0 - box.x} ${s.y0 - box.y}`;
            d += ` C ${s.c1x - box.x} ${s.c1y - box.y} ${s.c2x - box.x} ${s.c2y - box.y} ${s.x1 - box.x} ${s.y1 - box.y}`;
        }
        return d;
    }

    // The reticulated pattern: three dark-outlined saddles of uneven length,
    // with light flecks in the gaps between them, repeating every `period` px.
    // Values are in body widths. Uneven saddles read as a net, not a chain.
    readonly property var saddles: [[0, 0.75], [1.2, 1.75], [2.35, 3.25]]
    readonly property var flecks: [[0.93, 1.03], [1.92, 2.0], [2.12, 2.2], [3.38, 3.48]]
    readonly property real period: 3.6 * bodyW
    // Px the pattern has crept along the body: every 20-40 s it shifts its grip,
    // moving one pattern length over 1.4 s while the coils squeeze.
    property real slide: 0

    // dashPattern for spans (in body widths, shrunk by `inset` px at each end)
    // on a stroke `w` px wide.
    function pattern(spans, inset, w) {
        const out = [];
        for (let i = 0; i < spans.length; i++) {
            const a = spans[i][0] * bodyW + inset, b = spans[i][1] * bodyW - inset;
            const next = (i + 1 < spans.length ? spans[i + 1][0] * bodyW : period + spans[0][0] * bodyW) + inset;
            out.push((b - a) / w, (next - b) / w);
        }
        return out;
    }
    // dashOffset that starts the first span at its place, for a stroke `w` wide.
    function offsetFor(spans, inset, w) {
        const p = period, at = spans[0][0] * bodyW + inset;
        return ((((p - at - slide) % p) + p) % p) / w;
    }

    component Stroke: ShapePath {
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: root.svgPath }
    }

    // All the body strokes, drawn once into a texture and shown through masks.
    Item {
        id: art
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.samples: 4

        Shape {
            anchors.fill: parent

            Stroke { strokeColor: Theme.surface; strokeWidth: root.bodyW + 3 }
            Stroke { strokeColor: Theme.surfaceContainer; strokeWidth: root.bodyW }
            // Saddle outlines, then the saddles inside them: the net.
            Stroke {
                readonly property real w: root.bodyW - 3
                strokeColor: Theme.surface
                strokeWidth: w
                capStyle: ShapePath.FlatCap
                strokeStyle: ShapePath.DashLine
                dashPattern: root.pattern(root.saddles, 0, w)
                dashOffset: root.offsetFor(root.saddles, 0, w)
            }
            Stroke {
                readonly property real w: root.bodyW - 7
                strokeColor: Theme.primaryContainer
                strokeWidth: w
                capStyle: ShapePath.FlatCap
                strokeStyle: ShapePath.DashLine
                dashPattern: root.pattern(root.saddles, 2, w)
                dashOffset: root.offsetFor(root.saddles, 2, w)
            }
            // Light flecks between the saddles.
            Stroke {
                readonly property real w: 3.5
                strokeColor: Theme.tertiary
                strokeWidth: w
                strokeStyle: ShapePath.DashLine
                dashPattern: root.pattern(root.flecks, 0, w)
                dashOffset: root.offsetFor(root.flecks, 0, w)
            }
        }

        // A faint sheen along the top of the body.
        Shape {
            y: -3
            width: parent.width
            height: parent.height
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(1, 1, 1, 0.12)
                strokeWidth: 2
                capStyle: ShapePath.RoundCap
                PathSvg { path: root.svgPath }
            }
        }

        // Tapered tail tip: the path starts heading right, so the tip points left.
        Shape {
            readonly property var s: root.geo.path[0]
            x: s.x0 - root.box.x
            y: s.y0 - root.box.y
            ShapePath {
                fillColor: Theme.surfaceContainer
                strokeColor: Theme.surface
                strokeWidth: 1.5
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: `M 1 ${-root.bodyW / 2} L ${-root.bodyW * 1.3} 2 L 1 ${root.bodyW / 2}` }
            }
        }
    }

    // Back: everything except where the pill covers it.
    Item {
        id: pillMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Rectangle {
            x: -root.box.x
            y: -root.box.y
            width: root.pill.width
            height: root.pill.height
            radius: root.pill.radius
        }
    }

    // Front: only the crossings, and only over the pill (outside it the back layer shows).
    Item {
        id: crossingMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Repeater {
            model: root.geo.crossings
            Rectangle {
                required property var modelData
                x: modelData.x0 - root.box.x
                y: -root.box.y
                width: modelData.x1 - modelData.x0
                height: root.pill.height
            }
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: art
        maskEnabled: true
        maskSource: root.side === "back" ? pillMask : crossingMask
        maskInverted: root.side === "back"
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        transform: Scale {
            origin.y: root.pill.height / 2 - root.box.y
            yScale: root.breath
        }
    }

    // The head, front layer only: a long wedge with a dark crown line, small
    // eyes and a forked tongue. Drawn pointing +x, then turned.
    //
    // Motion comes in two speeds. Anything that moves the body (breathing, the
    // grip shift) and the head's slow sway and bob follow `t`, ticked at 30 fps:
    // redrawing the dashed body is the expensive part. The head's quick moves
    // (turning, waking, probing, tongue flicks) are Qt animations of small
    // shapes, which run at the display's refresh rate only while moving.

    // It leans along the bar toward the widget under the pointer; otherwise it
    // now and then looks around.
    readonly property real restAngle: geo.head.angle
    property real idleLook: 0
    readonly property real aim: isNaN(hoverX) ? restAngle + idleLook : Geo.headAim(restAngle, hoverX, pill.width)
    property real headAngle: aim
    Behavior on headAngle {
        SpringAnimation { spring: 2.4; damping: 0.3; epsilon: 0.05 }
    }

    // 0 = tucked in, 1 = raised. It rises with a small overshoot when the bar appears.
    property real lift: 0
    // A short forward jab when the pointer arrives, as if tasting the air.
    property real probe: 0
    // Coils tighten while the snake shifts its grip.
    property real squeeze: 0
    // Tongue: how far out, and how far the fork tips spread.
    property real tongueOut: 0
    property real fork: 0

    onRunningChanged: {
        if (side !== "front")
            return;
        if (running) {
            wake.restart();
        } else {
            wake.stop();
            lift = 0;
        }
    }
    onHoverXChanged: {
        const arrived = !isNaN(hoverX) && !hovering;
        hovering = !isNaN(hoverX);
        if (arrived && running && side === "front") {
            probeAnim.restart();
            if (Math.random() < 0.5)
                flickBurst(1 + Math.round(Math.random()));
        }
    }
    property bool hovering: false

    function flickBurst(n) {
        if (flick.running)
            return;
        flick.loops = n;
        flick.restart();
    }

    SequentialAnimation {
        id: wake
        PauseAnimation { duration: 160 }
        NumberAnimation { target: root; property: "lift"; from: 0; to: 1; duration: 560; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
    }

    SequentialAnimation {
        id: probeAnim
        NumberAnimation { target: root; property: "probe"; to: 1; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "probe"; to: 0; duration: 320; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: flick
        NumberAnimation { target: root; property: "tongueOut"; from: 0; to: 1; duration: 85; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "fork"; from: 0.2; to: 1; duration: 55 }
        NumberAnimation { target: root; property: "fork"; to: 0.35; duration: 55 }
        NumberAnimation { target: root; property: "fork"; to: 1; duration: 55 }
        NumberAnimation { target: root; property: "tongueOut"; to: 0; duration: 95; easing.type: Easing.InQuad }
        PauseAnimation { duration: 70 }
    }

    Item {
        visible: root.side === "front"
        // Slow sway and a bob in time with the breathing.
        readonly property real sway: 2.5 * Math.sin(2 * Math.PI * root.t / 1900) + 1.2 * Math.sin(2 * Math.PI * root.t / 730)
        readonly property real bob: 1.2 * Math.sin(2 * Math.PI * root.t / 5000 + 0.6)
        // Tucked back along its own axis until it rises; the probe pushes it forward.
        readonly property real reach: -9 * (1 - root.lift) + 4 * root.probe
        readonly property real dir: (root.headAngle + sway) * Math.PI / 180

        x: root.geo.head.x - root.box.x + reach * Math.cos(dir)
        y: root.geo.head.y - root.box.y + reach * Math.sin(dir) + bob
        rotation: root.headAngle + sway
        scale: 1.4 * (0.78 + 0.22 * root.lift)
        transformOrigin: Item.TopLeft

        Shape {
            id: tongue
            visible: root.tongueOut > 0.01
            preferredRendererType: Shape.CurveRenderer
            readonly property real tip: 16 + 8 * root.tongueOut
            readonly property real len: 4.5 * root.tongueOut
            readonly property real spread: (14 + 22 * root.fork) * Math.PI / 180
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.tertiary
                strokeWidth: 1.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: {
                        const t = tongue, ex = t.len * Math.cos(t.spread), ey = t.len * Math.sin(t.spread);
                        return `M 16 0 L ${t.tip} 0 L ${t.tip + ex} ${-ey} M ${t.tip} 0 L ${t.tip + ex} ${ey}`;
                    }
                }
            }
        }

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.secondary
                strokeColor: Theme.surface
                strokeWidth: 1.4
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M -4 -5.5 C 2 -7.5 8 -7.5 12 -5 Q 17 -3 17 0 Q 17 3 12 5 C 8 7.5 2 7.5 -4 5.5 Z" }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.surface
                strokeWidth: 1.2
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M -2 0 L 14 0" }
            }
            // The dark stripe behind each eye, and the nostrils.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(Theme.surface, 0.85)
                strokeWidth: 1
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 9 -4.4 L 0 -5.4 M 9 4.4 L 0 5.4 M 15.2 -1.6 L 15.6 -1.4 M 15.2 1.6 L 15.6 1.4" }
            }
            ShapePath {
                fillColor: Theme.tertiary
                strokeColor: "transparent"
                PathSvg { path: "M 9 -4.6 a 1.4 1.4 0 1 0 2.8 0 a 1.4 1.4 0 1 0 -2.8 0 M 9 4.6 a 1.4 1.4 0 1 0 2.8 0 a 1.4 1.4 0 1 0 -2.8 0" }
            }
        }
    }

    property real nextFlick: 6000
    property real nextSlide: 20000 + Math.random() * 20000
    property real slideFrom: 0
    property real nextLook: 5000
    property real lookUntil: 0

    // The slow tick, in the front instance only; the back one binds t, slide
    // and squeeze from it. It also schedules the quick events. Stops while the
    // bar is hidden.
    Timer {
        running: root.running && root.side === "front"
        repeat: true
        interval: 33
        onTriggered: {
            const t = root.t += interval;
            if (t > root.nextFlick) {
                root.flickBurst(2 + Math.round(Math.random()));
                root.nextFlick = t + 8000 + Math.random() * 7000;
            }
            const p = (t - root.nextSlide) / 1400;
            if (p >= 1) {
                root.slideFrom += root.period;
                root.slide = root.slideFrom;
                root.squeeze = 0;
                root.nextSlide = t + 20000 + Math.random() * 20000;
            } else if (p > 0) {
                root.slide = root.slideFrom + root.period * (1 - Math.cos(Math.PI * p)) / 2;
                root.squeeze = Math.sin(Math.PI * Math.min(1, p < 0.36 ? p / 0.72 : 0.5 + (p - 0.36) / 1.28));
            }
            if (root.idleLook !== 0 && t > root.lookUntil)
                root.idleLook = 0;
            if (t > root.nextLook) {
                root.idleLook = Math.random() < 0.5 ? -(10 + Math.random() * 14) : 8 + Math.random() * 12;
                root.lookUntil = t + 1200 + Math.random() * 1500;
                root.nextLook = t + 6000 + Math.random() * 6000;
            }
        }
    }
}
