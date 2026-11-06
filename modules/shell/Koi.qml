// Koi under the glass of the bottom bar: three fish swim in the pill behind
// the widgets. They wander, rest, and now and then touch the surface; they
// come to look at a pointer held still, dart off from a fast one, rush to a
// click on the water, and startle when a workspace or the volume changes.
// Motion comes from koi-motion.js; colours from the wallpaper (Theme).
import QtQuick
import "koi-motion.js" as Koi

Item {
    id: root

    property bool running: false
    // Pointer in this item's coordinates, NaN when it isn't over the bar.
    property real hoverX: NaN
    property real hoverY: NaN

    clip: true

    // Where heads may go: the middle band, clear of the rounded ends.
    readonly property var pool: ({ x: 12, y: height / 2 - 7, w: width - 24, h: 14 })

    // Colours sink toward the bar's own, as if seen through water.
    function sunk(c, k) {
        return Qt.tint(c, Qt.alpha(Theme.surface, k === undefined ? 0.3 : k));
    }
    // Koi red for the hi patches, warmed a little toward the wallpaper.
    readonly property color hi: Qt.tint("#d8432f", Qt.alpha(Theme.tertiary, 0.15))

    // Three varieties: kohaku (white, red patches), a lavender koi in the
    // wallpaper's own colour with red patches and ink spots, and ogon (one
    // metallic gold). Spots sit on the back: `s` is the spine position in
    // segments from the head, `side` shifts it sideways (-1..1), `l` is its
    // length in segments and `f` its share of the body's width.
    readonly property var kinds: [
        { len: 36, w: 11, speed: 13, base: Theme.text, eye: Theme.surface,
          spots: [{ s: 0.2, side: 0, l: 0.9, f: 0.55, c: hi },
                  { s: 1.9, side: -0.5, l: 1.9, f: 0.8, c: hi },
                  { s: 3.6, side: 0.6, l: 1.5, f: 0.7, c: hi },
                  { s: 5.0, side: -0.2, l: 1.0, f: 0.6, c: hi }] },
        { len: 31, w: 10, speed: 15, base: Theme.primary, eye: Theme.surface,
          spots: [{ s: 1.4, side: 0.4, l: 1.6, f: 0.75, c: hi },
                  { s: 3.3, side: -0.5, l: 1.2, f: 0.6, c: hi },
                  { s: 2.4, side: -0.7, l: 0.5, f: 0.3, c: Theme.surface },
                  { s: 4.4, side: 0.6, l: 0.6, f: 0.35, c: Theme.surface },
                  { s: 5.5, side: -0.3, l: 0.4, f: 0.3, c: Theme.surface }] },
        { len: 27, w: 9, speed: 17, base: Qt.tint("#e2a64a", Qt.alpha(Theme.primary, 0.2)), eye: Theme.surface,
          spots: [] }
    ]

    property var fish: []
    // The drawn spines, one array of {x, y, a} per koi; rewritten every tick.
    property var poses: []
    property real t: 0

    // The pointer: where it was, how fast it moved, when it last moved.
    property real pointerSpeed: 0
    property real stillSince: 0
    property real lastX: NaN
    property real lastY: NaN
    property real lastAt: 0
    onHoverXChanged: track()
    onHoverYChanged: track()
    function track() {
        if (isNaN(hoverX)) {
            lastX = NaN;
            return;
        }
        const now = Date.now();
        if (!isNaN(lastX) && now > lastAt) {
            const v = Math.hypot(hoverX - lastX, hoverY - lastY) / ((now - lastAt) / 1000);
            pointerSpeed = Math.max(pointerSpeed * 0.5, v);
        }
        lastX = hoverX;
        lastY = hoverY;
        lastAt = now;
        stillSince = t;
    }

    Component.onCompleted: {
        const f = [];
        for (let i = 0; i < kinds.length; i++) {
            const k = Koi.create(kinds[i].len, 40 + i * (width - 80) / 2, height / 2 + (i - 1) * 4, i % 2 ? Math.PI : 0);
            k.kind = kinds[i];
            k.mode = "wander";
            k.until = 0;
            k.target = { x: k.x, y: k.y };
            k.nextKiss = 8000 + Math.random() * 15000;
            Koi.follow(k);
            f.push(k);
        }
        fish = f;
        poses = f.map(Koi.pose);
    }

    // A ring on the water at (x, y); a second, smaller one follows it.
    property int nextRipple: 0
    function ripple(x, y, size) {
        const r = ripples.itemAt(nextRipple);
        nextRipple = (nextRipple + 1) % ripples.count;
        r.go(x, y, size);
    }

    // Something happened at x (a workspace switch, a volume change): a ripple
    // there; koi nearby dart off, and the nearest comes back to look.
    function notice(x) {
        ripple(x, height / 2, 26);
        let near = null;
        for (const k of fish) {
            const d = Math.abs(k.x - x);
            if (d < 110) {
                k.target = Koi.flee(k, x, height / 2, pool);
                k.mode = "dart";
                k.until = t + 900;
                k.lookAt = { x: x, at: t + 1500 };
            }
            if (!near || d < Math.abs(near.x - x)) near = k;
        }
        for (const k of fish) if (k !== near) k.lookAt = null;
        if (near && near.mode !== "dart") near.lookAt = { x: x, at: t + 300 };
    }

    // A click on open water: koi come for it as if it were food.
    function feed(x, y) {
        ripple(x, y, 22);
        for (const k of fish) {
            if (Math.abs(k.x - x) < 320) {
                k.mode = "feed";
                k.target = { x: x + (Math.random() - 0.5) * 6, y: y + (Math.random() - 0.5) * 6 };
                k.until = t + 4000;
            }
        }
    }

    // Hang in the water, drifting on along its heading.
    function rest(k, ms) {
        k.mode = "rest";
        k.until = t + ms;
        k.target = { x: k.x + Math.cos(k.a) * 30, y: k.y + Math.sin(k.a) * 30 };
    }

    function think(k) {
        const pointer = !isNaN(hoverX);
        const dPointer = pointer ? Math.hypot(k.x - hoverX, k.y - hoverY) : Infinity;

        // A fast pointer close by scares it off.
        if (pointer && pointerSpeed > 380 && dPointer < 50 && k.mode !== "dart") {
            k.target = Koi.flee(k, hoverX, hoverY, pool);
            k.mode = "dart";
            k.until = t + 900;
        }
        if ((k.mode === "dart" || k.mode === "feed" || k.mode === "rest") && t < k.until) {
            if (k.mode === "feed" && Math.hypot(k.x - k.target.x, k.y - k.target.y) < 7) {
                // Nibbling at the surface.
                ripple(k.x + Math.cos(k.a) * 4, k.y + Math.sin(k.a) * 4, 9);
                rest(k, 1200 + Math.random() * 1500);
            }
            return k.mode === "dart" ? 95 : k.mode === "feed" ? 48 : 2;
        }
        // Coming back to look at where something happened.
        if (k.lookAt && t >= k.lookAt.at) {
            k.target = { x: k.lookAt.x + (k.x < k.lookAt.x ? -10 : 10), y: height / 2 };
            k.mode = "look";
            k.until = t + 2500;
            k.lookAt = null;
        }
        // A pointer held still: come up to it and hang there, nose to it.
        if (pointer && t - stillSince > 600 && dPointer < 240) {
            const side = k.x < hoverX ? -1 : 1;
            k.target = { x: hoverX + side * 11, y: Math.max(pool.y, Math.min(pool.y + pool.h, hoverY)) };
            k.mode = "curious";
            return dPointer < 16 ? 3 : 16;
        }
        if ((k.mode === "look" && t < k.until))
            return Math.hypot(k.x - k.target.x, k.y - k.target.y) < 6 ? 2 : 22;
        // Wandering, with rests.
        if (k.mode !== "wander" || Math.hypot(k.x - k.target.x, k.y - k.target.y) < 8 || t > k.until) {
            if (k.mode === "wander" && Math.random() < 0.3) {
                rest(k, 1500 + Math.random() * 2500);
                return 2;
            }
            k.mode = "wander";
            k.target = Koi.wander(Math.random, pool);
            k.until = t + 12000;
        }
        if (t > k.nextKiss) {
            // Up to the surface for a moment.
            ripple(k.x + Math.cos(k.a) * 4, k.y + Math.sin(k.a) * 4, 12);
            k.nextKiss = t + 12000 + Math.random() * 20000;
        }
        return k.kind.speed;
    }

    Timer {
        // ~48 Hz: smooth enough for fish, a third of a 144 Hz frame rate.
        interval: 21
        repeat: true
        running: root.running && root.width > 0
        onTriggered: {
            const dt = interval / 1000;
            root.t += interval;
            root.pointerSpeed *= 0.85;
            for (const k of root.fish) {
                const speed = root.think(k);
                Koi.steer(k, dt, k.target.x, k.target.y, speed);
                // Keep a little room between fish.
                for (const o of root.fish) {
                    if (o === k) continue;
                    const dx = k.x - o.x, dy = k.y - o.y, d = Math.hypot(dx, dy);
                    if (d > 0 && d < 12) {
                        k.x += dx / d * 0.25;
                        k.y += dy / d * 0.25;
                    }
                }
                Koi.keepIn(k, root.pool);
                Koi.follow(k);
            }
            root.poses = root.fish.map(Koi.pose);
        }
    }

    Repeater {
        id: ripples
        model: 6

        Rectangle {
            id: ring
            property real size: 20
            function go(x, y, s) {
                size = s;
                ring.x = x - s / 2;
                ring.y = y - s / 2;
                spread.restart();
            }
            width: size
            height: size
            radius: size / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.5)
            opacity: 0
            scale: 0.2

            ParallelAnimation {
                id: spread
                NumberAnimation { target: ring; property: "scale"; from: 0.15; to: 1; duration: 1100; easing.type: Easing.OutQuad }
                NumberAnimation { target: ring; property: "opacity"; from: 0.9; to: 0; duration: 1100; easing.type: Easing.InQuad }
            }
        }
    }

    Repeater {
        model: root.kinds.length

        Item {
            id: koi
            required property int index
            readonly property var kind: root.kinds[index]
            readonly property var p: root.poses[index] || []
            readonly property int n: p.length
            readonly property real seg: kind.len / (Koi.SEGMENTS - 1)
            readonly property real deg: 180 / Math.PI
            // Fins beat with the swim.
            readonly property real beat: root.poses && root.fish[index] ? Math.sin(root.fish[index].phase * 0.6) : 0

            readonly property color body: root.sunk(kind.base)
            // The spine at s segments from the head, between sample points.
            function along(s) {
                const i = Math.min(n - 2, Math.floor(s)), f = s - i;
                const a = p[i], b = p[i + 1];
                return { x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f, a: a.a + Math.atan2(Math.sin(b.a - a.a), Math.cos(b.a - a.a)) * f };
            }

            // A soft shadow on the pond floor under the middle of the body.
            Rectangle {
                visible: koi.n > 0
                readonly property var mid: koi.n ? koi.p[3] : { x: 0, y: 0, a: 0 }
                width: koi.kind.len * 0.8
                height: koi.kind.w * 0.9
                radius: height / 2
                x: mid.x - width / 2 + 2
                y: mid.y - height / 2 + 3
                rotation: mid.a * koi.deg
                color: Qt.alpha("black", 0.22)
            }

            // Tail fin: two lobes splayed from the tail tip, swinging with it.
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    visible: koi.n > 0
                    readonly property var tip: koi.n ? koi.p[koi.n - 1] : { x: 0, y: 0, a: 0 }
                    readonly property real ang: tip.a + Math.PI + modelData * (0.42 + 0.12 * koi.beat)
                    width: koi.kind.len * 0.32
                    height: koi.kind.w * 0.34
                    radius: height / 2
                    // Rotated about its root at the tail tip.
                    x: tip.x + Math.cos(ang) * width / 2 - width / 2
                    y: tip.y + Math.sin(ang) * width / 2 - height / 2
                    rotation: ang * koi.deg
                    color: Qt.alpha(koi.body, 0.6)
                }
            }

            // Pectoral fins, just behind the head, paddling.
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    visible: koi.n > 1
                    readonly property var at: koi.n > 1 ? koi.p[1] : { x: 0, y: 0, a: 0 }
                    readonly property real ang: at.a + Math.PI + modelData * (1.15 + 0.3 * koi.beat * modelData)
                    width: koi.kind.w * 0.55
                    height: koi.kind.w * 0.36
                    radius: height / 2
                    x: at.x + Math.cos(ang) * (koi.kind.w * 0.22 + width / 2) - width / 2
                    y: at.y + Math.sin(ang) * (koi.kind.w * 0.22 + width / 2) - height / 2
                    rotation: ang * koi.deg
                    color: Qt.alpha(koi.body, 0.55)
                }
            }

            // The body: overlapping rounded segments along the spine, tail first
            // so the head sits on top.
            Repeater {
                model: Koi.SEGMENTS
                Rectangle {
                    required property int index
                    readonly property int i: Koi.SEGMENTS - 1 - index
                    visible: koi.n > i
                    readonly property var at: koi.n > i ? koi.p[i] : { x: 0, y: 0, a: 0 }
                    width: koi.seg * (i === 0 ? 1.5 : 1.9)
                    height: Koi.bodyWidth(i, Koi.SEGMENTS, koi.kind.w)
                    radius: height / 2
                    x: at.x - width / 2
                    y: at.y - height / 2
                    rotation: at.a * koi.deg
                    color: koi.body
                    antialiasing: true
                }
            }

            // Patches on the back, kept inside the body's outline.
            Repeater {
                model: koi.kind.spots
                Rectangle {
                    required property var modelData
                    visible: koi.n > 1
                    readonly property var at: koi.n > 1 ? koi.along(modelData.s) : { x: 0, y: 0, a: 0 }
                    readonly property real bw: Koi.bodyWidth(Math.min(Koi.SEGMENTS - 1, Math.round(modelData.s)), Koi.SEGMENTS, koi.kind.w)
                    readonly property real off: modelData.side * bw * (1 - modelData.f) / 2
                    width: koi.seg * modelData.l
                    height: bw * modelData.f
                    radius: height / 2
                    x: at.x - Math.sin(at.a) * off - width / 2
                    y: at.y + Math.cos(at.a) * off - height / 2
                    rotation: at.a * koi.deg
                    color: root.sunk(modelData.c)
                    antialiasing: true
                }
            }

            // A pale sheen down the back.
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    visible: koi.n > index + 1
                    readonly property var at: koi.n > index + 1 ? koi.p[index + 1] : { x: 0, y: 0, a: 0 }
                    width: koi.seg * 1.4
                    height: 1.2
                    radius: 0.6
                    x: at.x - width / 2
                    y: at.y - height / 2
                    rotation: at.a * koi.deg
                    color: Qt.alpha("white", 0.18)
                }
            }

            // Eyes, either side of the head.
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    visible: koi.n > 0
                    readonly property var h: koi.n ? koi.p[0] : { x: 0, y: 0, a: 0 }
                    width: 1.8
                    height: 1.8
                    radius: 0.9
                    x: h.x + Math.cos(h.a) * koi.seg * 0.35 - Math.sin(h.a) * modelData * koi.kind.w * 0.3 - 0.9
                    y: h.y + Math.sin(h.a) * koi.seg * 0.35 + Math.cos(h.a) * modelData * koi.kind.w * 0.3 - 0.9
                    color: root.sunk(koi.kind.eye, 0.15)
                }
            }
        }
    }
}
