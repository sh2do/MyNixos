// The python's head, seen from above, drawn once at its real size and moved
// only by transforms. The origin is the neck joint and the snout points +x
// (about 44 px out); the window rotates it into place (Python.qml).
//
// Broad plates, a dark midline and a stripe through each eye, six heat pits
// along each lip, pale irises with radial fibres and a slit pupil, catch-
// lights, nostrils, and a forked tongue that flicks out from under the snout.
// The jaws hinge at the mouth's corner: the upper (the whole head top) swings
// one way, the lower the other, showing the pale lining and small teeth.
//
// dilation: 0 = slit, 1 = wide oval. jaw: 0 shut .. 1 yawning. tongue: 0 in
// .. 1 out; flutter (-1..1) wags its fork. glint: the night catch-light.
// milk: the shed's milky blue eyes (0..1).
import QtQuick
import QtQuick.Shapes
import "." as U

Item {
    id: head

    property real dilation: 0
    property real jaw: 0
    property real tongue: 0
    property real flutter: 0
    property real glint: 0
    property real milk: 0

    readonly property point hinge: Qt.point(4, 0)
    // How far each jaw swings at a full yawn, in degrees.
    readonly property real upperOpen: 24
    readonly property real lowerOpen: 34

    component Lines: ShapePath {
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
    }

    // A soft shadow on the coil, at the bodies' offset.
    Shape {
        x: 3
        y: 5
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 20; centerY: 0; centerRadius: 26
                focalX: 20; focalY: 0
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.4) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
            }
            PathSvg { path: "M -6 0 a 26 15 0 1 0 52 0 a 26 15 0 1 0 -52 0" }
        }
    }

    // The tongue, under everything: it slides out past the snout.
    Shape {
        x: 32 + 16 * head.tongue
        visible: head.tongue > 0.01
        preferredRendererType: Shape.CurveRenderer
        Lines {
            strokeColor: U.Palette.slate
            strokeWidth: 1.1
            PathSvg { path: "M 0 0 L 9 0" }
        }
        Shape {
            x: 9
            rotation: head.flutter * 10
            transformOrigin: Item.TopLeft
            preferredRendererType: Shape.CurveRenderer
            Lines {
                strokeColor: U.Palette.slate
                strokeWidth: 1
                PathSvg { path: "M 0 0 L 4 -2.4 M 0 0 L 4 2.4" }
            }
        }
    }

    // One jaw's half of the open mouth: the pale lining, darker toward the
    // throat, fanned from the jaw's line toward the other jaw. It scales out
    // of that line as the mouth opens, so it is nothing while shut.
    component Mouth: Shape {
        property real side: 1
        property real open: 0
        preferredRendererType: Shape.CurveRenderer
        transform: Scale {
            yScale: open
        }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 38; y2: 0
                GradientStop { position: 0; color: U.Palette.line }
                GradientStop { position: 0.45; color: Qt.tint("#3b3f47", Qt.alpha(U.Palette.pyFleck, 0.55)) }
                GradientStop { position: 1; color: Qt.tint("#3b3f47", Qt.alpha(U.Palette.pyFleck, 0.7)) }
            }
            PathSvg { path: `M 0 0 L 38 0 Q 39 ${-8 * side} 36 ${-16 * side} Z` }
        }
    }

    // A jaw's small teeth, along its inner edge, pointing into the mouth.
    // Shown only as it opens: shut, they would poke past the lips.
    component Teeth: Shape {
        property var edge: []
        property real side: 1
        opacity: Math.min(1, Math.max(0, (head.jaw - 0.1) / 0.3))
        visible: opacity > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: U.Palette.bright
            strokeColor: "transparent"
            PathSvg {
                path: {
                    let p = "";
                    for (const [x, y] of edge)
                        p += `M ${x - 1} ${y} L ${x} ${y - 2.2 * side} L ${x + 1} ${y} Z `;
                    return p;
                }
            }
        }
    }

    // The open mouth, under both jaws: each half swings with its jaw.
    Item {
        rotation: -head.lowerOpen * head.jaw
        transformOrigin: Item.TopLeft
        x: head.hinge.x
        y: head.hinge.y

        Mouth {
            side: -1
            open: Math.tan((head.upperOpen + head.lowerOpen) / 2 * head.jaw * Math.PI / 180) / 0.42
            visible: head.jaw > 0.01
        }
        Teeth {
            x: -head.hinge.x
            side: -1
            edge: [[10, 5.6], [15, 5.3], [20, 4.8], [25, 4.1], [30, 3.2], [34, 2.3]]
        }
    }
    Item {
        rotation: head.upperOpen * head.jaw
        transformOrigin: Item.TopLeft
        x: head.hinge.x
        y: head.hinge.y

        Mouth {
            side: 1
            open: Math.tan((head.upperOpen + head.lowerOpen) / 2 * head.jaw * Math.PI / 180) / 0.42
            visible: head.jaw > 0.01
        }
        Teeth {
            x: -head.hinge.x
            side: 1
            edge: [[10, -12.6], [15, -13], [20, -12.6], [25, -11.5], [30, -9.6], [34, -7.6]]
        }
    }

    // The lower jaw, under the head: hidden by it while shut.
    Item {
        rotation: -head.lowerOpen * head.jaw
        transformOrigin: Item.TopLeft
        x: head.hinge.x
        y: head.hinge.y

        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#3b3f47"
                strokeColor: U.Palette.pyOutline
                strokeWidth: 1
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M -4 -7 C 8 -8 26 -5 37 -1.5 Q 39 0 37 1.5 C 26 4 8 6 -4 6 Z" }
            }
        }
    }

    // The upper jaw: the whole head top.
    Item {
        rotation: head.upperOpen * head.jaw
        transformOrigin: Item.TopLeft
        x: head.hinge.x
        y: head.hinge.y


        Item {
            x: -head.hinge.x
            y: -head.hinge.y

            Shape {
                preferredRendererType: Shape.CurveRenderer

                // The wedge.
                ShapePath {
                    fillColor: U.Palette.pyBody
                    strokeColor: U.Palette.pyOutline
                    strokeWidth: 1.4
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M -2.5 -9 C 7.6 -14.3 24.7 -13.3 36.1 -6.9 Q 43.7 -2.8 44.1 0 Q 43.7 2.8 36.1 6.9 C 24.7 13.3 7.6 14.3 -2.5 9 Q -5 0 -2.5 -9 Z" }
                }
                // A soft pale crown down the middle.
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: 18; centerY: 0; centerRadius: 16
                        focalX: 16; focalY: -2
                        GradientStop { position: 0; color: Qt.alpha(U.Palette.pySaddle, 0.7) }
                        GradientStop { position: 1; color: Qt.alpha(U.Palette.pySaddle, 0) }
                    }
                    PathSvg { path: "M 2 0 a 16 8 0 1 0 32 0 a 16 8 0 1 0 -32 0" }
                }
                // The plates.
                Lines {
                    strokeColor: "#3a3f48"
                    strokeWidth: 0.6
                    PathSvg { path: "M 19 -9.2 Q 28.5 -8.3 37.2 -3.2 M 19 9.2 Q 28.5 8.3 37.2 3.2 M 28.5 -6 L 39 -2.3 L 40.9 0 L 39 2.3 L 28.5 6 Z M 11.4 -6.9 Q 19 -7.8 26.6 -5.5 L 26.6 5.5 Q 19 7.8 11.4 6.9 Z M 39 -2.3 Q 42.2 0 39 2.3 M 34.2 -4.1 L 34.2 4.1" }
                }
                // The midline and the stripes through the eyes.
                Lines {
                    strokeColor: U.Palette.pyNet
                    strokeWidth: 1.1
                    PathSvg { path: "M 0 0 L 37.2 0 M 36 -4.6 L 7.6 -9 M 36 4.6 L 7.6 9" }
                }
                // Heat pits, six along each lip, just inside its edge.
                ShapePath {
                    fillColor: U.Palette.pyOutline
                    strokeColor: "transparent"
                    PathSvg {
                        path: {
                            const lip = [[11.4, -10.6], [15.6, -10.8], [19.8, -10.4], [23.9, -9.6], [28.1, -8.4], [32.3, -6.9]];
                            let p = "";
                            for (const [x, y] of lip)
                                for (const s of [1, -1])
                                    p += `M ${x} ${s * y} m -0.8 0 a 0.8 1.1 0 1 0 1.6 0 a 0.8 1.1 0 1 0 -1.6 0 `;
                            return p;
                        }
                    }
                }
                // Nostrils.
                ShapePath {
                    fillColor: U.Palette.pyOutline
                    strokeColor: "transparent"
                    PathSvg { path: "M 40.9 -1.5 a 0.6 0.6 0 1 0 1.2 0 a 0.6 0.6 0 1 0 -1.2 0 M 40.9 1.5 a 0.6 0.6 0 1 0 1.2 0 a 0.6 0.6 0 1 0 -1.2 0" }
                }
                // The sheen catches the head's upper edge: the only colour.
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 4; y1: 0; x2: 40; y2: 0
                        GradientStop { position: 0; color: Qt.rgba(0.48, 0.64, 1, 0) }
                        GradientStop { position: 0.4; color: Qt.rgba(0.71, 0.55, 1, 0.45) }
                        GradientStop { position: 0.75; color: Qt.rgba(0.49, 1, 0.83, 0.35) }
                        GradientStop { position: 1; color: Qt.rgba(1, 0.82, 0.48, 0) }
                    }
                    PathSvg { path: "M 4 11.4 C 14 13.2 26 12.4 36.5 6.4 C 26 11.4 14 12 4 10.2 Z" }
                }
            }

            Eye { x: 28.4; y: -7.1 }
            Eye { x: 28.4; y: 7.1 }
        }
    }

    // An eye: a dark rim, the iris with fibres radiating from the pupil, the
    // pupil itself (a slit that widens with dilation) and a catch-light.
    component Eye: Item {
        Rectangle {
            x: -3.6; y: -3.6
            width: 7.2; height: 7.2
            radius: 3.6
            color: U.Palette.pyOutline
        }
        Rectangle {
            x: -3; y: -3
            width: 6; height: 6
            radius: 3
            color: Qt.tint(U.Palette.pyEye, Qt.alpha(U.Palette.pyShedEye, head.milk))
        }
        Shape {
            preferredRendererType: Shape.CurveRenderer
            Lines {
                strokeColor: U.Palette.muted
                strokeWidth: 0.4
                PathSvg {
                    path: {
                        let p = "";
                        for (let i = 0; i < 14; i++) {
                            const a = i / 14 * 2 * Math.PI, c = Math.cos(a), s = Math.sin(a);
                            p += `M ${(1.5 * c).toFixed(2)} ${(1.9 * s).toFixed(2)} L ${(2.8 * c).toFixed(2)} ${(2.8 * s).toFixed(2)} `;
                        }
                        return p;
                    }
                }
            }
        }
        Rectangle {
            x: -1.6; y: -2.7
            width: 3.2; height: 5.4
            radius: 1.6
            color: U.Palette.pyOutline
            transform: Scale {
                origin.x: 1.6
                xScale: 0.25 + 0.75 * head.dilation
            }
        }
        // The catch-light, as a curve so it stays crisp at this size.
        Shape {
            preferredRendererType: Shape.CurveRenderer
            opacity: 0.85 + 0.15 * head.glint
            ShapePath {
                fillColor: "white"
                strokeColor: "transparent"
                PathSvg { path: "M -2.05 -1.5 a 0.75 0.75 0 1 0 1.5 0 a 0.75 0.75 0 1 0 -1.5 0" }
            }
        }
        // The night's faint glint round the eye.
        Rectangle {
            x: -6; y: -6
            width: 12; height: 12
            radius: 6
            color: U.Palette.bright
            opacity: 0.08 * head.glint
            visible: head.glint > 0
        }
    }
}
