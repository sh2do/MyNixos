// Koi under the glass of the bottom bar: three fish swim in the pill behind
// the widgets. They wander, rest, and now and then touch the surface; they
// come to look at a pointer held still, dart off from a fast one, rush to a
// click on the water, and startle when a workspace or the volume changes.
// While music plays they gather in the middle, under the top pill, flick
// their tails to the bass and come up when the track changes.
// Motion comes from koi-motion.js; colours from the wallpaper (Theme).
import QtQuick
import QtQuick.Shapes
import Quickshell
import "koi-motion.js" as Koi
import "beat.js" as Beat

Item {
    id: root

    property bool running: false
    // Pointer in this item's coordinates, NaN when it isn't over the bar.
    property real hoverX: NaN
    property real hoverY: NaN
    // A player is playing, and its song (artist and title): set by the bar.
    property bool music: false
    property string song: ""

    clip: true

    // ---- The music. RICE_FAKE_BEAT=1 (or RICE_KOI_FAKE_BEAT=1) plays a
    // made-up beat (a bass kick every 600 ms, a swelling loudness) so it can
    // be seen without a player.
    readonly property bool fakeBeat: Quickshell.env("RICE_FAKE_BEAT") === "1" || Quickshell.env("RICE_KOI_FAKE_BEAT") === "1"
    readonly property bool musical: music || fakeBeat
    // The shared cava runs for us only while the bar is up and music plays.
    readonly property bool listening: running && music && !fakeBeat
    onListeningChanged: listening ? Cava.acquire() : Cava.release()
    Component.onDestruction: if (listening) Cava.release()
    property var beatState: null
    // The loudness, smoothed: brightens the caustic light a little.
    property real loud: 0
    onMusicalChanged: {
        for (const k of fish) {
            if (musical) {
                // Pick a new (gathered) place to go now.
                if (k.mode === "wander" || k.mode === "rest") k.until = t;
            } else {
                // Slow down, and spread out from the middle afterwards.
                rest(k, 1200 + Math.random() * 1800);
            }
        }
        if (!musical) {
            beatState = null;
            loud = 0;
        }
    }
    // The last song heard, so pausing and playing on isn't a new track.
    property string lastSong: ""
    onSongChanged: {
        if (song === "" || song === lastSong) return;
        lastSong = song;
        if (!running || !fish.length) return;
        // The koi nearest the middle comes up to see.
        let near = fish[0];
        for (const k of fish)
            if (Math.abs(k.x - width / 2) < Math.abs(near.x - width / 2)) near = k;
        surface(near);
        bubble(near.x + Math.cos(near.a) * 2, near.y + Math.sin(near.a) * 2 + 1);
        rest(near, 1000 + Math.random() * 800);
    }
    // Levels from cava (or the fake beat), 0..1: [bass, ..., treble].
    function levelsNow() {
        if (fakeBeat) {
            const kick = t % 600 < 80 ? 0.85 : 0.15;
            return [kick, 0.3, 0.35 + 0.25 * Math.sin(t / 2000), 0.3, 0.2];
        }
        return Cava.ok ? Cava.levels : null;
    }
    // One tick of listening: beats flick a tail, loudness lights the water.
    function listen() {
        const lv = levelsNow();
        if (!lv) return;
        const r = Beat.beatStep(beatState, lv[0], t);
        beatState = r.state;
        if (r.beat) {
            // The koi nearest a random spot flicks its tail; a ring above it.
            const px = pool.x + Math.random() * pool.w;
            let near = null;
            for (const k of fish)
                if (!near || Math.abs(k.x - px) < Math.abs(near.x - px)) near = k;
            if (near) {
                near.flickUntil = t + 260;
                near.v = Math.max(near.v, near.kind.speed * 1.5);
                ripple(near.x, near.y, 16);
            }
        }
        let m = 0;
        for (const x of lv) m += x;
        m /= lv.length;
        const next = loud + (m - loud) * 0.08;
        if (Math.abs(next - loud) > 0.005) loud = next;
    }

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
                  { s: 2.7, side: 0.5, l: 0.8, f: 0.45, c: hi },
                  { s: 3.6, side: 0.6, l: 1.5, f: 0.7, c: hi },
                  { s: 4.3, side: -0.6, l: 0.6, f: 0.35, c: hi },
                  { s: 5.0, side: -0.2, l: 1.0, f: 0.6, c: hi }] },
        { len: 31, w: 10, speed: 15, base: Theme.primary, eye: Theme.surface,
          spots: [{ s: 1.4, side: 0.4, l: 1.6, f: 0.75, c: hi },
                  { s: 2.1, side: -0.3, l: 0.7, f: 0.4, c: hi },
                  { s: 3.3, side: -0.5, l: 1.2, f: 0.6, c: hi },
                  { s: 3.9, side: 0.4, l: 0.6, f: 0.35, c: hi },
                  { s: 2.4, side: -0.7, l: 0.5, f: 0.3, c: Theme.surface },
                  { s: 4.4, side: 0.6, l: 0.6, f: 0.35, c: Theme.surface },
                  { s: 5.5, side: -0.3, l: 0.4, f: 0.3, c: Theme.surface }] },
        { len: 27, w: 9, speed: 17, base: Qt.tint("#e2a64a", Qt.alpha(Theme.primary, 0.2)), eye: Theme.surface,
          spots: [{ s: 1.2, side: 0, l: 3.2, f: 0.3, c: Qt.lighter("#e2a64a", 1.3) }] }
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
            if (k.mode === "wander" && Math.random() < (musical ? 0.1 : 0.3)) {
                rest(k, 1500 + Math.random() * 2500);
                return 2;
            }
            k.mode = "wander";
            k.target = Koi.cruise(k, Math.random, pool);
            if (musical)
                k.target = Koi.gather(k.target, pool.x + pool.w / 2, 0.3);
            k.until = t + 12000;
        }
        if (t > k.nextKiss)
            surface(k);
        // Livelier to the music.
        return musical ? k.kind.speed * 1.35 : k.kind.speed;
    }

    // Up to the surface for a moment: a ring and a couple of bubbles.
    function surface(k) {
        ripple(k.x + Math.cos(k.a) * 4, k.y + Math.sin(k.a) * 4, 12);
        bubble(k.x + Math.cos(k.a) * 5, k.y + Math.sin(k.a) * 5);
        bubble(k.x + Math.cos(k.a) * 3 + 2, k.y + Math.sin(k.a) * 3 - 1);
        k.nextKiss = t + 12000 + Math.random() * 20000;
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
            if (root.musical)
                root.listen();
            for (const k of root.fish) {
                const speed = root.think(k);
                Koi.steer(k, dt, k.target.x, k.target.y, speed);
                // A quicker tail beat to the music, and a flick on a beat.
                if (root.musical)
                    k.phase += dt * (root.t < (k.flickUntil || 0) ? 16 : 1.6);
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
                // A darting koi leaves a wake.
                if (k.v > 40 && root.t > (k.nextWake || 0)) {
                    const tail = k.pts[k.pts.length - 1];
                    root.ripple(tail.x, tail.y, 7 + k.v / 15);
                    k.nextWake = root.t + 150;
                }
            }
            root.poses = root.fish.map(Koi.pose);
            // Rain dimpling the surface now and then.
            if (root.t > root.nextDrop) {
                root.ripple(root.pool.x + Math.random() * root.pool.w, 4 + Math.random() * (root.height - 8), 5 + Math.random() * 5);
                root.nextDrop = root.t + 700 + Math.random() * 2600;
            }
        }
    }
    property real nextDrop: 0

    // Caustics: light netted on the pond floor by the surface, two layers
    // drifting against each other. Drawn once; only moved per tick.
    Repeater {
        model: [{ dx: 0.004, op: 0.035, seed: 1 }, { dx: -0.0027, op: 0.025, seed: 2 }]
        Canvas {
            id: caustic
            required property var modelData
            readonly property int period: 160
            z: 0
            width: root.width + period
            height: root.height
            x: -((root.t * modelData.dx % period + period) % period)
            // A little brighter the louder the music.
            opacity: modelData.op * (1 + 0.9 * root.loud)
            onWidthChanged: requestPaint()
            Connections {
                target: Theme
                function onColoursChanged() { caustic.requestPaint(); }
            }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = Theme.text;
                ctx.lineWidth = 1.4;
                ctx.lineCap = "round";
                // Two families of wavy lines crossing at a slant make the net.
                // Every wave fits a whole number of times in `period`, so the
                // drift wraps without a seam.
                const seed = modelData.seed;
                for (const dir of [1, -1]) {
                    // Spacing 8 and slope 0.35 shift a line by exactly 7
                    // spacings over one period: the net repeats.
                    const reach = Math.ceil(width * 0.35 / 8);
                    for (let k = dir > 0 ? -1 : -reach; k < (dir > 0 ? reach : 0) + Math.ceil(height / 8) + 1; k++) {
                        ctx.beginPath();
                        for (let x = 0; x <= width; x += 3) {
                            const y = k * 8 - dir * x * 0.35
                                + 3 * Math.sin(2 * Math.PI * x / (period / 2) + k * 1.7 + seed)
                                + 1.5 * Math.sin(2 * Math.PI * x / (period / 4) + k + seed * 2);
                            if (x === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }
                }
            }
        }
    }

    // A small lily pad drifting slowly along the bar; the koi swim under it.
    Item {
        id: pad
        z: 2
        readonly property real d: 13
        width: d
        height: d
        x: root.width * (0.62 + 0.05 * Math.sin(root.t / 23000)) - d / 2
        y: root.height / 2 - d / 2 + 4 * Math.sin(root.t / 17000)
        rotation: 25 * Math.sin(root.t / 31000)

        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            x: 1.5
            radius: width / 2
            color: Qt.alpha("black", 0.25)
            transform: Translate { x: 1.5; y: 2 }
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Theme.primary, 0.5)
                strokeWidth: 0.6
                fillColor: root.sunk(Theme.primaryContainer, 0.15)
                // A disc with a notch cut to the middle.
                startX: pad.d / 2
                startY: pad.d / 2
                PathLine { x: pad.d / 2 + pad.d / 2 * Math.cos(-0.25); y: pad.d / 2 + pad.d / 2 * Math.sin(-0.25) }
                PathArc {
                    x: pad.d / 2 + pad.d / 2 * Math.cos(0.25)
                    y: pad.d / 2 + pad.d / 2 * Math.sin(0.25)
                    radiusX: pad.d / 2
                    radiusY: pad.d / 2
                    useLargeArc: true
                    direction: PathArc.Counterclockwise
                }
                PathLine { x: pad.d / 2; y: pad.d / 2 }
            }
            ShapePath {
                strokeColor: Qt.alpha(Theme.primary, 0.3)
                strokeWidth: 0.5
                fillColor: "transparent"
                startX: pad.d / 2; startY: pad.d / 2
                PathLine { x: pad.d * 0.08; y: pad.d / 2 }
                PathMove { x: pad.d / 2; y: pad.d / 2 }
                PathLine { x: pad.d * 0.25; y: pad.d * 0.12 }
                PathMove { x: pad.d / 2; y: pad.d / 2 }
                PathLine { x: pad.d * 0.25; y: pad.d * 0.88 }
            }
        }
        // A bud on the pad.
        Repeater {
            model: 5
            Rectangle {
                required property int index
                width: 3.2
                height: 1.6
                radius: 0.8
                x: pad.d * 0.3 + Math.cos(index * 1.2566) * 1.3 - width / 2
                y: pad.d * 0.62 + Math.sin(index * 1.2566) * 1.3 - height / 2
                rotation: index * 72
                color: Qt.tint(Theme.tertiary, Qt.alpha("white", 0.3))
            }
        }
        Rectangle {
            width: 1.6; height: 1.6; radius: 0.8
            x: pad.d * 0.3 - 0.8; y: pad.d * 0.62 - 0.8
            color: "#e2a64a"
        }
    }

    // Bubbles: up from a koi's mouth, a little drift, then they pop.
    property int nextBubble: 0
    function bubble(x, y) {
        const b = bubbles.itemAt(nextBubble);
        nextBubble = (nextBubble + 1) % bubbles.count;
        b.go(x, y);
    }
    Repeater {
        id: bubbles
        model: 8
        Rectangle {
            id: bub
            z: 3
            property real born: -1e9
            property real x0: 0
            property real drift: 0
            readonly property real age: (root.t - born) / 1000
            function go(x, y) {
                x0 = x - 1;
                bub.y = y - 1;
                drift = (Math.random() - 0.5) * 6;
                born = root.t;
            }
            visible: age >= 0 && age < 1
            x: x0 + drift * Math.sin(age * Math.PI / 2)
            width: 2.2
            height: 2.2
            radius: 1.1
            color: Qt.alpha(Theme.text, 0.15)
            border.width: 0.6
            border.color: Qt.alpha(Theme.text, 0.6)
            // Fades in, rises (grows), and pops.
            scale: 0.4 + 0.8 * Math.sin(age * Math.PI / 2)
            opacity: age < 0.2 ? age / 0.2 * 0.9 : age < 0.88 ? 0.9 : (1 - age) / 0.12 * 0.9
        }
    }

    // The glass: a faint sheen over the top of the water.
    Rectangle {
        z: 4
        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height * 0.45
        radius: Theme.radius
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("white", 0.06) }
            GradientStop { position: 1; color: Qt.alpha("white", 0) }
        }
    }

    Repeater {
        id: ripples
        model: 12

        // Driven by the koi's clock rather than an animation, so it renders
        // at the tick rate (48 Hz), not every display frame.
        Rectangle {
            id: ring
            z: 3
            property real size: 20
            property real born: -1e9
            readonly property real age: (root.t - born) / 1100
            function go(x, y, s) {
                size = s;
                ring.x = x - s / 2;
                ring.y = y - s / 2;
                born = root.t;
            }
            visible: age >= 0 && age < 1
            width: size
            height: size
            radius: size / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.text, 0.5)
            scale: 0.15 + 0.85 * (1 - (1 - age) * (1 - age))
            opacity: 0.9 * (1 - age * age)
        }
    }

    Repeater {
        model: root.kinds.length

        Item {
            id: koi
            z: 1
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
                    readonly property real ang: tip.a + Math.PI + modelData * (0.38 + 0.14 * koi.beat) + 0.12 * koi.beat
                    width: koi.kind.len * 0.3
                    height: koi.kind.w * 0.5
                    radius: height / 2
                    // Rotated about its root at the tail tip.
                    x: tip.x + Math.cos(ang) * width / 2 - width / 2
                    y: tip.y + Math.sin(ang) * width / 2 - height / 2
                    rotation: ang * koi.deg
                    color: Qt.alpha(koi.body, 0.55)
                    border.width: 0.5
                    border.color: Qt.alpha(koi.body, 0.8)
                }
            }

            // Pelvic fins, small, further back.
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    visible: koi.n > 4
                    readonly property var at: koi.n > 4 ? koi.p[4] : { x: 0, y: 0, a: 0 }
                    readonly property real ang: at.a + Math.PI + modelData * (0.95 - 0.2 * koi.beat * modelData)
                    width: koi.kind.w * 0.38
                    height: koi.kind.w * 0.24
                    radius: height / 2
                    x: at.x + Math.cos(ang) * (koi.kind.w * 0.15 + width / 2) - width / 2
                    y: at.y + Math.sin(ang) * (koi.kind.w * 0.15 + width / 2) - height / 2
                    rotation: ang * koi.deg
                    color: Qt.alpha(koi.body, 0.45)
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
            // so the head sits on top. A darker pass first rounds the flanks.
            Repeater {
                model: Koi.SEGMENTS
                Rectangle {
                    required property int index
                    readonly property int i: Koi.SEGMENTS - 1 - index
                    visible: koi.n > i
                    readonly property var at: koi.n > i ? koi.p[i] : { x: 0, y: 0, a: 0 }
                    width: koi.seg * (i === 0 ? 1.5 : 1.9) + 0.6
                    height: Koi.bodyWidth(i, Koi.SEGMENTS, koi.kind.w) + 0.6
                    radius: height / 2
                    x: at.x - width / 2
                    y: at.y - height / 2
                    rotation: at.a * koi.deg
                    color: Qt.darker(koi.body, 1.45)
                    antialiasing: true
                }
            }
            Repeater {
                model: Koi.SEGMENTS
                Rectangle {
                    required property int index
                    readonly property int i: Koi.SEGMENTS - 1 - index
                    visible: koi.n > i
                    readonly property var at: koi.n > i ? koi.p[i] : { x: 0, y: 0, a: 0 }
                    width: koi.seg * (i === 0 ? 1.3 : 1.8)
                    height: Koi.bodyWidth(i, Koi.SEGMENTS, koi.kind.w) * 0.78
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

            // The dorsal fin, folded down the back as a dark ridge.
            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    visible: koi.n > index + 3
                    readonly property var at: koi.n > index + 3 ? koi.along(2.3 + index * 0.8) : { x: 0, y: 0, a: 0 }
                    width: koi.seg * 1.0
                    height: 1
                    radius: 0.5
                    x: at.x - width / 2
                    y: at.y - height / 2
                    rotation: at.a * koi.deg
                    color: Qt.alpha(Qt.darker(koi.body, 1.8), 0.6)
                }
            }

            // Whiskers at the mouth.
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    visible: koi.n > 0
                    readonly property var h: koi.n ? koi.p[0] : { x: 0, y: 0, a: 0 }
                    readonly property real ang: h.a + modelData * 2.2
                    readonly property real len: 3.2
                    width: len
                    height: 0.6
                    x: h.x + Math.cos(h.a) * koi.seg * 0.62 + Math.cos(ang) * len / 2 - len / 2
                    y: h.y + Math.sin(h.a) * koi.seg * 0.62 + Math.sin(ang) * len / 2 - 0.3
                    rotation: ang * koi.deg
                    color: Qt.alpha(Theme.text, 0.55)
                    antialiasing: true
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
