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
    readonly property real breath: 1 + 0.025 * Math.sin(2 * Math.PI * t / 5000)
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
    // moving one pattern length over a second.
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
    // It turns toward the widget under the pointer, at most 35 deg off its rest.
    readonly property real restAngle: geo.head.angle
    property real headAngle: restAngle
    readonly property real targetAngle: {
        if (isNaN(hoverX))
            return restAngle;
        const h = geo.head;
        const a = Math.atan2(pill.height / 2 - h.y, hoverX - h.x) * 180 / Math.PI;
        let d = a - restAngle;
        d = ((d + 540) % 360) - 180;
        return restAngle + Math.max(-35, Math.min(35, d));
    }

    Item {
        visible: root.side === "front"
        x: root.geo.head.x - root.box.x
        y: root.geo.head.y - root.box.y
        rotation: root.headAngle
        scale: 1.4
        transformOrigin: Item.TopLeft

        Shape {
            id: tongue
            visible: root.flickPhase > 0
            transform: Scale { origin.x: 17; xScale: root.flickPhase }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.tertiary
                strokeWidth: 1.2
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 16 0 L 24 0 M 24 0 L 28 -2.5 M 24 0 L 28 2.5" }
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
            ShapePath {
                fillColor: Theme.tertiary
                strokeColor: "transparent"
                PathSvg { path: "M 9 -4.6 a 1.4 1.4 0 1 0 2.8 0 a 1.4 1.4 0 1 0 -2.8 0 M 9 4.6 a 1.4 1.4 0 1 0 2.8 0 a 1.4 1.4 0 1 0 -2.8 0" }
            }
        }
    }

    // Tongue: out and back over 300 ms, every 8-15 s.
    property real nextFlick: 8000
    readonly property real flickPhase: {
        const p = (t - nextFlick) / 300;
        return p > 0 && p < 1 ? Math.sin(Math.PI * p) : 0;
    }

    property real slideFrom: 0
    property real nextSlide: 20000 + Math.random() * 20000

    // One 25 fps tick drives everything, in the front instance only; the back
    // one binds t and slide from it. Stops while the bar is hidden.
    Timer {
        running: root.running && root.side === "front"
        repeat: true
        interval: 40
        onTriggered: {
            root.t += interval;
            if (root.t > root.nextFlick + 300)
                root.nextFlick = root.t + 8000 + Math.random() * 7000;
            const p = (root.t - root.nextSlide) / 1000;
            if (p >= 1) {
                root.slideFrom += root.period;
                root.slide = root.slideFrom;
                root.nextSlide = root.t + 20000 + Math.random() * 20000;
            } else if (p > 0) {
                root.slide = root.slideFrom + root.period * (1 - Math.cos(Math.PI * p)) / 2;
            }
            root.headAngle += (root.targetAngle - root.headAngle) * 0.25;
        }
    }
}
