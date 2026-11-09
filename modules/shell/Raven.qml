// The bar's raven (RICE_MASCOT=raven): perched on the bottom bar pill's top
// edge at its right end, facing along the bar. The art is Umbriel's
// (RavenBody.qml, drawn once; every motion is a transform of its parts), and
// so are its life (RavenLife.qml: the pose, its habits and the caw) and its
// moods (raven-mood.js); all three are copied in from modules/umbriel/shell
// by default.nix. Colours come from the wallpaper (Theme).
//
// Always alive while the bar shows (raven-mood.js times it):
// - breathing, a 1.5% swell of the chest every 4 s, and the faint sheen on
//   its wing and back drifting;
// - a blink of the nictitating membrane every 4-9 s;
// - a tilt or turn of the head every 6-14 s, now and then a double-take;
// - a ruffle every 2-4 min, a preen (beak in the back's feathers, ~2 s)
//   every 5-10 min.
// A pointer resting on the bar is watched after 2 s, and hopped at and
// pecked at after 5. notice(x) (a workspace switch, a volume or brightness
// change) makes it snap its head round to x and caw (silently: two arcs from
// the beak). After dark (21:00-06:00) it fluffs up and sleeps with its head
// tucked in; a notice wakes it for ~20 s.
//
// One clock, a Timer at several rates: every repaint of the bar costs CPU
// whatever changes, so it ticks at 5 Hz for the idle life (its steps are a
// tenth of a pixel), at 30 Hz while the head turns, blinks or preens, and at
// 60 Hz during a hop, a caw or a ruffle. It runs only while the bar is shown.
//
// To the music it bobs its head (about 120 ms: down a few px with a small
// forward tilt, then back) on each bass beat of the shared cava (beat.js,
// the koi's own beat finder), at most twice a second; not asleep (music
// doesn't wake it), nor in a preen, hop, caw, ruffle or look. It holds cava
// only while the bar shows and a player plays; the beats come from cava's
// level changes (no timer), and the bob rides the clock below.
//
// RICE_FAKE_BEAT=1 (or the koi's RICE_KOI_FAKE_BEAT=1) fakes a bass kick
// every 600 ms as though music played, to see it without a player.
//
// In October a carved pumpkin and a candle stand on the rim ahead of it
// (SeasonTrinkets.qml, Season.qml; RICE_SEASON=october to see it).
//
// RICE_RAVEN_DEBUG=1: a ruffle and a preen every 20 s, and night for 30 s of
// every 2 minutes.
import QtQuick
import Quickshell
import "raven-mood.js" as Mood
import "beat.js" as Beat

