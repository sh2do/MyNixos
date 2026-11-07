// The python's skin, drawn once as a straight strip for the Serpent bodies
// to bend: u along the body (head end at the left), v across it (the upper
// flank at the top, the belly band at the bottom). The strip is `stripWidth`
// px long and twice the body's width tall; the art inside is laid out in body
// pixels, `bodyLength` long, and stretched to fit, so a scale is the same size
// on screen wherever the strip lands.
//
// The reticulated net: dark diamonds down the back with pale-edged saddles
// inside, and bars down each flank boxing in pale lateral spots. White
// flecks, rows of overlapping scales over it all, and the belly's plates
// along the lower fifth. The bodies' shader adds the rounding, the specular
// line and the iridescent sheen.
import QtQuick
import QtQuick.Shapes
import "." as U

Item {
    id: skin

    property real bodyWidth: 22
    property real bodyLength: 900
    readonly property int stripWidth: 1400

    width: stripWidth
    height: 2 * bodyWidth

    // The pattern, in body pixels: x along, y across (0..bodyWidth).
    readonly property var geo: {
        const L = bodyLength, H = bodyWidth;
        const f = v => v.toFixed(2);
        // A fixed seed: the same python every time.
        let seed = 7;
        const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
        const belly = H * 0.8, dorsal = H * 0.4;
        const dot = (x, y, r) => `M ${f(x - r)} ${f(y)} a ${f(r)} ${f(r)} 0 1 0 ${f(2 * r)} 0 a ${f(r)} ${f(r)} 0 1 0 ${f(-2 * r)} 0 `;

        // The dorsal chain: diamonds sharing their side vertices, uneven in
        // length and height like a real python's.
        const xs = [-6];
        while (xs[xs.length - 1] < L + 6)
            xs.push(xs[xs.length - 1] + 22 + rnd() * 9);
        let net = "", saddles = "", spots = "", flecks = "";
        for (let i = 0; i + 1 < xs.length; i++) {
            const a = xs[i], b = xs[i + 1], m = (a + b) / 2 + (rnd() - 0.5) * 3;
            const top = 0.9 + rnd() * 1.0, bot = belly - 3.4 - rnd() * 1.4;
            const ya = dorsal + (rnd() - 0.5) * 1.6, yb = dorsal + (rnd() - 0.5) * 1.6;
            net += `M ${f(a)} ${f(ya)} L ${f(m)} ${f(top)} L ${f(b)} ${f(yb)} L ${f(m)} ${f(bot)} Z `;
            // The saddle: the diamond pulled in toward its middle.
            const cx = m, cy = (top + bot) / 2, k = 0.7;
            const p = (x, y) => `${f(cx + (x - cx) * k)} ${f(cy + (y - cy) * k)}`;
            saddles += `M ${p(a, ya)} L ${p(m, top)} L ${p(b, yb)} L ${p(m, bot)} Z `;
            // From each shared vertex the net runs down the flank to the
            // belly, boxing in a pale lateral spot under the diamond.
            const lean = (rnd() - 0.5) * 3;
            net += `M ${f(a)} ${f(ya)} L ${f(a + lean)} ${f(belly)} `;
            const sx = m, sy = (bot + belly) / 2 + 0.6;
            spots += `M ${f(sx - 4.2)} ${f(sy)} Q ${f(sx)} ${f(sy - 2.6)} ${f(sx + 4.2)} ${f(sy)} Q ${f(sx)} ${f(sy + 2)} ${f(sx - 4.2)} ${f(sy)} Z `;
            flecks += dot(sx + (rnd() - 0.5), sy - 0.2, 0.6);
            // Flecks where the net meets, and a few scattered on the saddles.
            flecks += dot(a + (rnd() - 0.5) * 1.2, ya - 1.7, 0.5);
            if (rnd() < 0.6)
                flecks += dot(m + (rnd() - 0.5) * 6, cy + (rnd() - 0.5) * 3, 0.35 + rnd() * 0.25);
        }

        // Overlapping scales: staggered rows of arches over the back and
        // flanks, each with a faint pale rim.
        let scales = "", rims = "";
        const sw = 3.6, sh = 3;
        for (let r = 0, y = 0.4; y < belly - 0.5; r++, y += sh) {
            for (let x = (r % 2) * sw / 2 - sw; x < L + sw; x += sw) {
                scales += `M ${f(x)} ${f(y + sh)} Q ${f(x + sw / 2)} ${f(y - 0.5)} ${f(x + sw)} ${f(y + sh)} `;
                rims += `M ${f(x + 0.7)} ${f(y + sh - 0.3)} Q ${f(x + sw / 2)} ${f(y + 0.5)} ${f(x + sw - 0.7)} ${f(y + sh - 0.3)} `;
            }
        }

        // The belly's plates: wide pale bands across the underside.
        let plates = "";
        for (let x = 0; x < L + 3; x += 3.2)
            plates += `M ${f(x)} ${f(belly + 0.3)} Q ${f(x + 0.7)} ${f((belly + H) / 2)} ${f(x)} ${f(H)} `;

        return { net: net, saddles: saddles, spots: spots, flecks: flecks, scales: scales, rims: rims, plates: plates, belly: belly };
    }

    component Lines: ShapePath {
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    Item {
        id: art
        width: skin.bodyLength
        height: skin.bodyWidth
        transform: Scale {
            xScale: skin.stripWidth / skin.bodyLength
            yScale: 2
        }

        Rectangle {
            anchors.fill: parent
            color: U.Palette.pyBody
        }
        Rectangle {
            y: skin.geo.belly
            width: parent.width
            height: parent.height - y
            color: U.Palette.pyBelly
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            Lines {
                strokeColor: Qt.alpha(U.Palette.slate, 0.9)
                strokeWidth: 0.5
                PathSvg { path: skin.geo.plates }
            }
            Lines {
                strokeColor: U.Palette.pyNet
                strokeWidth: 2.2
                PathSvg { path: skin.geo.net }
            }
            // Pale lateral spots, ringed dark.
            ShapePath {
                fillColor: Qt.alpha(U.Palette.pySaddle, 0.85)
                strokeColor: U.Palette.pyNet
                strokeWidth: 0.7
                PathSvg { path: skin.geo.spots }
            }
            ShapePath {
                fillColor: U.Palette.pySaddle
                strokeColor: Qt.alpha(U.Palette.pyFleck, 0.5)
                strokeWidth: 0.5
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: skin.geo.saddles }
            }
            // The scales lie over everything, faint enough to read as texture.
            Lines {
                strokeColor: Qt.alpha("#3a3f48", 0.55)
                strokeWidth: 0.45
                PathSvg { path: skin.geo.scales }
            }
            Lines {
                strokeColor: Qt.alpha(U.Palette.pyFleck, 0.12)
                strokeWidth: 0.3
                PathSvg { path: skin.geo.rims }
            }
            ShapePath {
                fillColor: U.Palette.pyFleck
                strokeColor: "transparent"
                PathSvg { path: skin.geo.flecks }
            }
        }

        // The outline along both edges.
        Rectangle {
            width: parent.width
            height: 0.9
            color: U.Palette.pyOutline
        }
        Rectangle {
            y: parent.height - height
            width: parent.width
            height: 0.9
            color: U.Palette.pyOutline
        }
    }
}
