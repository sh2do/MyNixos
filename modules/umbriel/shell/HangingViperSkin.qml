// The hanging viper's skin, drawn once as a straight strip for its Serpent
// body to bend (HangingViper.qml): u along the body (the neck at the left,
// the tail end, hidden behind the island, at the right), v across it. Laid
// out in body pixels and stretched 2× into the strip.
//
// The desert viper's side view on the detail sheet, in the viper slate:
// irregular dark blotches saddling the back, each with a pale rim and a dark
// spot low on the flank between them; rows of keeled scales over it all,
// each scale an arch with a pale ridge down its middle pointing tailward; a
// faint pale band of belly scales along the lower edge, and the outline.
// The body's shader adds the rounding and the specular line.
import QtQuick
import QtQuick.Shapes
import "." as U

Item {
    id: skin

    property real bodyWidth: 12
    property real bodyLength: 150
    readonly property int stripWidth: Math.ceil(2 * bodyLength)

    width: stripWidth
    height: 2 * bodyWidth

    // The pattern, in body pixels: x along, y across (0..bodyWidth).
    readonly property var geo: {
        const L = bodyLength, H = bodyWidth;
        const f = v => v.toFixed(2);
        // A fixed seed: the same viper every time.
        let seed = 11;
        const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
        const belly = H * 0.84;
        const dot = (x, y, rx, ry) => `M ${f(x - rx)} ${f(y)} a ${f(rx)} ${f(ry)} 0 1 0 ${f(2 * rx)} 0 a ${f(rx)} ${f(ry)} 0 1 0 ${f(-2 * rx)} 0 `;

        // Blotches: the mockup's dash run (7 on, 8 off, 5 on, 10 off) made
        // organic. Each is a saddle, waisted at the midline, its ends rounded
        // over the flanks; between two of them a small dark spot sits low.
        let blotches = "", rims = "", spots = "";
        const runs = [[7, 8], [5, 10]];
        let x = 3 + rnd() * 2;
        for (let i = 0; x < L + 8; i++) {
            const r = runs[i % 2];
            const len = r[0] * (0.85 + rnd() * 0.4);
            const top = 0.9 + rnd() * 0.7, bot = belly - 1.4 - rnd() * 0.8;
            const mid = (top + bot) / 2, waist = len * (0.22 + rnd() * 0.1);
            const a = x, b = x + len, skew = (rnd() - 0.5) * 1.6;
            const path = `M ${f(a)} ${f(mid)} C ${f(a)} ${f(top + 0.6)} ${f(a + 0.8)} ${f(top)} ${f((a + b) / 2 + skew)} ${f(top)} ` +
                `C ${f(b - 0.8)} ${f(top)} ${f(b)} ${f(top + 0.6)} ${f(b - waist * 0.3)} ${f(mid)} ` +
                `C ${f(b)} ${f(bot - 0.6)} ${f(b - 0.8)} ${f(bot)} ${f((a + b) / 2 - skew)} ${f(bot)} ` +
                `C ${f(a + 0.8)} ${f(bot)} ${f(a)} ${f(bot - 0.6)} ${f(a + waist * 0.3)} ${f(mid)} Z `;
            blotches += path;
            rims += path;
            const gap = r[1] * (0.8 + rnd() * 0.4);
            spots += dot(b + gap / 2 + (rnd() - 0.5), belly - 2 - rnd() * 0.6, 1 + rnd() * 0.4, 0.75);
            if (rnd() < 0.5)
                spots += dot(b + gap / 2 + (rnd() - 0.5) * 2, 1.9 + rnd() * 0.5, 0.7, 0.5);
            x = b + gap;
        }

        // Keeled scales: staggered rows of arches, each with its ridge as a
        // short pale dash. The arch opens toward the neck (u = 0), so the
        // scales overlap tailward as on a real snake.
        let scales = "", keels = "";
        const sw = 2.6, sh = 1.75;
        for (let r = 0, y = 0.6; y < belly - 0.4; r++, y += sh) {
            for (let x = (r % 2) * sw / 2 - sw; x < L + sw; x += sw) {
                const j = (rnd() - 0.5) * 0.3;
                scales += `M ${f(x)} ${f(y - sh / 2 + j)} Q ${f(x + sw * 1.05)} ${f(y + j)} ${f(x)} ${f(y + sh / 2 + j)} `;
                keels += `M ${f(x + 0.35)} ${f(y + j)} L ${f(x + sw * 0.7)} ${f(y + j)} `;
            }
        }

        // Belly scales: broad plates across the lower edge.
        let plates = "";
        for (let x = 0; x < L + 2; x += 2.1)
            plates += `M ${f(x)} ${f(belly + 0.2)} Q ${f(x + 0.6)} ${f((belly + H) / 2)} ${f(x)} ${f(H)} `;

        return { blotches: blotches, rims: rims, spots: spots, scales: scales, keels: keels, plates: plates, belly: belly };
    }

    component Lines: ShapePath {
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    Item {
        width: skin.bodyLength
        height: skin.bodyWidth
        transform: Scale {
            xScale: skin.stripWidth / skin.bodyLength
            yScale: 2
        }

        Rectangle {
            anchors.fill: parent
            color: U.Palette.viperBody
        }
        // The belly, a shade paler.
        Rectangle {
            y: skin.geo.belly
            width: parent.width
            height: parent.height - y
            color: Qt.tint(U.Palette.viperBody, Qt.alpha(U.Palette.viperKeel, 0.28))
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            Lines {
                strokeColor: Qt.alpha(U.Palette.viperBlotch, 0.6)
                strokeWidth: 0.35
                PathSvg { path: skin.geo.plates }
            }
            ShapePath {
                fillColor: U.Palette.viperBlotch
                strokeColor: "transparent"
                PathSvg { path: skin.geo.blotches }
            }
            ShapePath {
                fillColor: Qt.alpha(U.Palette.viperBlotch, 0.9)
                strokeColor: "transparent"
                PathSvg { path: skin.geo.spots }
            }
            // The scales lie over everything: dark arches, pale keels.
            Lines {
                strokeColor: Qt.alpha(U.Palette.viperOutline, 0.28)
                strokeWidth: 0.3
                PathSvg { path: skin.geo.scales }
            }
            Lines {
                strokeColor: Qt.alpha(U.Palette.viperKeel, 0.5)
                strokeWidth: 0.32
                PathSvg { path: skin.geo.keels }
            }
            // A pale rim round each blotch, over the scales, so it reads
            // through them.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(U.Palette.viperKeel, 0.35)
                strokeWidth: 0.4
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: skin.geo.rims }
            }
        }

        // The outline along both edges.
        Rectangle {
            width: parent.width
            height: 0.8
            color: U.Palette.viperOutline
        }
        Rectangle {
            y: parent.height - height
            width: parent.width
            height: 0.8
            color: U.Palette.viperOutline
        }
    }
}