Item {
    id: root

    // The perch, in this item's coordinates: the line its feet grip (the
    // pill's top edge) and the x of its feet (near the pill's right end).
    property real perchY: 0
    property real homeX: 0
    // How far it may hop along the perch from home, either way (px).
    property real reachLeft: 40
    property real reachRight: 4
    // The pointer over the bar, in this item's coordinates (NaN when it isn't).
    property real hoverX: NaN
    property real hoverY: NaN
    // Where a noticed change happened is level with this y.
    property real noticeY: perchY + 19
    property bool running: false
    // A player is playing (set by the bar).
    property bool music: false

    readonly property bool debug: Quickshell.env("RICE_RAVEN_DEBUG") === "1"

    // The pose and the life (RavenLife.qml), at the bar's 60 Hz for fast
    // motion.
    RavenLife {
        id: life

        fastHz: 60
        // Focus mode puts it to sleep too.
        night: root.night || Focus.on
        debug: root.debug
        k: body.k
        homeX: root.homeX
        perchY: root.perchY
        reachLeft: root.reachLeft
        reachRight: root.reachRight
        pointerX: root.hoverX
        pointerY: root.hoverY
        movedAt: root.movedAt
    }

    // ---- The music.
    readonly property bool fakeBeat: Quickshell.env("RICE_FAKE_BEAT") === "1" || Quickshell.env("RICE_KOI_FAKE_BEAT") === "1"
    // The shared cava runs for us only while the bar is up and music plays.
    readonly property bool listening: running && music && !fakeBeat
    onListeningChanged: {
        listening ? Cava.acquire() : Cava.release();
        beatState = null;
    }
    Component.onDestruction: if (listening) Cava.release()
    property var beatState: null
    property real lastBob: -1e12
    function heard(bass) {
        const now = Date.now();
        const r = Beat.beatStep(beatState, bass, now);
        beatState = r.state;
        if (!r.beat)
            return;
        const s = life.bobState();
        s.sinceBob = now - lastBob;
        if (!Beat.bobAllowed(s))
            return;
        lastBob = now;
        life.bob();
    }
    Connections {
        target: Cava
        enabled: root.listening && Cava.ok
        function onLevelsChanged() {
            root.heard(Cava.levels[0]);
        }
    }
    // The fake beat: cava's 10 Hz frames, a kick every 600 ms (debug only).
    Timer {
        interval: 100
        repeat: true
        running: root.fakeBeat && root.running
        onTriggered: root.heard(Date.now() % 600 < 100 ? 0.85 : 0.15)
    }

    // Something changed at x (level with noticeY): snap the head round to it
    // and caw.
    function notice(x) {
        // Unseen (and it would play late, once the clock runs again).
        if (!running)
            return;
        const d = life.rouse();
        life.busy(4);
        const h = life.headPos();
        const behind = x > h.x + 6;
        const a = Math.min(Math.max(Math.atan2(h.y - noticeY, Math.abs(x - h.x)) * 180 / Math.PI, -40), 20);
        life.turnHead(behind ? -1 : 1, 0.15, d);
        life.tween("headAngle", a, 0.12, d, life.fastHz);
        life.tween("gazeX", behind ? 0.7 : -0.7, 0.12, d, life.fastHz);
        life.tween("gazeY", 0.5, 0.12, d, life.fastHz);
        life.call(d);
        // Then it keeps an eye on the spot a while.
        life.tween("headAngle", 0, 0.5, d + 2.4);
        life.tween("gazeX", 0, 0.4, d + 2.4);
        life.tween("gazeY", 0, 0.4, d + 2.4);
        if (behind)
            life.turnHead(1, 0.25, d + 2.4);
    }

    // The pointer: hover is re-sent with the same position as the window
    // repaints; only a real move counts.
    property real movedAt: 0
    property point lastHover: Qt.point(-1, -1)
    function pointerMoved() {
        if (isNaN(hoverX))
            return;
        if (Math.abs(hoverX - lastHover.x) + Math.abs(hoverY - lastHover.y) >= 1) {
            lastHover = Qt.point(hoverX, hoverY);
            movedAt = Date.now();
        }
    }
    onHoverXChanged: pointerMoved()
    onHoverYChanged: pointerMoved()

    // Night: checked every 30 s while the bar shows (every second in debug,
    // where it is night for 30 s of every 2 minutes).
    property bool night: false
    Timer {
        interval: root.debug ? 1000 : 30000
        repeat: true
        running: root.running
        triggeredOnStart: true
        onTriggered: root.night = root.debug ? (Date.now() / 1000) % 120 < 30 : Mood.isNight(new Date())
    }

    // The clock.
    Timer {
        readonly property int hz: life.need > 0 ? life.need : life.idleHz
        property real last: 0
        running: root.running
        interval: 1000 / Math.max(1, hz)
        repeat: true
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            life.tick(Mood.clockStep((now - last) / 1000, hz));
            last = now;
        }
    }

    // October (Season.qml): a pumpkin and a candle on the rim ahead of it,
    // past the beak (behind the tail the rim already curves down), its
    // little hoard; it draws over them when it hops that way. The flame
    // rides the raven's clock.
    readonly property var season: Season.touch(false)
    SeasonTrinkets {
        visible: root.season.trinkets
        x: root.homeX - 66
        y: root.perchY
        clock: visible ? life.t : 0
        flicker: root.season.flicker
        tone: Theme.surface
    }

    RavenBody {
        id: body
        x: root.homeX + life.hopX - footX
        y: root.perchY - perchY - life.hopY
        size: 44
        // A very dark surface, its feathers edged in a dark slate of the
        // outline (as dark as Umbriel's, so the bird reads black, not grey);
        // the eye's catch-light the text colour; the sheen the wallpaper's
        // accents, deepened so a pale palette doesn't grey the wing.
        bodyColor: Qt.darker(Theme.surface, 1.4)
        edgeColor: Qt.darker(Theme.outline, 2.6)
        beakColor: Theme.surfaceContainer
        eyeColor: Theme.text
        membraneColor: Theme.textMuted
        sheenColors: [Qt.darker(Theme.primary, 1.8), Qt.darker(Qt.tint(Theme.primary, Qt.alpha(Theme.tertiary, 0.5)), 1.8), Qt.darker(Theme.tertiary, 1.8)]
        breath: life.breath
        puff: life.puff
        lean: life.lean
        headAngle: life.headAngle
        headFlip: life.headFlip
        headDrop: life.headDrop
        headTucked: life.headTucked
        beakOpen: life.beakOpen
        hackles: life.hackles
        blink: life.blink
        lid: life.lid
        gazeX: life.gazeX
        gazeY: life.gazeY
        wingLift: life.wingLift
        preen: life.preening
        tailAngle: life.tailAngle
        tuck: life.tuck
        caw: life.caw
        sheen: life.sheen
        sheenShift: life.sheenShift
    }
}
