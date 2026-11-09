// Volume / brightness pop-up: a 56 × 168 glass capsule, bottom centre, that
// fills with water to the level. The surface is a drifting wave; each change
// rings ripples across it. It watches the state itself, so the media keys
// stay plain wpctl / brightnessctl binds. The first value read at startup is
// only remembered, never shown.
//
// Motion comes from one clock that runs only while the capsule shows: 20 Hz
// for 500 ms of ripples and rise after a change, then 6 Hz for a slow drift.
// Every frame costs the shell about 2 ms of CPU, so the rate is the budget.
// The wave is drawn once and only moved and stretched, never rebuilt.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

Scope {
    id: root

    property string icon: ""
    property real value: 0
    property bool shown: false

    readonly property var sink: Pipewire.defaultAudioSink

    readonly property real born: Date.now()

    Sound {
        id: sound
    }

    function show(icon, value) {
        root.icon = icon;
        root.value = Math.max(0, Math.min(1, value));
        if (!shown && fade === 0)
            level = root.value * 0.85;      // rise in from just below
        energy = Math.min(1, energy + 0.45);
        pendingRings = 2;
        lastChange = t;
        shown = true;
        hideTimer.restart();
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    // -1 means "not read yet", so the startup value doesn't pop the OSD.
    property real lastVolume: -1
    property int lastMuted: -1
    property real lastBrightness: -1

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            root.volumeChanged();
        }
        function onMutedChanged() {
            root.volumeChanged();
        }
    }

    function volumeChanged() {
        const audio = sink?.audio;
        if (!audio)
            return;
        const first = lastVolume < 0;
        const v = audio.volume;
        const m = audio.muted ? 1 : 0;
        if (!first && (Math.abs(v - lastVolume) > 0.001 || m !== lastMuted)) {
            // Not the values settling just after startup.
            if (!audio.muted && Date.now() - root.born > 3000)
                sound.play("tick");
            show(audio.muted ? "󰝟" : (v > 0.5 ? "󰕾" : "󰖀"), audio.muted ? 0 : v);
        }
        lastVolume = v;
        lastMuted = m;
    }

    Connections {
        target: Brightness

        function onCurrentChanged() {
            const v = Brightness.value;
            if (root.lastBrightness >= 0 && Math.abs(v - root.lastBrightness) > 0.001)
                root.show("󰃠", v);
            root.lastBrightness = v;
        }
    }

    // A sink that appears after startup counts as its own first read.
    onSinkChanged: {
        lastVolume = -1;
        lastMuted = -1;
        volumeChanged();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    // Motion state, advanced by the clock.
    property real t: 0                   // ms of motion so far
    property real lastChange: -1e9
    property real level: 0               // eased water level, 0..1
    property real energy: 0              // wave swell from recent changes, 0..1
    property real fade: 0                // capsule opacity
    property real frontPhase: 0          // wave drift, px
    property real backPhase: 0
    // Ripple rings: start times in a ring buffer. A change asks for two;
    // they leave at least 150 ms apart, so key repeats make a steady train
    // instead of restarting the rings each step.
    readonly property int ringLife: 500
    property var rings: [-1e9, -1e9, -1e9, -1e9]
    property int nextRing: 0
    property int pendingRings: 0
    property real lastRing: -1e9

    readonly property bool busy: t - lastChange < 500 || (fade > 0 && fade < 1) || Math.abs(value - level) > 0.003
    property real lastTick: 0

    Timer {
        interval: root.busy ? 50 : 166
        repeat: true
        running: root.shown || root.fade > 0
        onRunningChanged: root.lastTick = Date.now()
        onTriggered: {
            const now = Date.now();
            const dt = Math.min(0.2, Math.max(0, now - root.lastTick) / 1000);
            root.lastTick = now;
            root.t += dt * 1000;
            root.level += (root.value - root.level) * (1 - Math.exp(-dt / 0.09));
            root.energy *= Math.exp(-dt / 0.6);
            root.frontPhase = (root.frontPhase + dt * (5 + 30 * root.energy)) % 26;
            root.backPhase = (root.backPhase + dt * (3 + 18 * root.energy)) % 26;
            root.fade = root.shown ? Math.min(1, root.fade + dt / 0.18) : Math.max(0, root.fade - dt / 0.18);
            if (root.pendingRings > 0 && root.t - root.lastRing >= 150) {
                const r = root.rings.slice();
                r[root.nextRing] = root.t;
                root.rings = r;
                root.nextRing = (root.nextRing + 1) % r.length;
                root.lastRing = root.t;
                root.pendingRings--;
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors.bottom: true
            margins.bottom: 120
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-osd"
            color: "transparent"
            implicitWidth: 56
            implicitHeight: 168
            visible: root.fade > 0
            // Never takes the pointer.
            mask: Region {}

            // The capsule. Its rounded clip comes from cheap rectangular
            // clips: the body is the whole capsule shape cut at the surface,
            // and the waves are cut to the capsule's width at the surface.
            Item {
                id: capsule

                anchors.fill: parent
                opacity: root.fade

                // Water surface, in capsule coordinates.
                readonly property real surface: 166 - root.level * 164
                // Swell: gentle at rest, up to 1.5× after a change; flat when empty.
                readonly property real swell: (0.6 + 0.9 * root.energy) * Math.min(1, root.level * 25)
                readonly property color deep: Theme.primaryContainer
                readonly property color shallow: Theme.primary
                readonly property color back: Qt.tint(Theme.primaryContainer, Qt.alpha(Theme.primary, 0.45))

                // Half the capsule's inner width at height y.
                function halfWidth(y) {
                    const r = 27, d = y < 28 ? 28 - y : (y > 140 ? y - 140 : 0);
                    return Math.sqrt(Math.max(0, r * r - d * d));
                }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.alpha(Theme.surface, 0.88)
                }

                // A wave strip of 26 px periods, drawn once. Its bottom edge
                // (y 14) sits on the water body; it drifts by x and swells by
                // a y scale about that edge.
                component Wave: Shape {
                    id: wave
                    property color fill
                    property real stroke: 0
                    width: 130
                    height: 14
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        strokeWidth: -1
                        fillColor: wave.fill
                        startX: 0
                        startY: 8
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathLine { x: 130; y: 14 }
                        PathLine { x: 0; y: 14 }
                    }

                    // The bright rim along the crest.
                    ShapePath {
                        strokeWidth: wave.stroke
                        strokeColor: wave.stroke > 0 ? Qt.rgba(1, 1, 1, 0.5) : "transparent"
                        fillColor: "transparent"
                        startX: 0
                        startY: 8
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 7; relativeControlY: -6 }
                        PathQuad { relativeX: 13; relativeY: 0; relativeControlX: 6; relativeControlY: 6 }
                    }
                }

                // The waves and ripples, up to 18 px above the body. The clip
                // takes the capsule's narrowest width over the waves' height,
                // and its top corners stay inside the rounded top.
                Item {
                    id: crest
                    readonly property real half: Math.min(capsule.halfWidth(capsule.surface - 12), capsule.halfWidth(capsule.surface + 1))
                    readonly property real base: capsule.surface - y   // the surface, locally
                    clip: true
                    x: 28 - half
                    width: 2 * half
                    y: Math.max(capsule.surface - 18, 28 - Math.sqrt(Math.max(0, 729 - half * half)))
                    height: capsule.surface + 1 - y
                    visible: root.level > 0.005

                    // A darker wave behind, drifting slower, for depth.
                    Wave {
                        fill: capsule.back
                        x: -52 + root.backPhase - crest.x
                        y: crest.base - 17
                        transform: Scale { origin.y: 14; yScale: capsule.swell * 0.8 }
                    }

                    Wave {
                        fill: capsule.shallow
                        stroke: 1
                        x: -root.frontPhase - crest.x
                        y: crest.base - 14
                        transform: Scale { origin.y: 14; yScale: capsule.swell }
                    }

                    // Ripple rings spreading from the middle of the surface.
                    Repeater {
                        model: root.rings.length

                        Rectangle {
                            required property int index
                            readonly property real p: (root.t - root.rings[index]) / root.ringLife
                            readonly property bool alive: p >= 0 && p < 1
                            visible: alive
                            width: alive ? 2 * (8 + 20 * p) : 0
                            height: width * 0.2
                            x: 28 - width / 2 - crest.x
                            // The wave's mean line: 6 px above its base, swollen.
                            y: crest.base - 6 * capsule.swell - height / 2
                            radius: height / 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, alive ? 0.5 * (1 - p) : 0)
                        }
                    }
                }

                // The body: the capsule's shape, cut at the surface. It
                // overlaps the wave's base by a pixel (both are opaque).
                Item {
                    id: body
                    clip: true
                    y: capsule.surface - 1
                    width: parent.width
                    height: Math.max(0, parent.height - y)
                    visible: root.level > 0.005

                    Rectangle {
                        x: 1
                        y: 1 - body.y
                        width: 54
                        height: 166
                        radius: 27
                        gradient: Gradient {
                            GradientStop { position: Math.max(0, (body.y - 1) / 166); color: capsule.shallow }
                            GradientStop { position: 1; color: capsule.deep }
                        }
                    }

                    // A few still bubbles.
                    Repeater {
                        model: [{ x: 18, y: 122, r: 1.6 }, { x: 36, y: 136, r: 1.1 }, { x: 26, y: 108, r: 1 }]

                        Rectangle {
                            required property var modelData
                            x: modelData.x - modelData.r
                            y: modelData.y - modelData.r - body.y
                            width: modelData.r * 2
                            height: width
                            radius: width / 2
                            color: "white"
                            opacity: 0.45
                            visible: modelData.y > capsule.surface + 6
                        }
                    }
                }

                // Glass: the rim, and a faint highlight near the top.
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Theme.primary, 0.35)
                }

                Rectangle {
                    x: 12
                    y: 8
                    width: 32
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.15)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 20
                    text: Math.round(root.value * 100)
                    color: capsule.surface < 30 ? Theme.textOnPrimary : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 138
                    text: root.icon
                    color: capsule.surface < 150 ? Theme.textOnPrimary : Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 5
                }
            }
        }
    }
}
