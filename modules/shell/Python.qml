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
    readonly property real breath: 1 + 0.025 * Math.sin(2 * Math.PI * t / 5000) - 0.04 * squeeze - 0.05 * flinch
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
            readonly property var saddles: Geo.blotches(root.spine, root.bodyW, root.slide)
            readonly property var spots: Geo.flecks(root.spine, root.bodyW, root.slide)

            Item {
                id: art
                anchors.fill: parent

                // A soft shadow, baked into the texture so it costs nothing per
                // tick: on the pill under the front crossings, on the wallpaper
                // under the rest.
                Item {
                    x: 1
                    y: 2.5
                    width: parent.width
                    height: parent.height
                    opacity: 0.5
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 0.35
                        blurMax: 12
                    }
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        Fill {
                            fillColor: "black"
                            PathSvg { path: Geo.outlineSvg(root.spine, root.bodyW, root.box.x, root.box.y) }
                        }
                    }
                }

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
                    // The dark line down the spine that links the saddles into a net.
                    Line {
                        strokeColor: Qt.alpha(Theme.surface, 0.7)
                        strokeWidth: root.bodyW * 0.09
                        PathSvg { path: Geo.edgeSvg(root.spine, root.bodyW, 0, root.box.x, root.box.y) }
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
                        // Saddles: dark-edged diamonds with a paler heart.
                        Fill {
                            fillColor: Theme.primaryContainer
                            strokeColor: Theme.surface
                            strokeWidth: 1.6
                            PathSvg { path: Geo.polysSvg(skinItem.saddles, root.box.x, root.box.y) }
                        }
                        Fill {
                            fillColor: Qt.lighter(Theme.primaryContainer, 1.3)
                            PathSvg { path: Geo.polysSvg(Geo.shrink(skinItem.saddles, 0.45), root.box.x, root.box.y) }
                        }
                        // Eyespots: a dark ring around a pale centre.
                        Fill {
                            fillColor: Theme.surface
                            PathSvg { path: Geo.dotsSvg(skinItem.spots, root.box.x, root.box.y) }
                        }
                        Fill {
                            fillColor: Theme.tertiary
                            PathSvg { path: Geo.dotsSvg(skinItem.spots, root.box.x, root.box.y, 0.5) }
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

    // The head and neck, front layer only. The head is a broad, flat wedge in
    // the saddle colour: dark midline and eye stripes, pale barred lips with
    // heat pits, amber eyes with slit pupils, and a forked tongue, sized from
    // the body. Drawn pointing +x from the neck joint, then turned; the neck is
    // redrawn to meet it.
    //
    // Motion comes in two speeds. The slow, small motions (breathing, the grip
    // shift, the head's sway and bob) follow `t`, ticked every 21 ms: every
    // third frame at 144 Hz, so the steps stay even, and each is under a pixel.
    // A per-frame clock keeps the bar redrawing at the full refresh rate and
    // costs several times the CPU. The quick moves (turning, waking, probing,
    // flinching, tongue flicks) are Qt animations, which run every frame while
    // they last.

    // Where it looks, most urgent first: something that just changed on the bar
    // (notice), the widget under the pointer, then now and then around.
    readonly property real restAngle: geo.head.angle
    property real idleLook: 0
    property real noticeX: NaN
    readonly property real lookX: !isNaN(noticeX) ? noticeX : hoverX
    readonly property real aim: isNaN(lookX) ? restAngle + idleLook : Geo.headAim(restAngle, geo.head, lookX, pill.height)
    property real headAngle: aim
    Behavior on headAngle {
        SpringAnimation { spring: 2.2; damping: 0.32; epsilon: 0.05 }
    }

    // 0 = resting, head down on the coils; 1 = raised.
    property real lift: 0
    // A short forward jab when the pointer arrives, as if tasting the air.
    property real probe: 0
    // Leaning in while the pointer is over the bar.
    property real attention: hovering ? 1 : 0
    Behavior on attention {
        NumberAnimation { duration: 450; easing.type: Easing.InOutSine }
    }
    // Coils tighten while the snake shifts its grip, and flinch when something
    // on the bar changes.
    property real squeeze: 0
    property real flinch: 0
    // Tongue: how far out, and how far the fork tips spread.
    property real tongueOut: 0
    property real fork: 0

    // Something changed at x on the bar (pill coordinates): look at it, flinch,
    // taste the air.
    function notice(x) {
        if (!running || side !== "front")
            return;
        noticeX = x;
        noticeTimer.restart();
        flinchAnim.restart();
        flickBurst(1);
    }
    Timer {
        id: noticeTimer
        interval: 1600
        onTriggered: root.noticeX = NaN
    }

    // Hidden for a while, it has settled: it wakes slowly, lifting, looking
    // along the bar and tasting the air. Back soon, it just pops up.
    property real hiddenAt: 0
    onRunningChanged: {
        if (side !== "front")
            return;
        if (running) {
            if (Date.now() - hiddenAt > 180000)
                slowWake.restart();
            else
                wake.restart();
        } else {
            wake.stop();
            slowWake.stop();
            lift = 0;
            hiddenAt = Date.now();
        }
    }
    onHoverXChanged: {
        const arrived = !isNaN(hoverX) && !hovering;
        hovering = !isNaN(hoverX);
        if (arrived && running && side === "front" && !slowWake.running) {
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
        id: slowWake
        PauseAnimation { duration: 450 }
        NumberAnimation { target: root; property: "lift"; from: 0; to: 1; duration: 1400; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "idleLook"; to: -22; duration: 700; easing.type: Easing.InOutSine }
        ScriptAction { script: root.flickBurst(2) }
        NumberAnimation { target: root; property: "idleLook"; to: 10; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "idleLook"; to: 0; duration: 600; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: probeAnim
        NumberAnimation { target: root; property: "probe"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "probe"; to: 0; duration: 420; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: flinchAnim
        NumberAnimation { target: root; property: "flinch"; to: 1; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "flinch"; to: 0; duration: 650; easing.type: Easing.OutElastic; easing.amplitude: 1; easing.period: 0.5 }
    }

    // Real tongues flutter: a fast flicker of the tips inside a slower in and out,
    // sagging a little at full reach.
    SequentialAnimation {
        id: flick
        NumberAnimation { target: root; property: "tongueOut"; from: 0; to: 1; duration: 90; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "fork"; from: 0.2; to: 1; duration: 45; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "fork"; to: 0.3; duration: 45; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "fork"; to: 1; duration: 45; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "fork"; to: 0.4; duration: 45; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "fork"; to: 1; duration: 45; easing.type: Easing.InOutSine }
        NumberAnimation { target: root; property: "tongueOut"; to: 0; duration: 110; easing.type: Easing.InQuad }
        PauseAnimation { duration: 80 }
    }

    // The head's pose, in this item's frame. The neck follows the main pose
    // (turning, lifting, leaning, flinching), so it's only rebuilt while the
    // head really moves; the slow sway, bob and breathing ride on the head
    // alone (under 2 px, hidden by the neck joint).
    readonly property real poseDir: headAngle * Math.PI / 180
    // Out along its axis: tucked back at rest, forward for the probe and while
    // the pointer is over the bar, jerked back by a flinch.
    readonly property real headReach: bodyW * (-0.5 * (1 - lift) + 0.25 * probe + 0.12 * attention - 0.2 * flinch)
    readonly property real poseX: geo.head.x - box.x + headReach * Math.cos(poseDir)
    readonly property real poseY: geo.head.y - box.y + headReach * Math.sin(poseDir) + 0.5 * bodyW * (1 - lift)
    // Sampled on the slow tick (and on layout changes), not every frame: a turn
    // runs at the full refresh rate and rebuilding the neck that often is the
    // costliest thing here. The joint hides the lag.
    property var neckPose: ({ x: poseX, y: poseY, angle: headAngle })
    function updateNeck() {
        const p = neckPose;
        if (Math.abs(p.x - poseX) + Math.abs(p.y - poseY) > 0.2 || Math.abs(p.angle - headAngle) > 0.2)
            neckPose = { x: poseX, y: poseY, angle: headAngle };
    }
    onGeoChanged: neckPose = { x: poseX, y: poseY, angle: headAngle }
    readonly property var neckShape: side !== "front" ? ({ fill: "", edges: "", spine: "", belly: "", sheen: "" })
        : Geo.neckSvg(Geo.neckSegment({ x: geo.neck.x - box.x, y: geo.neck.y - box.y }, neckPose, neckPose.angle, bodyW), bodyW, 0, 0)

    readonly property real headRot: headAngle + 2.5 * Math.sin(2 * Math.PI * t / 2300) + 1 * Math.sin(2 * Math.PI * t / 890)
    readonly property real breathOriginY: pill.height / 2 - box.y
    readonly property real headX: poseX
    readonly property real headY: poseY + (geo.head.y - box.y - breathOriginY) * (breath - 1)
        + 0.06 * bodyW * Math.sin(2 * Math.PI * t / 5000 + 0.6)

    // An offset copy under the neck and head, matching the body's shadow. Not
    // blurred: a blurred layer would be redrawn on every tick as the head sways.
    Item {
        visible: root.side === "front"
        anchors.fill: parent
        opacity: 0.3

        Shape {
            x: 1
            y: 2.5
            preferredRendererType: Shape.CurveRenderer
            Fill {
                fillColor: "black"
                PathSvg { path: root.neckShape.fill }
            }
        }
        Item {
            x: root.headX + 1
            y: root.headY + 2.5
            rotation: root.headRot
            scale: 0.88 + 0.12 * root.lift
            transformOrigin: Item.TopLeft
            Shape {
                preferredRendererType: Shape.CurveRenderer
                Fill {
                    fillColor: "black"
                    PathSvg { path: head.outline }
                }
            }
        }
    }

    Shape {
        visible: root.side === "front"
        preferredRendererType: Shape.CurveRenderer
        Fill {
            fillColor: Theme.surfaceContainer
            PathSvg { path: root.neckShape.fill }
        }
        Line {
            strokeColor: Qt.alpha(Theme.surface, 0.35)
            strokeWidth: root.bodyW * 0.22
            PathSvg { path: root.neckShape.belly }
        }
        Line {
            strokeColor: Qt.rgba(1, 1, 1, 0.1)
            strokeWidth: root.bodyW * 0.12
            PathSvg { path: root.neckShape.sheen }
        }
        Line {
            strokeColor: Qt.alpha(Theme.surface, 0.7)
            strokeWidth: root.bodyW * 0.09
            PathSvg { path: root.neckShape.spine }
        }
        Line {
            strokeColor: Theme.surface
            strokeWidth: 1.6
            PathSvg { path: root.neckShape.edges }
        }
    }

    Item {
        id: head
        visible: root.side === "front"
        readonly property real b: root.bodyW

        x: root.headX
        y: root.headY
        rotation: root.headRot
        scale: 0.88 + 0.12 * root.lift
        transformOrigin: Item.TopLeft

        // Circles at points given in body widths, as SVG.
        function dots(pts, r) {
            const R = r * b;
            return pts.map(p => `M ${p[0] * b - R} ${p[1] * b} a ${R} ${R} 0 1 0 ${2 * R} 0 a ${R} ${R} 0 1 0 ${-2 * R} 0`).join(" ");
        }
        // Ellipses (slit pupils), rx by ry body widths.
        function slits(pts, rx, ry) {
            const X = rx * b, Y = ry * b;
            return pts.map(p => `M ${p[0] * b - X} ${p[1] * b} a ${X} ${Y} 0 1 0 ${2 * X} 0 a ${X} ${Y} 0 1 0 ${-2 * X} 0`).join(" ");
        }
        // Wide at the jaw, a slight brow over each eye, narrowing to the snout.
        readonly property string outline: {
            return `M ${-0.2 * b} ${-0.36 * b} C ${0.05 * b} ${-0.7 * b} ${0.35 * b} ${-0.8 * b} ${0.7 * b} ${-0.78 * b}`
                + ` C ${1.15 * b} ${-0.74 * b} ${1.45 * b} ${-0.66 * b} ${1.6 * b} ${-0.6 * b}`
                + ` C ${1.95 * b} ${-0.46 * b} ${2.2 * b} ${-0.3 * b} ${2.32 * b} ${-0.2 * b}`
                + ` Q ${2.46 * b} ${-0.08 * b} ${2.46 * b} 0 Q ${2.46 * b} ${0.08 * b} ${2.32 * b} ${0.2 * b}`
                + ` C ${2.2 * b} ${0.3 * b} ${1.95 * b} ${0.46 * b} ${1.6 * b} ${0.6 * b}`
                + ` C ${1.45 * b} ${0.66 * b} ${1.15 * b} ${0.74 * b} ${0.7 * b} ${0.78 * b}`
                + ` C ${0.35 * b} ${0.8 * b} ${0.05 * b} ${0.7 * b} ${-0.2 * b} ${0.36 * b} Z`;
        }

        Shape {
            id: tongue
            visible: root.tongueOut > 0.01
            preferredRendererType: Shape.CurveRenderer
            readonly property real base: 2.42 * head.b
            readonly property real tip: base + 0.75 * head.b * root.tongueOut
            readonly property real sag: 0.08 * head.b * root.tongueOut
            readonly property real len: 0.3 * head.b * root.tongueOut
            readonly property real spread: (12 + 26 * root.fork) * Math.PI / 180
            Line {
                strokeColor: Theme.tertiary
                strokeWidth: Math.max(1.1, 0.07 * head.b)
                PathSvg {
                    path: {
                        const t = tongue, ex = t.len * Math.cos(t.spread), ey = t.len * Math.sin(t.spread);
                        return `M ${t.base} 0 Q ${(t.base + t.tip) / 2} ${t.sag * 1.6} ${t.tip} ${t.sag}`
                            + ` L ${t.tip + ex} ${t.sag - ey} M ${t.tip} ${t.sag} L ${t.tip + ex} ${t.sag + ey}`;
                    }
                }
            }
        }

        Shape {
            preferredRendererType: Shape.CurveRenderer
            // Neck joint: covers the seam with the neck as the head turns.
            Fill {
                fillColor: Theme.surfaceContainer
                PathSvg { path: head.dots([[0, 0]], 0.36) }
            }
            Fill {
                fillColor: Theme.primaryContainer
                strokeColor: Theme.surface
                strokeWidth: 1.5
                PathSvg { path: head.outline }
            }
            // Pale lips along the snout's edges, barred dark, with heat pits.
            Line {
                strokeColor: Qt.lighter(Theme.primaryContainer, 1.4)
                strokeWidth: 0.12 * head.b
                PathSvg {
                    path: {
                        const b = head.b;
                        return `M ${1.0 * b} ${-0.66 * b} C ${1.5 * b} ${-0.56 * b} ${1.95 * b} ${-0.38 * b} ${2.28 * b} ${-0.14 * b}`
                            + ` M ${1.0 * b} ${0.66 * b} C ${1.5 * b} ${0.56 * b} ${1.95 * b} ${0.38 * b} ${2.28 * b} ${0.14 * b}`;
                    }
                }
            }
            Line {
                strokeColor: Qt.alpha(Theme.surface, 0.8)
                strokeWidth: Math.max(0.8, 0.05 * head.b)
                PathSvg {
                    path: {
                        const b = head.b;
                        return [[1.2, 0.63], [1.55, 0.53], [1.9, 0.38], [2.15, 0.22]].map(p =>
                            `M ${p[0] * b} ${-(p[1] + 0.07) * b} L ${(p[0] + 0.03) * b} ${-(p[1] - 0.07) * b}`
                            + ` M ${p[0] * b} ${(p[1] + 0.07) * b} L ${(p[0] + 0.03) * b} ${(p[1] - 0.07) * b}`).join(" ");
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
            // Amber eyes with slit pupils, then the nostrils.
            Fill {
                fillColor: Qt.tint(Theme.tertiary, Qt.rgba(0.85, 0.55, 0.15, 0.6))
                strokeColor: Theme.surface
                strokeWidth: 1
                PathSvg { path: head.dots([[1.55, -0.38], [1.55, 0.38]], 0.14) }
            }
            Fill {
                fillColor: Theme.surface
                PathSvg { path: head.slits([[1.56, -0.38], [1.56, 0.38]], 0.11, 0.035) + " " + head.dots([[2.32, -0.12], [2.32, 0.12]], 0.04) }
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
            root.updateNeck();
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
            if (slowWake.running)
                return;
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
