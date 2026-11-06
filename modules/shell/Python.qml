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

    readonly property int bodyW: Math.round(Theme.barHeight * 0.5)
    readonly property var geo: Geo.layout(pill.width, pill.height, gaps, bodyW)
    // Breathing: the coils loosen and tighten a little every 5 s. A scale of
    // the finished image, so the body isn't redrawn for it.
    readonly property real breath: 1 + 0.025 * Math.sin(2 * Math.PI * t / 5000) - 0.04 * squeeze
    readonly property var box: geo.bounds

    // The python's own frame is the pill's, shifted so the bounds start at 0, 0.
    x: pill.x + box.x
    y: pill.y + box.y
    width: box.w
    height: box.h
    opacity: pill.opacity

    // The spine, sampled every 2 px; the skin is built around it.
    readonly property var spine: Geo.samples(geo.path, 2)
    // Px the pattern has crept along the body: every 20-40 s it shifts its grip,
    // moving one saddle along over 1.4 s while the coils squeeze.
    property real slide: 0
    readonly property real period: bodyW * 2.4
    // The body texture. The front instance draws it; the back one binds this
    // to the front's, so the body is drawn once and shown through both masks.
    property Item texture: skin.item ? skin.item.texture : null

    component Fill: ShapePath {
        strokeColor: "transparent"
        joinStyle: ShapePath.RoundJoin
    }
    component Line: ShapePath {
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    // The body, drawn into a texture and shown through masks: a tapered
    // outline, a shadow along the belly side, the saddles, flecks and a sheen.
    Loader {
        id: skin
        anchors.fill: parent
        active: root.side === "front"
        sourceComponent: Item {
            id: skinItem
            readonly property Item texture: artTex
            readonly property string saddleSvg: Geo.polysSvg(Geo.blotches(root.spine, root.bodyW, root.slide), root.box.x, root.box.y)
            readonly property string fleckSvg: Geo.dotsSvg(Geo.flecks(root.spine, root.bodyW, root.slide), root.box.x, root.box.y)

            Item {
                id: art
                anchors.fill: parent

                // The outline never changes after layout. The curve renderer picks
                // up colour changes even inside a hidden source; the default one
                // doesn't.
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    Fill {
                        fillColor: Theme.surfaceContainer
                        strokeColor: Theme.surface
                        strokeWidth: 1.6
                        PathSvg { path: Geo.outlineSvg(root.spine, root.bodyW, root.box.x, root.box.y) }
                    }
                    Line {
                        strokeColor: Qt.alpha(Theme.surface, 0.35)
                        strokeWidth: root.bodyW * 0.22
                        PathSvg { path: Geo.edgeSvg(root.spine, root.bodyW, 0.3, root.box.x, root.box.y) }
                    }
                    Line {
                        strokeColor: Qt.rgba(1, 1, 1, 0.1)
                        strokeWidth: root.bodyW * 0.12
                        PathSvg { path: Geo.edgeSvg(root.spine, root.bodyW, -0.26, root.box.x, root.box.y) }
                    }
                }
                // The pattern in its own Shape, so a grip shift only rebuilds this
                // one, with the default renderer: cheaper to rebuild every step.
                // It doesn't pick up colour-only changes inside a hidden source,
                // so it's recreated when the colours change.
                Repeater {
                    model: [Theme.colours]
                    Shape {
                        anchors.fill: parent
                        Fill {
                            fillColor: Theme.primaryContainer
                            strokeColor: Theme.surface
                            strokeWidth: 1.3
                            PathSvg { path: skinItem.saddleSvg }
                        }
                        Fill {
                            fillColor: Theme.tertiary
                            PathSvg { path: skinItem.fleckSvg }
                        }
                    }
                }
            }

            // A hidden source item, multisampled for the pattern's edges.
            ShaderEffectSource {
                id: artTex
                anchors.fill: parent
                sourceItem: art
                hideSource: true
                visible: false
                samples: 4
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
        source: root.texture
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

    // The head, front layer only: a broad, flat wedge in the saddle colour with
    // a dark midline, eye stripes and a forked tongue, sized from the body.
    // Drawn pointing +x from the neck joint, then turned.
    //
    // Motion comes in two speeds. The slow, small motions (breathing, the grip
    // shift, the head's sway and bob) follow `t`, ticked every 21 ms: every
    // third frame at 144 Hz, so the steps stay even, and each is under a pixel.
    // A per-frame clock keeps the bar redrawing at the full refresh rate and
    // costs several times the CPU. The quick moves (turning, waking, probing,
    // tongue flicks) are Qt animations, which run every frame while they last.

    // It looks at the widget under the pointer; otherwise it now and then
    // looks around.
    readonly property real restAngle: geo.head.angle
    property real idleLook: 0
    readonly property real aim: isNaN(hoverX) ? restAngle + idleLook : Geo.headAim(restAngle, geo.head, hoverX, pill.height)
    property real headAngle: aim
    Behavior on headAngle {
        SpringAnimation { spring: 2.2; damping: 0.32; epsilon: 0.05 }
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
        NumberAnimation { target: root; property: "lift"; from: 0; to: 1; duration: 620; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
    }

    SequentialAnimation {
        id: probeAnim
        NumberAnimation { target: root; property: "probe"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "probe"; to: 0; duration: 420; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: flick
        NumberAnimation { target: root; property: "tongueOut"; from: 0; to: 1; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "fork"; from: 0.2; to: 1; duration: 60; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "fork"; to: 0.35; duration: 60; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "fork"; to: 1; duration: 60; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "tongueOut"; to: 0; duration: 110; easing.type: Easing.InQuad }
        PauseAnimation { duration: 80 }
    }

    Item {
        id: head
        visible: root.side === "front"
        readonly property real b: root.bodyW
        // Slow sway and a bob in time with the breathing.
        readonly property real sway: 2.5 * Math.sin(2 * Math.PI * root.t / 2300) + 1 * Math.sin(2 * Math.PI * root.t / 890)
        readonly property real bob: 0.06 * b * Math.sin(2 * Math.PI * root.t / 5000 + 0.6)
        // Tucked back along its own axis until it rises; the probe pushes it forward.
        readonly property real reach: -0.5 * b * (1 - root.lift) + 0.25 * b * root.probe
        readonly property real dir: (root.headAngle + sway) * Math.PI / 180
        // Follow the body's breathing scale, so the neck stays joined.
        readonly property real originY: root.pill.height / 2 - root.box.y
        readonly property real restY: root.geo.head.y - root.box.y

        x: root.geo.head.x - root.box.x + reach * Math.cos(dir)
        y: originY + (restY - originY) * root.breath + reach * Math.sin(dir) + bob
        rotation: root.headAngle + sway
        scale: 0.88 + 0.12 * root.lift
        transformOrigin: Item.TopLeft

        // Circles at points given in body widths, as SVG.
        function dots(pts, r) {
            const R = r * b;
            return pts.map(p => `M ${p[0] * b - R} ${p[1] * b} a ${R} ${R} 0 1 0 ${2 * R} 0 a ${R} ${R} 0 1 0 ${-2 * R} 0`).join(" ");
        }

        Shape {
            id: tongue
            visible: root.tongueOut > 0.01
            preferredRendererType: Shape.CurveRenderer
            readonly property real base: 2.42 * head.b
            readonly property real tip: base + 0.6 * head.b * root.tongueOut
            readonly property real len: 0.28 * head.b * root.tongueOut
            readonly property real spread: (14 + 22 * root.fork) * Math.PI / 180
            Line {
                strokeColor: Theme.tertiary
                strokeWidth: Math.max(1.1, 0.07 * head.b)
                PathSvg {
                    path: {
                        const t = tongue, ex = t.len * Math.cos(t.spread), ey = t.len * Math.sin(t.spread);
                        return `M ${t.base} 0 L ${t.tip} 0 L ${t.tip + ex} ${-ey} M ${t.tip} 0 L ${t.tip + ex} ${ey}`;
                    }
                }
            }
        }

        Shape {
            preferredRendererType: Shape.CurveRenderer
            // Neck joint: covers the seam with the body as the head turns.
            Fill {
                fillColor: Theme.surfaceContainer
                PathSvg { path: head.dots([[0, 0]], 0.36) }
            }
            Fill {
                fillColor: Theme.primaryContainer
                strokeColor: Theme.surface
                strokeWidth: 1.5
                PathSvg {
                    path: {
                        const b = head.b;
                        return `M ${-0.2 * b} ${-0.36 * b} C ${0.05 * b} ${-0.7 * b} ${0.35 * b} ${-0.8 * b} ${0.65 * b} ${-0.78 * b}`
                            + ` C ${1.2 * b} ${-0.72 * b} ${1.95 * b} ${-0.48 * b} ${2.28 * b} ${-0.24 * b}`
                            + ` Q ${2.45 * b} ${-0.1 * b} ${2.45 * b} 0 Q ${2.45 * b} ${0.1 * b} ${2.28 * b} ${0.24 * b}`
                            + ` C ${1.95 * b} ${0.48 * b} ${1.2 * b} ${0.72 * b} ${0.65 * b} ${0.78 * b}`
                            + ` C ${0.35 * b} ${0.8 * b} ${0.05 * b} ${0.7 * b} ${-0.2 * b} ${0.36 * b} Z`;
                    }
                }
            }
            // Midline, and the dark stripe running back from each eye.
            Line {
                strokeColor: Qt.alpha(Theme.surface, 0.85)
                strokeWidth: Math.max(1.2, 0.1 * head.b)
                PathSvg {
                    path: {
                        const b = head.b;
                        return `M ${0.15 * b} 0 L ${2.1 * b} 0`
                            + ` M ${1.5 * b} ${-0.4 * b} Q ${1.0 * b} ${-0.55 * b} ${0.4 * b} ${-0.6 * b}`
                            + ` M ${1.5 * b} ${0.4 * b} Q ${1.0 * b} ${0.55 * b} ${0.4 * b} ${0.6 * b}`;
                    }
                }
            }
            // Eyes, set into the stripes, then pupils and nostrils.
            Fill {
                fillColor: Theme.tertiary
                strokeColor: Theme.surface
                strokeWidth: 1
                PathSvg { path: head.dots([[1.55, -0.38], [1.55, 0.38]], 0.13) }
            }
            Fill {
                fillColor: Theme.surface
                PathSvg { path: head.dots([[1.58, -0.38], [1.58, 0.38]], 0.05) + " " + head.dots([[2.3, -0.13], [2.3, 0.13]], 0.04) }
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
        interval: 21
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
