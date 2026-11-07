// The desert horned viper wound twice around the open launcher (the spec's
// viper-launcher.html, option B), in the slate viper colours. Island places
// two of these around the panel: side "back" under it (the whole body,
// hidden where the panel covers it) and side "front" over it (only the
// crossings, clipped to the gaps the launcher leaves between its rows, plus
// the head). Coordinates are the panel's, 240×320; the body
// reaches outside it.
//
// The body and head are shapes built once. Everything that moves is a
// transform of them: the coil grows out from behind the panel, the head turns,
// draws back and lunges. Nothing runs while hidden.
//
// phase: "hidden" | "entering" | "idle" | "strike". The launcher sets
// entering, strike and hidden; entering turns into idle by itself, and strike
// ends with struck(). The back one binds its phase to the front one's.
import QtQuick
import QtQuick.Shapes
import "." as U

Item {
    id: root

    property string side: "front"
    property string phase: "hidden"
    // Where the strike lands, in panel coordinates.
    property point strikeTarget: Qt.point(0, 0)
    // The two gaps between the launcher's rows that the front crossings use,
    // as [top, bottom] pairs in panel coordinates, upper first.
    property var bands: [[124, 150], [226, 252]]

    signal struck()

    readonly property int panelW: 240
    readonly property int panelH: 320
    readonly property real bodyW: 17
    // The outline's own width each side of the body.
    readonly property real rim: 2

    width: panelW
    height: panelH
    visible: phase !== "hidden"

    // Geometry

    // The spine as cubic segments [p0, c1, c2, p3], tail first: up into the
    // lower front crossing, round the right edge, back across behind the
    // panel, round the left edge, the upper front crossing, then the neck up
    // the right side in a cocked S to the head over the top-right corner. The
    // crossings sit on the bands' centre lines, rising 4 px to the right.
    function spine(W, bands) {
        const a = (bands[0][0] + bands[0][1]) / 2, b = (bands[1][0] + bands[1][1]) / 2;
        const P = (x, y) => ({ x: x, y: y });
        // The back crossing runs from just above the lower band, on the right,
        // to just below the upper one, on the left.
        const gap = bodyW / 2 + rim + 0.5;
        const r = bands[1][0] - gap, l = bands[0][1] + gap;
        return [
            [P(-30, b + 79), P(-28, b + 57), P(-18, b + 2), P(0, b + 2)],
            [P(0, b + 2), P(W / 3, b + 0.7), P(2 * W / 3, b - 0.7), P(W, b - 2)],
            [P(W, b - 2), P(W + 22, b - 2), P(W + 22, r), P(W, r)],
            [P(W, r), P(W - 70, r), P(70, l), P(0, l)],
            [P(0, l), P(-22, l), P(-22, a + 2), P(0, a + 2)],
            [P(0, a + 2), P(W / 3, a + 0.7), P(2 * W / 3, a - 0.7), P(W, a - 2)],
            [P(W, a - 2), P(W + 22, a - 2), P(W + 30, a - 29), P(W + 22, a - 53)],
            [P(W + 22, a - 53), P(W + 14, a - 77), P(W + 10, a - 97), P(W + 22, a - 115)],
            [P(W + 22, a - 115), P(W + 30, a - 127), P(W + 16.7, a - 138), P(W + 8, a - 133)]
        ];
    }

    // Points along the spine every `step` px of arc length, with the tangent.
    function sample(segs, step) {
        const fine = [];
        for (const s of segs) {
            for (let i = fine.length ? 1 : 0; i <= 64; i++) {
                const t = i / 64, u = 1 - t;
                fine.push({
                    x: u * u * u * s[0].x + 3 * u * u * t * s[1].x + 3 * u * t * t * s[2].x + t * t * t * s[3].x,
                    y: u * u * u * s[0].y + 3 * u * u * t * s[1].y + 3 * u * t * t * s[2].y + t * t * t * s[3].y
                });
            }
        }
        const out = [{ x: fine[0].x, y: fine[0].y, s: 0 }];
        let walked = 0, next = step;
        for (let i = 1; i < fine.length; i++) {
            const p = fine[i - 1], q = fine[i];
            const d = Math.hypot(q.x - p.x, q.y - p.y);
            while (walked + d >= next) {
                const f = (next - walked) / d;
                out.push({ x: p.x + f * (q.x - p.x), y: p.y + f * (q.y - p.y), s: next });
                next += step;
            }
            walked += d;
        }
        for (let i = 0; i < out.length; i++) {
            const p = out[Math.max(0, i - 1)], q = out[Math.min(out.length - 1, i + 1)];
            const d = Math.hypot(q.x - p.x, q.y - p.y) || 1;
            out[i].tx = (q.x - p.x) / d;
            out[i].ty = (q.y - p.y) / d;
        }
        return out;
    }

    function f(v) {
        return v.toFixed(2);
    }
    // A point `off` px to the left of the spine at sample p, `along` px on.
    function at(p, off, along) {
        return f(p.x + along * p.tx - off * p.ty) + " " + f(p.y + along * p.ty + off * p.tx);
    }

    readonly property real tailLen: 48
    function halfWidth(s) {
        return bodyW / 2 * Math.min(1, 0.15 + 0.85 * Math.pow(s / tailLen, 0.6));
    }

    readonly property var geo: {
        const pts = sample(spine(panelW, bands), 2);
        const n = pts.length, len = pts[n - 1].s;
        // The stroked body: from where the tail is full width to just under
        // the back of the head.
        const main = [];
        for (const p of pts)
            if (p.s >= tailLen - 2 && p.s <= len - 3)
                main.push((main.length ? "L " : "M ") + f(p.x) + " " + f(p.y));
        // The tail, tapering to a point, as an outline.
        const left = [], right = [];
        for (const p of pts) {
            if (p.s > tailLen + 2)
                break;
            const w = halfWidth(p.s);
            left.push(at(p, w, 0));
            right.unshift(at(p, -w, 0));
        }
        const tail = "M " + left.join(" L ") + " L " + right.join(" L ") + " Z";
        // Paired dark blotches either side of the midline, every 16 px.
        const blotches = [];
        for (const p of pts) {
            if (p.s < 14 || p.s > len - 14 || Math.round(p.s) % 16 !== 0)
                continue;
            const k = halfWidth(p.s) / (bodyW / 2), o = 3.3 * k, h = 3 * k;
            blotches.push(`M ${at(p, o, -h)} L ${at(p, o, h)} M ${at(p, -o, -h)} L ${at(p, -o, h)}`);
        }
        // Keeled scales: rows of short pale dashes, staggered.
        const keels = [];
        for (const p of pts) {
            if (p.s < 6 || p.s > len - 8)
                continue;
            const k = halfWidth(p.s) / (bodyW / 2), row = Math.round(p.s / 2) % 3;
            if (row === 0)
                keels.push(`M ${at(p, 0, -0.75)} L ${at(p, 0, 0.75)}`);
            else if (row === 1)
                keels.push(`M ${at(p, 6 * k, -0.75)} L ${at(p, 6 * k, 0.75)} M ${at(p, -6 * k, -0.75)} L ${at(p, -6 * k, 0.75)}`);
        }
        const end = pts[n - 1], prev = pts[n - 3];
        return {
            main: main.join(" "),
            tail: tail,
            blotches: blotches.join(" "),
            keels: keels.join(" "),
            joint: Qt.point(end.x, end.y),
            angle: Math.atan2(end.y - prev.y, end.x - prev.x) * 180 / Math.PI
        };
    }

    // Shapes

    component Line: ShapePath {
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    // Outline layer first (the stroke and the tail, grown by the rim), then
    // the body over it, so loops and the tail join without seams. Flat caps:
    // the tail end hides under the tail, the neck end under the head.
    component Body: Shape {
        preferredRendererType: Shape.CurveRenderer
        Line {
            strokeColor: U.Palette.viperOutline
            strokeWidth: root.bodyW + 2 * root.rim
            capStyle: ShapePath.FlatCap
            PathSvg { path: root.geo.main }
        }
        ShapePath {
            fillColor: U.Palette.viperOutline
            strokeColor: U.Palette.viperOutline
            strokeWidth: 2 * root.rim
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.geo.tail }
        }
        Line {
            strokeColor: U.Palette.viperBody
            strokeWidth: root.bodyW
            capStyle: ShapePath.FlatCap
            PathSvg { path: root.geo.main }
        }
        ShapePath {
            fillColor: U.Palette.viperBody
            strokeColor: "transparent"
            PathSvg { path: root.geo.tail }
        }
        Line {
            strokeColor: U.Palette.viperBlotch
            strokeWidth: 5
            PathSvg { path: root.geo.blotches }
        }
        Line {
            strokeColor: Qt.alpha(U.Palette.viperKeel, 0.55)
            strokeWidth: 1.2
            PathSvg { path: root.geo.keels }
        }
    }

    // The head, pointing +x from the neck joint at 0, 0: a broad triangle with
    // a dark V down it, two horns over the eyes, and vertical pupils. Drawn
    // at the mockup's size, then scaled up: the snout tip is `headLen` out.
    readonly property real headLen: 30
    component Head: Item {
        Shape {
            scale: 1.25
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: U.Palette.viperBody
                strokeColor: U.Palette.viperOutline
                strokeWidth: 1.4
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M -7 -10 C 4 -12 14 -10 22 -3 C 25 0 25 0 22 3 C 14 10 4 12 -7 10 Z" }
            }
            Line {
                strokeColor: U.Palette.viperBlotch
                strokeWidth: 1.6
                PathSvg { path: "M 0 -5 C 6 -6 12 -4 16 0 C 12 4 6 6 0 5" }
            }
            ShapePath {
                fillColor: U.Palette.viperBody
                strokeColor: U.Palette.viperOutline
                strokeWidth: 1.4
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 7.5 -8 L 3 -17.5 L 13 -8.5 Z M 7.5 8 L 3 17.5 L 13 8.5 Z" }
            }
            ShapePath {
                fillColor: U.Palette.viperEye
                strokeColor: U.Palette.viperOutline
                strokeWidth: 0.8
                PathSvg { path: "M 9.8 -6.5 a 2.2 2.2 0 1 0 4.4 0 a 2.2 2.2 0 1 0 -4.4 0 M 9.8 6.5 a 2.2 2.2 0 1 0 4.4 0 a 2.2 2.2 0 1 0 -4.4 0" }
            }
            Line {
                strokeColor: "black"
                strokeWidth: 0.9
                capStyle: ShapePath.FlatCap
                PathSvg { path: "M 12 -8 L 12 -5 M 12 5 L 12 8" }
            }
        }
    }

    // Motion

    // The coil's size about the panel's centre: at 0.7 it sits wholly behind
    // the panel. `reveal` fades in the front layer once it is out.
    property real grow: 0.7
    property real reveal: 0
    // The head: sway in degrees, how far drawn back (0..1), how far into the
    // strike (0..1).
    property real sway: 0
    property real retreat: 0
    property real lunge: 0
    // The strike's end pose, fixed when it starts.
    property point strikeJoint: geo.joint
    property real strikeAngle: geo.angle

    onPhaseChanged: {
        enter.stop();
        if (phase === "hidden") {
            strikeAnim.stop();
            drawBack.stop();
            grow = 0.7;
            reveal = 0;
            sway = 0;
            retreat = 0;
            lunge = 0;
        } else if (phase === "entering") {
            enter.restart();
        } else {
            grow = 1;
            reveal = 1;
            if (phase === "strike" && side === "front")
                strike();
        }
    }

    function strike() {
        drawBack.stop();
        retreat = 0;
        const j = geo.joint, t = strikeTarget;
        const d = Math.hypot(t.x - j.x, t.y - j.y) || 1;
        // The snout tip lands on the target.
        const reach = Math.max(0, d - headLen);
        strikeJoint = Qt.point(j.x + (t.x - j.x) / d * reach, j.y + (t.y - j.y) / d * reach);
        strikeAngle = Math.atan2(t.y - j.y, t.x - j.x) * 180 / Math.PI;
        strikeAnim.restart();
    }

    // Out from behind the panel once it has mostly opened.
    SequentialAnimation {
        id: enter
        PauseAnimation { duration: 250 }
        ParallelAnimation {
            NumberAnimation { target: root; property: "grow"; from: 0.7; to: 1; duration: 500; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 330 }
                NumberAnimation { target: root; property: "reveal"; from: 0; to: 1; duration: 170 }
            }
        }
        ScriptAction {
            script: if (root.side === "front") root.phase = "idle"
        }
    }

    // Head ±4° every 3 s while idle.
    SequentialAnimation on sway {
        running: root.side === "front" && root.phase === "idle"
        loops: Animation.Infinite
        NumberAnimation { to: 4; duration: 750; easing.type: Easing.InOutSine }
        NumberAnimation { to: -4; duration: 1500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 750; easing.type: Easing.InOutSine }
    }

    // Now and then it draws its head back a little, as if to strike.
    Timer {
        running: root.side === "front" && root.phase === "idle"
        repeat: true
        interval: 4000
        onTriggered: {
            drawBack.restart();
            interval = 3500 + Math.random() * 4000;
        }
    }
    SequentialAnimation {
        id: drawBack
        NumberAnimation { target: root; property: "retreat"; to: 1; duration: 260; easing.type: Easing.OutQuad }
        PauseAnimation { duration: 380 }
        NumberAnimation { target: root; property: "retreat"; to: 0; duration: 480; easing.type: Easing.InOutSine }
    }

    SequentialAnimation {
        id: strikeAnim
        NumberAnimation { target: root; property: "lunge"; from: 0; to: 1; duration: 150; easing.type: Easing.OutQuart }
        PauseAnimation { duration: 60 }
        ScriptAction { script: root.struck() }
    }

    // The head's pose: at rest on the neck, swaying and drawn back, blended
    // into the strike pose.
    readonly property real restRad: geo.angle * Math.PI / 180
    readonly property real headX: (1 - lunge) * (geo.joint.x - 4 * retreat * Math.cos(restRad)) + lunge * strikeJoint.x
    readonly property real headY: (1 - lunge) * (geo.joint.y - 4 * retreat * Math.sin(restRad)) + lunge * strikeJoint.y
    readonly property real headAngle: (1 - lunge) * (geo.angle + sway) + lunge * strikeAngle

    // Drawing

    Item {
        id: coil
        anchors.fill: parent
        // Not drawn until it starts out: the panel may not cover it yet.
        visible: root.grow > 0.7
        opacity: root.side === "front" ? root.reveal : 1
        transform: Scale {
            origin.x: root.panelW / 2
            origin.y: root.panelH / 2
            xScale: root.grow
            yScale: root.grow
        }

        // Back: the whole body, and the head until the front one shows.
        Body {
            visible: root.side === "back"
        }
        Head {
            visible: root.side === "back" && root.phase === "entering"
            x: root.geo.joint.x
            y: root.geo.joint.y
            rotation: root.geo.angle
            transformOrigin: Item.TopLeft
        }

        // Front: the crossings, only within the bands over the panel.
        Repeater {
            model: root.side === "front" ? root.bands : []
            Item {
                required property var modelData
                y: modelData[0]
                width: root.panelW
                height: modelData[1] - modelData[0]
                clip: true
                Body {
                    y: -parent.y
                }
            }
        }

        // The neck, stretched straight out behind the head in a strike.
        Rectangle {
            visible: root.side === "front" && root.lunge > 0
            x: root.geo.joint.x
            y: root.geo.joint.y - height / 2
            width: Math.hypot(root.headX - root.geo.joint.x, root.headY - root.geo.joint.y)
            height: root.bodyW + 2 * root.rim
            radius: height / 2
            transformOrigin: Item.Left
            rotation: Math.atan2(root.headY - root.geo.joint.y, root.headX - root.geo.joint.x) * 180 / Math.PI
            color: U.Palette.viperBody
            border.width: root.rim
            border.color: U.Palette.viperOutline
        }

        Head {
            visible: root.side === "front"
            x: root.headX
            y: root.headY
            rotation: root.headAngle
            transformOrigin: Item.TopLeft
        }
    }
}
