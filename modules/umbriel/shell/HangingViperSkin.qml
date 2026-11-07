// The hanging viper's skin, drawn once as a straight strip for its Serpent
// body to bend (HangingViper.qml): u along the body (the neck at the left,
// the tail end, hidden behind the island, at the right), v across it. Laid
// out in body pixels and stretched 2× into the strip.
//
// The desert viper's side view on the detail sheet, in the viper slate:
// irregular dark blotches saddling the back, each with a pale rim and a dark
// spot low on the flank between them; rows of keeled scales over it all,
// each an almond with a pale ridge down its middle; a pale band of broad
// ventral plates along the lower edge, widening where the S turns (the body
// twists there and shows its belly), and a dark outline that keeps it off a
// pale wallpaper. The body's shader adds the rounding and the specular line.
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
        // The belly's edge: a narrow band, widening where the S turns (the
        // body's two bends, about 14 and 77 px down from the neck).
        const bellyAt = x => H * (0.84 - 0.3 * Math.exp(-Math.pow((x - 77) / 16, 2)) - 0.16 * Math.exp(-Math.pow((x - 13) / 9, 2)));
        const dot = (x, y, rx, ry) => `M ${f(x - rx)} ${f(y)} a ${f(rx)} ${f(ry)} 0 1 0 ${f(2 * rx)} 0 a ${f(rx)} ${f(ry)} 0 1 0 ${f(-2 * rx)} 0 `;

        // Blotches: the mockup's dash run (7 on, 8 off, 5 on, 10 off) made
        // organic. Each is a saddle, waisted at the midline, its ends rounded
        // over the flanks; between two of them a small dark spot sits low.
        let blotches = "", spots = "";
        const runs = [[7, 8], [5, 10]];
        let x = 3 + rnd() * 2;
        for (let i = 0; x < L + 8; i++) {
            const r = runs[i % 2];
            const len = r[0] * (0.85 + rnd() * 0.4);
            const top = 0.9 + rnd() * 0.7, bot = Math.min(bellyAt(x), bellyAt(x + len)) - 1.4 - rnd() * 0.8;
            const mid = (top + bot) / 2, waist = len * (0.22 + rnd() * 0.1);
            const a = x, b = x + len, skew = (rnd() - 0.5) * 1.6;
            blotches += `M ${f(a)} ${f(mid)} C ${f(a)} ${f(top + 0.6)} ${f(a + 0.8)} ${f(top)} ${f((a + b) / 2 + skew)} ${f(top)} ` +
                `C ${f(b - 0.8)} ${f(top)} ${f(b)} ${f(top + 0.6)} ${f(b - waist * 0.3)} ${f(mid)} ` +
                `C ${f(b)} ${f(bot - 0.6)} ${f(b - 0.8)} ${f(bot)} ${f((a + b) / 2 - skew)} ${f(bot)} ` +
                `C ${f(a + 0.8)} ${f(bot)} ${f(a)} ${f(bot - 0.6)} ${f(a + waist * 0.3)} ${f(mid)} Z `;
            const gap = r[1] * (0.8 + rnd() * 0.4);
            const sx = b + gap / 2 + (rnd() - 0.5);
            spots += dot(sx, bellyAt(sx) - 2 - rnd() * 0.6, 1 + rnd() * 0.4, 0.75);
            if (rnd() < 0.5)
                spots += dot(b + gap / 2 + (rnd() - 0.5) * 2, 1.9 + rnd() * 0.5, 0.7, 0.5);
            x = b + gap;
        }

        // Keeled scales: staggered rows of overlapping almonds, each with its
        // ridge as a short pale dash, down to the belly's edge.
        let scales = "", keels = "";
        const sw = 2.6, sh = 1.75;
        for (let r = 0, y = 0.6; y < H; r++, y += sh) {
            for (let x = (r % 2) * sw / 2 - sw; x < L + sw; x += sw) {
                const j = (rnd() - 0.5) * 0.3;
                if (y + j > bellyAt(x + sw / 2) - 0.5)
                    continue;
                scales += `M ${f(x)} ${f(y + j)} Q ${f(x + sw / 2)} ${f(y + j - sh * 0.62)} ${f(x + sw)} ${f(y + j)} Q ${f(x + sw / 2)} ${f(y + j + sh * 0.62)} ${f(x)} ${f(y + j)} `;
                keels += `M ${f(x + 0.55)} ${f(y + j)} L ${f(x + sw - 0.55)} ${f(y + j)} `;
            }
        }

        // The belly: its edge, and the ventral plates across it, each with a
        // pale leading edge.
        let belly = `M 0 ${f(H)} `, plates = "", plateHi = "";
        for (let x = 0; x <= L + 2; x += 1)
            belly += `L ${f(x)} ${f(bellyAt(x))} `;
        belly += `L ${f(L + 2)} ${f(H)} Z`;
        for (let x = 0; x < L + 2; x += 2.1) {
            const y0 = bellyAt(x) + 0.15;
            plates += `M ${f(x)} ${f(y0)} Q ${f(x + 0.7)} ${f((y0 + H) / 2)} ${f(x)} ${f(H)} `;
            plateHi += `M ${f(x + 0.45)} ${f(y0 + 0.3)} Q ${f(x + 1.05)} ${f((y0 + H) / 2)} ${f(x + 0.45)} ${f(H - 0.3)} `;
        }
        let bellyEdge = `M 0 ${f(bellyAt(0))} `;
        for (let x = 1; x <= L + 2; x += 1)
            bellyEdge += `L ${f(x)} ${f(bellyAt(x))} `;

        return { blotches: blotches, spots: spots, scales: scales, keels: keels, belly: belly, bellyEdge: bellyEdge, plates: plates, plateHi: plateHi };
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

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // The ventral plates, pale, each edged dark with a pale lip.
            ShapePath {
                fillColor: Qt.tint(U.Palette.viperBody, Qt.alpha(U.Palette.viperKeel, 0.55))
                strokeColor: "transparent"
                PathSvg { path: skin.geo.belly }
            }
            Lines {
                strokeColor: Qt.alpha(U.Palette.viperKeel, 0.55)
                strokeWidth: 0.35
                PathSvg { path: skin.geo.plateHi }
            }
            Lines {
                strokeColor: Qt.darker(U.Palette.viperBody, 1.25)
                strokeWidth: 0.4
                PathSvg { path: skin.geo.plates }
            }
            Lines {
                strokeColor: Qt.alpha(U.Palette.viperOutline, 0.6)
                strokeWidth: 0.4
                PathSvg { path: skin.geo.bellyEdge }
            }
            // A pale rim round each blotch, under its fill, so it shows as
            // an edging; then the blotches and the spots.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(U.Palette.viperKeel, 0.6)
                strokeWidth: 0.9
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: skin.geo.blotches }
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
            // The scales lie over the back and flanks: dark almonds, pale
            // keels.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(U.Palette.viperOutline, 0.4)
                strokeWidth: 0.28
                PathSvg { path: skin.geo.scales }
            }
            Lines {
                strokeColor: Qt.alpha(Qt.lighter(U.Palette.viperKeel, 1.2), 0.6)
                strokeWidth: 0.34
                PathSvg { path: skin.geo.keels }
            }
        }

        // The outline along both edges.
        Rectangle {
            width: parent.width
            height: 1.1
            color: U.Palette.viperOutline
        }
        Rectangle {
            y: parent.height - height
            width: parent.width
            height: 1.1
            color: U.Palette.viperOutline
        }
    }
}
