// The season's few sprites (season.js): petals, snow or fireflies, drawn as
// plain rounded rectangles and moved only when the owner calls step(dt) on a
// clock it already has (the niri koi's tick, SeasonLayer's 15 Hz Timer).
// With nothing in season there are no sprites and nothing to step. `splash`
// fires where a petal or a flake lands (the pond rings it). Shared by both
// shells (modules/shell/default.nix copies it in).
import QtQuick
import "season.js" as S

Item {
    id: field

    // Season.touch(...), and where the sprites live (season.js's box).
    property var touch: ({ sprite: "", count: 0 })
    property var box: ({ x: 0, y: 0, w: width, h: height, k: 1, drift: 0, land: [0.3, 0.9] })
    property color petal: "#f2c3d1"
    property color snow: "#f3f5fa"
    property color firefly: "#e6f59c"

    signal splash(real x, real y)

    // The sprites (season.js steps them in place), and what is drawn: a
    // fresh copy of each per step, so every binding on it sees the change.
    property var list: []
    property var shown: []
    property string sprite: ""
    readonly property bool active: list.length > 0

    // A new kind or count starts afresh; the same again (Season's minute
    // step) leaves them be.
    onTouchChanged: sync()
    Component.onCompleted: sync()
    function sync() {
        const want = touch?.count > 0 ? touch.sprite : "";
        if (want === sprite && list.length === (want ? touch.count : 0))
            return;
        sprite = want;
        list = want ? S.sprites(touch, box, Math.random) : [];
        shown = list.map(draw);
    }

    function draw(p) {
        return { x: p.x, y: p.y, rot: p.rot, opacity: p.opacity, scale: p.scale };
    }

    function step(dt) {
        for (const p of list) {
            S.step(p, sprite, dt, box, Math.random);
            if (p.splash)
                field.splash(p.x, p.y);
        }
        shown = list.map(draw);
    }

    Repeater {
        model: field.shown.length

        Item {
            id: one
            required property int index
            readonly property var p: field.shown[index] ?? { x: 0, y: 0, rot: 0, opacity: 0, scale: 1 }
            readonly property real k: (field.box.k || 1) * p.scale
            visible: p.opacity > 0.01
            x: p.x
            y: p.y
            opacity: p.opacity

            // A petal: a soft pink oval with a paler streak, turning as it falls.
            Item {
                visible: field.sprite === "petals"
                rotation: one.p.rot
                Rectangle {
                    width: 5.2 * one.k
                    height: 3.2 * one.k
                    x: -width / 2
                    y: -height / 2
                    radius: height / 2
                    color: field.petal
                    antialiasing: true
                }
                Rectangle {
                    width: 2.6 * one.k
                    height: 0.8 * one.k
                    x: -width / 2 + 0.6 * one.k
                    y: -height / 2
                    radius: height / 2
                    color: Qt.alpha("white", 0.45)
                }
            }

            // A flake: a small white dot in a faint halo.
            Rectangle {
                visible: field.sprite === "snow"
                width: 4.4 * one.k
                height: width
                x: -width / 2
                y: -height / 2
                radius: width / 2
                color: Qt.alpha(field.snow, 0.25)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.5
                    height: width
                    radius: width / 2
                    color: field.snow
                }
            }

            // A firefly: a pale green-gold spark in its glow.
            Rectangle {
                visible: field.sprite === "fireflies"
                width: 8 * one.k
                height: width
                x: -width / 2
                y: -height / 2
                radius: width / 2
                color: Qt.alpha(field.firefly, 0.18)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.24
                    height: width
                    radius: width / 2
                    color: field.firefly
                }
            }
        }
    }
}
