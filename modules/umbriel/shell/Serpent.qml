// A serpent's body, bent on the GPU. The skin is any Item laid out as a
// straight horizontal strip (neck on the left, tail tip on the right); it is
// drawn once into a hidden texture and serpent.vert bends a GridMesh of it
// along the spine. Per frame only the uniforms change: the 24 evenly spaced
// spine points and the lighting inputs. The shadow is the same mesh again,
// drawn first and offset (serpent-shadow.frag).
//
// skinRect: the part of the skin item this body wears (default: all of it),
// so several bodies can share one strip, each its own stretch of it.
//
// spine: control points [{x, y}] in this item's coordinates, neck first.
// widths: width scales per control point; by default the plain taper of
// serpent-spine.js widthAt. head and tail are the spine's end samples
// ({x, y, tx, ty, s}, tangent pointing from the neck towards the tail), for
// whatever attaches there; null while the spine has fewer than 2 points (the
// body is hidden then).
//
// Updates are batched: assigning spine and/or widths only marks the body
// dirty, and one rebuild runs at the end of the event loop pass
// (Qt.callLater), however many were assigned. A driver ticking its own clock
// should call setSpine(spine, widths) instead: it assigns both and rebuilds
// once, immediately, with no frame of latency. Every assignment counts as a
// change, so a driver whose body is still should not assign at all.
import QtQuick
import "serpent-spine.js" as Spine

Item {
    id: serpent

    property Item skin
    property rect skinRect
    property real bodyWidth: 20
    property var spine: []
    // Placed by index: widths[k] lands at k / (length - 1) of the body, which
    // is exact for 24 widths or evenly spaced control points.
    property var widths: null
    property real time: 0
    property real sheen: 0
    property real dull: 0
    property real ripplePhase: 0
    property real rippleAmp: 0
    property point shadowOffset: Qt.point(3, 5)
    // Off for a body that continues into another: its shadow would fall
    // across the seam.
    property bool castShadow: true

    readonly property var head: priv.head
    readonly property var tail: priv.tail

    anchors.fill: parent

    // Assign both and rebuild now; ws may be omitted to keep the current widths.
    function setSpine(points, ws) {
        priv.direct = true;
        spine = points;
        if (ws !== undefined)
            widths = ws;
        priv.direct = false;
        priv.rebuild();
    }

    onSpineChanged: priv.markDirty()
    onWidthsChanged: priv.markDirty()
    onSkinChanged: strip.scheduleUpdate()
    onSkinRectChanged: strip.scheduleUpdate()
    Component.onCompleted: {
        priv.rebuild();
        strip.scheduleUpdate();
    }

    QtObject {
        id: priv

        property var head: null
        property var tail: null
        property bool valid: false
        property bool dirty: false
        // True while setSpine assigns, so its own assignments don't mark dirty.
        property bool direct: false
        readonly property var names: Array.from({ length: Spine.SPINE_POINTS }, (_, i) => "s" + i)
        readonly property var noBulges: []

        function markDirty() {
            if (direct || dirty)
                return;
            dirty = true;
            Qt.callLater(flush);
        }

        function flush() {
            if (dirty)
                rebuild();
        }

        // Resample the spine, attach each point's width scale and hand the
        // points to both passes.
        function rebuild() {
            dirty = false;
            const n = Spine.SPINE_POINTS;
            if (!serpent.spine || serpent.spine.length < 2) {
                valid = false;
                head = null;
                tail = null;
                return;
            }
            const samples = Spine.sample(serpent.spine, n);
            const ws = serpent.widths;
            for (let i = 0; i < n; i++) {
                const u = i / (n - 1);
                let w;
                if (ws && ws.length > 1) {
                    // By index fraction, not arc length (see widths).
                    const f = u * (ws.length - 1), k = Math.min(Math.floor(f), ws.length - 2);
                    w = ws[k] + (ws[k + 1] - ws[k]) * (f - k);
                } else {
                    w = Spine.widthAt(u, noBulges);
                }
                const p = Qt.vector4d(samples[i].x, samples[i].y, w, 0);
                body[names[i]] = p;
                shadow[names[i]] = p;
            }
            head = samples[0];
            tail = samples[n - 1];
            valid = true;
        }
    }

    // The skin strip, drawn once.
    ShaderEffectSource {
        id: strip
        sourceItem: serpent.skin
        sourceRect: serpent.skinRect
        hideSource: true
        live: false
        visible: false
    }

    component Pass: ShaderEffect {
        property real bodyWidth
        property real time
        property real sheen
        property real dull
        property real ripplePhase
        property real rippleAmp
        property vector4d s0
        property vector4d s1
        property vector4d s2
        property vector4d s3
        property vector4d s4
        property vector4d s5
        property vector4d s6
        property vector4d s7
        property vector4d s8
        property vector4d s9
        property vector4d s10
        property vector4d s11
        property vector4d s12
        property vector4d s13
        property vector4d s14
        property vector4d s15
        property vector4d s16
        property vector4d s17
        property vector4d s18
        property vector4d s19
        property vector4d s20
        property vector4d s21
        property vector4d s22
        property vector4d s23

        mesh: GridMesh { resolution: Qt.size(128, 4) }
        vertexShader: "serpent.vert.qsb"
    }

    Pass {
        id: shadow
        visible: priv.valid && serpent.castShadow
        x: serpent.shadowOffset.x
        y: serpent.shadowOffset.y
        width: serpent.width
        height: serpent.height
        bodyWidth: serpent.bodyWidth
        fragmentShader: "serpent-shadow.frag.qsb"
    }

    Pass {
        id: body
        visible: priv.valid
        readonly property var source: strip
        width: serpent.width
        height: serpent.height
        bodyWidth: serpent.bodyWidth
        time: serpent.time
        sheen: serpent.sheen
        dull: serpent.dull
        ripplePhase: serpent.ripplePhase
        rippleAmp: serpent.rippleAmp
        fragmentShader: "serpent.frag.qsb"
    }
}
