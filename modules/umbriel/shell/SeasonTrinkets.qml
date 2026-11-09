// October's trinkets for the raven's hoard (Season.touch().trinkets): a
// small carved pumpkin and a candle, standing on y = 0 from x = 0 rightward
// (about 17 px wide at k = 1). Drawn once; the flame flickers by transform
// and opacity only, from `clock` (seconds of the owner's own clock, so it
// stops when that does), and holds still while `flicker` is false (focus
// mode). `tone` sinks the colours a little toward the shell's own. Shared
// by both shells (modules/shell/default.nix copies it in).
import QtQuick

Item {
    id: root

    property real k: 1
    property real clock: 0
    property bool flicker: true
    property color tone: "#202329"

    width: 17 * k
    height: 12 * k

    // 0..1, how bright the flame is now: two slow waves, smooth even at the
    // raven's 5 Hz idle clock.
    readonly property real glow: flicker ? 0.75 + 0.15 * Math.sin(clock * 2.3) + 0.1 * Math.sin(clock * 3.7 + 1) : 0.8

    function sunk(c) {
        return Qt.tint(c, Qt.alpha(tone, 0.22));
    }

    // The pumpkin: three ribbed lobes, a stem, a carved face lit from inside.
    Item {
        x: 0
        y: -7.4 * root.k
        width: 9.6 * root.k
        height: 7.4 * root.k

        Rectangle {
            x: 0
            y: 0.6 * root.k
            width: 5.4 * root.k
            height: 6.6 * root.k
            radius: width / 2
            color: root.sunk("#b85a1c")
            antialiasing: true
        }
        Rectangle {
            x: 4.2 * root.k
            y: 0.6 * root.k
            width: 5.4 * root.k
            height: 6.6 * root.k
            radius: width / 2
            color: root.sunk("#b85a1c")
            antialiasing: true
        }
        Rectangle {
            x: 2.1 * root.k
            y: 0.3 * root.k
            width: 5.4 * root.k
            height: 7.1 * root.k
            radius: width / 2
            color: root.sunk("#dc7d2b")
            antialiasing: true
        }
        // Stem.
        Rectangle {
            x: 4.3 * root.k
            y: -1.2 * root.k
            width: 1.1 * root.k
            height: 2 * root.k
            radius: 0.4 * root.k
            rotation: 14
            color: root.sunk("#5c6a34")
        }
        // Eyes and a grin, glowing with the candle.
        Repeater {
            model: [3.0, 5.6]
            Rectangle {
                required property real modelData
                x: modelData * root.k
                y: 2.6 * root.k
                width: 1.1 * root.k
                height: 1.1 * root.k
                rotation: 45
                color: "#ffd47a"
                opacity: 0.55 + 0.45 * root.glow
            }
        }
        Rectangle {
            x: 3.2 * root.k
            y: 4.7 * root.k
            width: 3.3 * root.k
            height: 0.8 * root.k
            radius: 0.4 * root.k
            color: "#ffd47a"
            opacity: 0.55 + 0.45 * root.glow
        }
    }

    // The candle: a cream stub, its wick, and a flame in a soft halo.
    Item {
        x: 12 * root.k
        y: 0

        Rectangle {
            x: 0
            y: -6 * root.k
            width: 3 * root.k
            height: 6 * root.k
            radius: 0.6 * root.k
            color: root.sunk("#eadfc6")
            // A drip down its side.
            Rectangle {
                x: 0.3 * root.k
                y: 0
                width: 0.8 * root.k
                height: 2.2 * root.k
                radius: width / 2
                color: Qt.lighter(parent.color, 1.08)
            }
        }
        Rectangle {
            x: 1.25 * root.k
            y: -7 * root.k
            width: 0.5 * root.k
            height: 1.2 * root.k
            color: "#3a3226"
        }
        // The halo.
        Rectangle {
            x: 1.5 * root.k - width / 2
            y: -8.6 * root.k - height / 2
            width: 9 * root.k
            height: width
            radius: width / 2
            color: "#ffcf6b"
            opacity: 0.1 + 0.1 * root.glow
        }
        // The flame, swaying from its foot.
        Item {
            x: 1.5 * root.k
            y: -7 * root.k
            scale: 0.85 + 0.2 * root.glow
            rotation: root.flicker ? 6 * Math.sin(root.clock * 1.9) : 0
            Rectangle {
                x: -0.95 * root.k
                y: -3.4 * root.k
                width: 1.9 * root.k
                height: 3.4 * root.k
                radius: width / 2
                color: "#ffbf4d"
                antialiasing: true
            }
            Rectangle {
                x: -0.45 * root.k
                y: -2 * root.k
                width: 0.9 * root.k
                height: 1.8 * root.k
                radius: width / 2
                color: "#fff3c4"
            }
        }
    }
}
