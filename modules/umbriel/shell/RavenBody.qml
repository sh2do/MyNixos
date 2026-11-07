// A raven perched on a line, facing left: drawn once (CurveRenderer Shapes)
// as jointed parts that only ever move by transform. Shared by Umbriel's
// corner raven (Raven.qml) and the niri bar's, so it takes every colour as a
// property and knows nothing of either shell.
//
// The art is laid out in design units, 64 from the crown's line to the perch
// line, and scaled to `size` px; the perch line is at `perchY`, the feet at
// `footX`. Parts, back to front: the far leg, the near leg, then the torso
// (the tail fan; the body, with the mantle's sheen; the folded wing:
// coverts, secondaries and five primaries, with its sheen; and the head:
// throat hackles, eye, nictitating membrane and lid, nasal bristles, and
// the upper and lower beak, hinged at the gape). The sheen is the raven's
// own faint blue-violet-green iridescence, the only colour on it.
//
// The pose properties are plain numbers; the owner animates them.
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    // Colours. The darker and lighter tones are derived from these.
    required property color bodyColor
    required property color edgeColor
    required property color beakColor
    required property color eyeColor
    required property color membraneColor
    property list<color> sheenColors: ["#2f4fb8", "#5b3db0", "#23866a"]
    readonly property color deep: Qt.darker(bodyColor, 1.9)
    readonly property color mid: Qt.tint(bodyColor, Qt.alpha(edgeColor, 0.22))
    readonly property color iris: Qt.darker(bodyColor, 3)
    readonly property color beakHi: Qt.tint(beakColor, Qt.alpha(edgeColor, 0.3))

    // Size: px from the crown's line to the perch line.
    property real size: 64
    readonly property real k: size / 64
    readonly property real perchY: 64 * k
    readonly property real footX: 40.8 * k
    implicitWidth: 88 * k
    implicitHeight: 66 * k

    // Pose.
    // Chest swell (1 at rest) and fluffed-up feathers (0 sleek, 0.08 asleep).
    property real breath: 1
    property real puff: 0
    // The whole bird leaning about its feet, degrees (negative: forward).
    property real lean: 0
    // Head: degrees about the neck (positive raises the beak), facing (1
    // forward, -1 turned right round, between: turning), and lowered by
    // `headDrop` design units. `headTucked` puts it under the wing's edge.
    property real headAngle: 0
    property real headFlip: 1
    property real headDrop: 0
    property bool headTucked: false
    // 0 shut, 1 a caw's full gape.
    property real beakOpen: 0
    // Throat hackles raised, 0-1.
    property real hackles: 0
    // The nictitating membrane across the eye, 0-1.
    property real blink: 0
    // The eye shut (asleep), 0-1.
    property real lid: 0
    // Where the eye looks, -1..1 each way.
    property real gazeX: 0
    property real gazeY: 0
    // The wing raised (and its primaries spread) for a flap, 0-1.
    property real wingLift: 0
    // The tail's flick, degrees (positive: down).
    property real tailAngle: 0
    // Legs swung back and toes curled, in the air, 0-1.
    property real tuck: 0
    // The silent caw's two arcs, 0-1 through their spread.
    property real caw: 0
    // The iridescence: opacity, and how far its colours have drifted (0-1).
    property real sheen: 0.16
    property real sheenShift: 0

    // Where something held in the beak goes (it follows the lower mandible).
    readonly property alias beakSlot: slot

    Item {
        id: art
        width: 88
        height: 66
        scale: root.k
        transformOrigin: Item.TopLeft

        // A primary spreads from its base in a flap, the outermost most.
        component Primary: Item {
            required property int index
            transform: Rotation {
                origin.x: 22
                origin.y: 2
                angle: -root.wingLift * (4 - index) * 7
            }
        }

        component Leg: Item {
            transform: Rotation {
                origin.x: 39.4
                origin.y: 54
                angle: root.tuck * 32
            }
        }

        Leg {
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.deep
                    PathSvg { path: "M41.4,53.3 C42.2,56.9 42.8,59.9 43,62.5 L44.7,62.3 C44.4,59.3 43.9,56.1 43.4,53.1 Z" }
                }
                ShapePath {
                    strokeColor: root.deep
                    strokeWidth: 1.15
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M43.8,62.8 C41.8,62.8 39.6,62.9 37.8,63.2" }
                }
                ShapePath {
                    strokeColor: root.deep
                    strokeWidth: 0.62
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M37.8,63.2 C36.7,63.4 36.2,64.2 36.5,65.3" }
                }
                ShapePath {
                    strokeColor: root.deep
                    strokeWidth: 1
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M43.9,62.6 C42.8,62.5 41.6,62.6 40.7,63" }
                }
                ShapePath {
                    strokeColor: root.deep
                    strokeWidth: 0.55
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M40.7,63 C39.9,63.3 39.7,64 40,64.8" }
                }
                ShapePath {
                    strokeColor: root.deep
                    strokeWidth: 1.05
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M44.2,62.9 C45.6,63 46.8,63.1 47.8,63.4" }
                }
                ShapePath {
                    strokeColor: root.deep
                    strokeWidth: 0.58
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M47.8,63.4 C48.7,63.7 48.9,64.4 48.5,65.3" }
                }
            }
        }
        Leg {
            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillColor: root.beakColor
                    PathSvg { path: "M38.4,53.8 C39.2,57.4 39.8,60.4 40,63 L41.7,62.8 C41.4,59.8 40.9,56.6 40.4,53.6 Z" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.5)
                    strokeWidth: 0.28
                    fillColor: "transparent"
                    PathSvg { path: "M39.38,56.4 L40.88,56.15" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.5)
                    strokeWidth: 0.28
                    fillColor: "transparent"
                    PathSvg { path: "M39.64,57.7 L41.14,57.45" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.5)
                    strokeWidth: 0.28
                    fillColor: "transparent"
                    PathSvg { path: "M39.9,59 L41.4,58.75" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.5)
                    strokeWidth: 0.28
                    fillColor: "transparent"
                    PathSvg { path: "M40.16,60.3 L41.66,60.05" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.5)
                    strokeWidth: 0.28
                    fillColor: "transparent"
                    PathSvg { path: "M40.42,61.6 L41.92,61.35" }
                }
                ShapePath {
                    strokeColor: root.beakColor
                    strokeWidth: 1.15
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M40.8,63.3 C38.8,63.3 36.6,63.4 34.8,63.7" }
                }
                ShapePath {
                    strokeColor: root.beakColor
                    strokeWidth: 0.62
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M34.8,63.7 C33.7,63.9 33.2,64.7 33.5,65.8" }
                }
                ShapePath {
                    strokeColor: root.beakColor
                    strokeWidth: 1
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M40.9,63.1 C39.8,63 38.6,63.1 37.7,63.5" }
                }
                ShapePath {
                    strokeColor: root.beakColor
                    strokeWidth: 0.55
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M37.7,63.5 C36.9,63.8 36.7,64.5 37,65.3" }
                }
                ShapePath {
                    strokeColor: root.beakColor
                    strokeWidth: 1.05
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M41.2,63.4 C42.6,63.5 43.8,63.6 44.8,63.9" }
                }
                ShapePath {
                    strokeColor: root.beakColor
                    strokeWidth: 0.58
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M44.8,63.9 C45.7,64.2 45.9,64.9 45.5,65.8" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.6)
                    strokeWidth: 0.3
                    fillColor: "transparent"
                    PathSvg { path: "M40,62.85 C38.4,62.85 36.6,62.95 35,63.25" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.5)
                    strokeWidth: 0.3
                    fillColor: "transparent"
                    PathSvg { path: "M41.6,63 C42.8,63.05 43.8,63.15 44.6,63.4" }
                }
            }
        }

        Item {
            id: torso
            transform: [
                Scale {
                    origin.x: 38
                    origin.y: 55
                    xScale: root.breath + root.puff
                    yScale: 1 + (root.breath - 1) * 0.6 + root.puff * 0.7
                },
                Rotation {
                    origin.x: 40.8
                    origin.y: 63
                    angle: root.lean
                }
            ]

            Item {
                id: tail
                transform: [
                    Rotation {
                        angle: 32.6 + root.tailAngle
                    },
                    Translate {
                        x: 57
                        y: 47
                    }
                ]
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M-2,1.6 C3,3.8 9,4.8 14.5,4.6 C10,6.4 3,6.4 -3,4.4 Z" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: -2; x2: 0; y2: 4
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.55; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M-1,-0.04 C10.33,-0.41 15.99,0.55 21.65,0.55 C22.67,0.55 23.5,1.38 23.5,2.4 C23.5,3.42 22.67,4.25 21.65,4.25 C15.99,4.25 10.33,3.29 -1,2.92 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.55)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M20.54,0.62 L21.65,0.55 C22.67,0.55 23.5,1.38 23.5,2.4 C23.5,3.42 22.67,4.25 21.65,4.25 L19.43,4.21" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.22)
                        strokeWidth: 0.25
                        fillColor: "transparent"
                        PathSvg { path: "M1.45,1.54 L21.28,2.49" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: -2; x2: 0; y2: 4
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.55; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M-1,-0.64 C11.58,-1.01 17.86,-0.45 24.15,-0.45 C25.17,-0.45 26,0.38 26,1.4 C26,2.42 25.17,3.25 24.15,3.25 C17.86,3.25 11.58,2.69 -1,2.32 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.55)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M23.04,-0.38 L24.15,-0.45 C25.17,-0.45 26,0.38 26,1.4 C26,2.42 25.17,3.25 24.15,3.25 L21.93,3.21" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.22)
                        strokeWidth: 0.25
                        fillColor: "transparent"
                        PathSvg { path: "M1.7,0.9 L23.78,1.49" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: -2; x2: 0; y2: 4
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.55; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M-1,-1.24 C12.77,-1.61 19.66,-1.45 26.55,-1.45 C27.57,-1.45 28.4,-0.62 28.4,0.4 C28.4,1.42 27.57,2.25 26.55,2.25 C19.66,2.25 12.77,2.09 -1,1.72 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.55)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M25.44,-1.38 L26.55,-1.45 C27.57,-1.45 28.4,-0.62 28.4,0.4 C28.4,1.42 27.57,2.25 26.55,2.25 L24.33,2.21" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.22)
                        strokeWidth: 0.25
                        fillColor: "transparent"
                        PathSvg { path: "M1.94,0.26 L26.18,0.49" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: -2; x2: 0; y2: 4
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.55; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M-1,-1.84 C13.77,-2.21 21.16,-2.45 28.55,-2.45 C29.57,-2.45 30.4,-1.62 30.4,-0.6 C30.4,0.42 29.57,1.25 28.55,1.25 C21.16,1.25 13.77,1.49 -1,1.12 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.55)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M27.44,-2.38 L28.55,-2.45 C29.57,-2.45 30.4,-1.62 30.4,-0.6 C30.4,0.42 29.57,1.25 28.55,1.25 L26.33,1.21" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.22)
                        strokeWidth: 0.25
                        fillColor: "transparent"
                        PathSvg { path: "M2.14,-0.38 L28.18,-0.51" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.35)
                        strokeWidth: 0.4
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M2,-1.9 C10,-2.4 20,-2.3 28.4,-2.2" }
                    }
                }
            }

            Shape {
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 46; y1: 20; x2: 26; y2: 54
                        GradientStop { position: 0; color: root.mid }
                        GradientStop { position: 0.42; color: root.bodyColor }
                        GradientStop { position: 1; color: root.deep }
                    }
                    PathSvg { path: "M31,16.6 C38.4,17.2 45.4,21.8 51.2,29.8 C55.6,35.8 58.8,41.4 60.8,46.6 L57.6,50.8 C52.2,53.8 46.2,55.6 40.4,55.8 C33.6,56 27.2,52.6 23.6,46.8 C20.4,41.6 19.6,35.2 20.4,30.0 C21.2,25.2 24.6,20.2 31,16.6 Z" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M24.01,27.1 C24.41,28.6 26.61,28.6 27.01,27.1" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M27.41,27.1 C27.81,28.6 30.01,28.6 30.41,27.1" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M30.81,27.1 C31.21,28.6 33.41,28.6 33.81,27.1" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M24.43,30.7 C24.83,32.2 27.03,32.2 27.43,30.7" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M27.83,30.7 C28.23,32.2 30.43,32.2 30.83,30.7" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M31.23,30.7 C31.63,32.2 33.83,32.2 34.23,30.7" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M22.14,34.3 C22.54,35.8 24.74,35.8 25.14,34.3" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M25.54,34.3 C25.94,35.8 28.14,35.8 28.54,34.3" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.21000000000000002)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M28.94,34.3 C29.34,35.8 31.54,35.8 31.94,34.3" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M23.94,37.9 C24.34,39.4 26.54,39.4 26.94,37.9" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M27.34,37.9 C27.74,39.4 29.94,39.4 30.34,37.9" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M30.74,37.9 C31.14,39.4 33.34,39.4 33.74,37.9" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M23.02,41.5 C23.42,43 25.62,43 26.02,41.5" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M26.42,41.5 C26.82,43 29.02,43 29.42,41.5" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M29.82,41.5 C30.22,43 32.42,43 32.82,41.5" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M26.19,45.1 C26.59,46.6 28.79,46.6 29.19,45.1" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M29.59,45.1 C29.99,46.6 32.19,46.6 32.59,45.1" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M26.64,48.7 C27.04,50.2 29.24,50.2 29.64,48.7" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.16)
                    strokeWidth: 0.34
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M30.04,48.7 C30.44,50.2 32.64,50.2 33.04,48.7" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.55)
                    strokeWidth: 0.6
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M33,17.2 C39.6,18.2 45.8,22.6 51.2,30 C55.4,35.8 58.6,41.4 60.6,46.4" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.42)
                    strokeWidth: 0.55
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M23.4,46.4 C20.4,41.4 19.8,35.2 20.6,30.2 C21.0,27.6 22.0,25.4 23.6,23.4" }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 40; y1: 47; x2: 40; y2: 57
                        GradientStop { position: 0; color: root.bodyColor }
                        GradientStop { position: 1; color: root.deep }
                    }
                    PathSvg { path: "M33.6,49.4 C35.8,46.8 41.2,46.4 44.2,49.2 C45.4,51.8 44.8,54.4 43.4,56.4 L42.2,55.2 L41.6,57.4 L40.2,55.8 L39.2,57.6 L38.2,55.6 C36.2,55 34.4,53.2 33.6,49.4 Z" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.3)
                    strokeWidth: 0.3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M37.8,49.8 L38.4,52.8" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.3)
                    strokeWidth: 0.3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M39.8,50.4 L40.4,53.4" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.3)
                    strokeWidth: 0.3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M41.8,50.2 L42.4,53.2" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.3)
                    strokeWidth: 0.3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M38.8,52.4 L39.4,55.4" }
                }
                ShapePath {
                    strokeColor: Qt.alpha(root.edgeColor, 0.3)
                    strokeWidth: 0.3
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    PathSvg { path: "M41,52.6 L41.6,55.6" }
                }
            }
            Shape {
                preferredRendererType: Shape.CurveRenderer
                opacity: root.sheen
                ShapePath {
                    strokeColor: "transparent"
                    fillTransform: PlanarTransform.fromTranslate(root.sheenShift * 28, root.sheenShift * 25)
                    fillGradient: LinearGradient {
                        x1: 30; y1: 17; x2: 58; y2: 42
                        spread: ShapeGradient.ReflectSpread
                        GradientStop { position: 0; color: root.sheenColors[0] }
                        GradientStop { position: 0.45; color: root.sheenColors[1] }
                        GradientStop { position: 1; color: root.sheenColors[2] }
                    }
                    PathSvg { path: "M31,17 C38.4,17.6 45.4,22 51.2,30 C53.8,33.6 55.8,36.8 57.2,39.8 L49,36 C43.6,30.4 37.4,26.2 29.6,24.4 Z" }
                }
            }

            Item {
                id: wing
                z: 2
                transform: [
                    Rotation {
                        angle: 39.7 - root.wingLift * 58
                    },
                    Translate {
                        x: 31
                        y: 24
                    }
                ]

                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: -3; x2: 0; y2: 11
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.5; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M0,-1 C8,-3.6 20,-3.8 32,-2.6 C40,-1.8 47.4,-0.8 53.6,0.2 C50,1.8 46,3.4 41,4.8 C34,7.6 25,10.2 17,10.8 C10,11.2 4,9.6 1,6 C-0.8,4 -1,1.4 0,-1 Z" }
                    }
                }
                Primary {
                    index: 0
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 30; y1: -2; x2: 30; y2: 4
                                GradientStop { position: 0; color: root.mid }
                                GradientStop { position: 0.6; color: root.bodyColor }
                                GradientStop { position: 1; color: root.deep }
                            }
                            PathSvg { path: "M22,-1.02 C35.71,-1.4 42.57,-1.7 49.42,-1.7 C51.89,-1.51 53.13,-0.27 53.6,0.39 C52.94,1.34 51.7,2.1 49.42,2.1 C42.57,2.1 35.71,2.4 22,2.02 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.62)
                            strokeWidth: 0.48
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M45.62,-1.64 L49.42,-1.7 C51.89,-1.51 53.13,-0.27 53.6,0.39" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.2)
                            strokeWidth: 0.24
                            fillColor: "transparent"
                            PathSvg { path: "M25.16,0.47 L49.04,0.3" }
                        }
                    }
                }
                Primary {
                    index: 1
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 30; y1: -2; x2: 30; y2: 4
                                GradientStop { position: 0; color: root.mid }
                                GradientStop { position: 0.6; color: root.bodyColor }
                                GradientStop { position: 1; color: root.deep }
                            }
                            PathSvg { path: "M22.8,-0.33 C34.67,-0.7 40.6,-0.35 46.53,-0.35 C48.94,-0.16 50.14,1.04 50.6,1.69 C49.95,2.61 48.75,3.35 46.53,3.35 C40.6,3.35 34.67,3 22.8,2.63 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.62)
                            strokeWidth: 0.48
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M42.83,-0.29 L46.53,-0.35 C48.94,-0.16 50.14,1.04 50.6,1.69" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.2)
                            strokeWidth: 0.24
                            fillColor: "transparent"
                            PathSvg { path: "M25.58,1.18 L46.16,1.59" }
                        }
                    }
                }
                Primary {
                    index: 2
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 30; y1: -2; x2: 30; y2: 4
                                GradientStop { position: 0; color: root.mid }
                                GradientStop { position: 0.6; color: root.bodyColor }
                                GradientStop { position: 1; color: root.deep }
                            }
                            PathSvg { path: "M23.6,0.31 C33.62,-0.05 38.63,0.9 43.64,0.9 C45.98,1.08 47.15,2.25 47.6,2.88 C46.97,3.78 45.8,4.5 43.64,4.5 C38.63,4.5 33.62,3.55 23.6,3.19 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.62)
                            strokeWidth: 0.48
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M40.04,0.95 L43.64,0.9 C45.98,1.08 47.15,2.25 47.6,2.88" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.2)
                            strokeWidth: 0.24
                            fillColor: "transparent"
                            PathSvg { path: "M26,1.85 L43.28,2.79" }
                        }
                    }
                }
                Primary {
                    index: 3
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 30; y1: -2; x2: 30; y2: 4
                                GradientStop { position: 0; color: root.mid }
                                GradientStop { position: 0.6; color: root.bodyColor }
                                GradientStop { position: 1; color: root.deep }
                            }
                            PathSvg { path: "M24.4,0.85 C32.58,0.5 36.66,1.95 40.75,1.95 C43.03,2.13 44.16,3.26 44.6,3.88 C43.99,4.75 42.85,5.45 40.75,5.45 C36.66,5.45 32.58,4 24.4,3.65 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.62)
                            strokeWidth: 0.48
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M37.25,2 L40.75,1.95 C43.03,2.13 44.16,3.26 44.6,3.88" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.2)
                            strokeWidth: 0.24
                            fillColor: "transparent"
                            PathSvg { path: "M26.42,2.4 L40.4,3.79" }
                        }
                    }
                }
                Primary {
                    index: 4
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 30; y1: -2; x2: 30; y2: 4
                                GradientStop { position: 0; color: root.mid }
                                GradientStop { position: 0.6; color: root.bodyColor }
                                GradientStop { position: 1; color: root.deep }
                            }
                            PathSvg { path: "M25.2,1.29 C31.63,0.95 34.85,2.8 38.06,2.8 C40.27,2.97 41.38,4.08 41.8,4.67 C41.21,5.52 40.1,6.2 38.06,6.2 C34.85,6.2 31.63,4.35 25.2,4.01 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.62)
                            strokeWidth: 0.48
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M34.66,2.85 L38.06,2.8 C40.27,2.97 41.38,4.08 41.8,4.67" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.2)
                            strokeWidth: 0.24
                            fillColor: "transparent"
                            PathSvg { path: "M26.86,2.84 L37.72,4.59" }
                        }
                    }
                }
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 2.4000000000000004; x2: 0; y2: 8.4
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.7; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M23.2,0.2 C30.45,-0.3 34.08,2.9 37.7,2.9 C39.08,2.9 40.2,4.02 40.2,5.4 C40.2,6.78 39.08,7.9 37.7,7.9 C34.08,7.9 30.45,4.7 23.2,4.2 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.46)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M36.2,3 L37.7,2.9 C39.08,2.9 40.2,4.02 40.2,5.4 C40.2,6.78 39.08,7.9 37.7,7.9 L34.7,7.85" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 4.6; x2: 0; y2: 10.6
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.7; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M18.4,2.4 C25.65,1.9 29.28,5.1 32.9,5.1 C34.28,5.1 35.4,6.22 35.4,7.6 C35.4,8.98 34.28,10.1 32.9,10.1 C29.28,10.1 25.65,6.9 18.4,6.4 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.46)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M31.4,5.2 L32.9,5.1 C34.28,5.1 35.4,6.22 35.4,7.6 C35.4,8.98 34.28,10.1 32.9,10.1 L29.9,10.05" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 6; x2: 0; y2: 12
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.7; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M13.4,3.8 C20.65,3.3 24.28,6.5 27.9,6.5 C29.28,6.5 30.4,7.62 30.4,9 C30.4,10.38 29.28,11.5 27.9,11.5 C24.28,11.5 20.65,8.3 13.4,7.8 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.46)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M26.4,6.6 L27.9,6.5 C29.28,6.5 30.4,7.62 30.4,9 C30.4,10.38 29.28,11.5 27.9,11.5 L24.9,11.45" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 6.800000000000001; x2: 0; y2: 12.8
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.7; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M8,4.6 C15.25,4.1 18.88,7.3 22.5,7.3 C23.88,7.3 25,8.42 25,9.8 C25,11.18 23.88,12.3 22.5,12.3 C18.88,12.3 15.25,9.1 8,8.6 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.46)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M21,7.4 L22.5,7.3 C23.88,7.3 25,8.42 25,9.8 C25,11.18 23.88,12.3 22.5,12.3 L19.5,12.25" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 0; y1: 7; x2: 0; y2: 13
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.7; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M2.4,4.8 C9.65,4.3 13.27,7.5 16.9,7.5 C18.28,7.5 19.4,8.62 19.4,10 C19.4,11.38 18.28,12.5 16.9,12.5 C13.27,12.5 9.65,9.3 2.4,8.8 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.46)
                        strokeWidth: 0.45
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M15.4,7.6 L16.9,7.5 C18.28,7.5 19.4,8.62 19.4,10 C19.4,11.38 18.28,12.5 16.9,12.5 L13.9,12.45" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M20.6,-3.04 C26.2,-3.4 29,-2.8 31.8,-2.8 C32.79,-2.8 33.6,-1.99 33.6,-1 C33.6,-0.01 32.79,0.8 31.8,0.8 C29,0.8 26.2,0.2 20.6,-0.16 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.42)
                        strokeWidth: 0.4
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M30.72,-2.73 L31.8,-2.8 C32.79,-2.8 33.6,-1.99 33.6,-1 C33.6,-0.01 32.79,0.8 31.8,0.8 L29.64,0.76" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M14.4,-3.64 C20,-4 22.8,-3.4 25.6,-3.4 C26.59,-3.4 27.4,-2.59 27.4,-1.6 C27.4,-0.61 26.59,0.2 25.6,0.2 C22.8,0.2 20,-0.4 14.4,-0.76 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.42)
                        strokeWidth: 0.4
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M24.52,-3.33 L25.6,-3.4 C26.59,-3.4 27.4,-2.59 27.4,-1.6 C27.4,-0.61 26.59,0.2 25.6,0.2 L23.44,0.16" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M8.4,-4.04 C14,-4.4 16.8,-3.8 19.6,-3.8 C20.59,-3.8 21.4,-2.99 21.4,-2 C21.4,-1.01 20.59,-0.2 19.6,-0.2 C16.8,-0.2 14,-0.8 8.4,-1.16 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.42)
                        strokeWidth: 0.4
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M18.52,-3.73 L19.6,-3.8 C20.59,-3.8 21.4,-2.99 21.4,-2 C21.4,-1.01 20.59,-0.2 19.6,-0.2 L17.44,-0.24" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.mid
                        PathSvg { path: "M23.6,1.2 C26.23,0.85 27.54,1.25 28.85,1.25 C29.82,1.25 30.6,2.03 30.6,3 C30.6,3.97 29.82,4.75 28.85,4.75 C27.54,4.75 26.23,4.35 23.6,4 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.34)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M27.8,1.32 L28.85,1.25 C29.82,1.25 30.6,2.03 30.6,3 C30.6,3.97 29.82,4.75 28.85,4.75 L26.75,4.72" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.mid
                        PathSvg { path: "M20.2,2.6 C22.83,2.25 24.14,2.65 25.45,2.65 C26.42,2.65 27.2,3.43 27.2,4.4 C27.2,5.37 26.42,6.15 25.45,6.15 C24.14,6.15 22.83,5.75 20.2,5.4 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.34)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M24.4,2.72 L25.45,2.65 C26.42,2.65 27.2,3.43 27.2,4.4 C27.2,5.37 26.42,6.15 25.45,6.15 L23.35,6.12" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.mid
                        PathSvg { path: "M16.8,3.8 C19.43,3.45 20.74,3.85 22.05,3.85 C23.02,3.85 23.8,4.63 23.8,5.6 C23.8,6.57 23.02,7.35 22.05,7.35 C20.74,7.35 19.43,6.95 16.8,6.6 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.34)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M21,3.92 L22.05,3.85 C23.02,3.85 23.8,4.63 23.8,5.6 C23.8,6.57 23.02,7.35 22.05,7.35 L19.95,7.32" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.mid
                        PathSvg { path: "M13.4,4.6 C16.02,4.25 17.34,4.65 18.65,4.65 C19.62,4.65 20.4,5.43 20.4,6.4 C20.4,7.37 19.62,8.15 18.65,8.15 C17.34,8.15 16.02,7.75 13.4,7.4 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.34)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M17.6,4.72 L18.65,4.65 C19.62,4.65 20.4,5.43 20.4,6.4 C20.4,7.37 19.62,8.15 18.65,8.15 L16.55,8.12" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.mid
                        PathSvg { path: "M10,5 C12.63,4.65 13.94,5.05 15.25,5.05 C16.22,5.05 17,5.83 17,6.8 C17,7.77 16.22,8.55 15.25,8.55 C13.94,8.55 12.63,8.15 10,7.8 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.34)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M14.2,5.12 L15.25,5.05 C16.22,5.05 17,5.83 17,6.8 C17,7.77 16.22,8.55 15.25,8.55 L13.15,8.52" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.mid
                        PathSvg { path: "M6.6,5 C9.23,4.65 10.54,5.05 11.85,5.05 C12.82,5.05 13.6,5.83 13.6,6.8 C13.6,7.77 12.82,8.55 11.85,8.55 C10.54,8.55 9.23,8.15 6.6,7.8 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.34)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M10.8,5.12 L11.85,5.05 C12.82,5.05 13.6,5.83 13.6,6.8 C13.6,7.77 12.82,8.55 11.85,8.55 L9.75,8.52" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M15.8,-1.36 C17.68,-1.65 18.61,-1.25 19.55,-1.25 C20.35,-1.25 21,-0.6 21,0.2 C21,1 20.35,1.65 19.55,1.65 C18.61,1.65 17.68,1.25 15.8,0.96 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.3)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M18.68,-1.19 L19.55,-1.25 C20.35,-1.25 21,-0.6 21,0.2 C21,1 20.35,1.65 19.55,1.65 L17.81,1.62" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M12.8,0.04 C14.68,-0.25 15.61,0.15 16.55,0.15 C17.35,0.15 18,0.8 18,1.6 C18,2.4 17.35,3.05 16.55,3.05 C15.61,3.05 14.68,2.65 12.8,2.36 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.3)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M15.68,0.21 L16.55,0.15 C17.35,0.15 18,0.8 18,1.6 C18,2.4 17.35,3.05 16.55,3.05 L14.81,3.02" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M9.8,1.24 C11.68,0.95 12.61,1.35 13.55,1.35 C14.35,1.35 15,2 15,2.8 C15,3.6 14.35,4.25 13.55,4.25 C12.61,4.25 11.68,3.85 9.8,3.56 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.3)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M12.68,1.41 L13.55,1.35 C14.35,1.35 15,2 15,2.8 C15,3.6 14.35,4.25 13.55,4.25 L11.81,4.22" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M6.8,2.04 C8.68,1.75 9.61,2.15 10.55,2.15 C11.35,2.15 12,2.8 12,3.6 C12,4.4 11.35,5.05 10.55,5.05 C9.61,5.05 8.68,4.65 6.8,4.36 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.3)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M9.68,2.21 L10.55,2.15 C11.35,2.15 12,2.8 12,3.6 C12,4.4 11.35,5.05 10.55,5.05 L8.81,5.02" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M3.8,2.44 C5.68,2.15 6.61,2.55 7.55,2.55 C8.35,2.55 9,3.2 9,4 C9,4.8 8.35,5.45 7.55,5.45 C6.61,5.45 5.68,5.05 3.8,4.76 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.3)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M6.68,2.61 L7.55,2.55 C8.35,2.55 9,3.2 9,4 C9,4.8 8.35,5.45 7.55,5.45 L5.81,5.42" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M1,2.64 C2.88,2.35 3.81,2.75 4.75,2.75 C5.55,2.75 6.2,3.4 6.2,4.2 C6.2,5 5.55,5.65 4.75,5.65 C3.81,5.65 2.88,5.25 1,4.96 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.3)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M3.88,2.81 L4.75,2.75 C5.55,2.75 6.2,3.4 6.2,4.2 C6.2,5 5.55,5.65 4.75,5.65 L3.01,5.62" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M9.4,-2.92 C10.63,-3.15 11.24,-2.75 11.85,-2.75 C12.48,-2.75 13,-2.23 13,-1.6 C13,-0.97 12.48,-0.45 11.85,-0.45 C11.24,-0.45 10.63,-0.85 9.4,-1.08 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.26)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M11.16,-2.7 L11.85,-2.75 C12.48,-2.75 13,-2.23 13,-1.6 C13,-0.97 12.48,-0.45 11.85,-0.45 L10.47,-0.47" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M6.8,-1.92 C8.03,-2.15 8.64,-1.75 9.25,-1.75 C9.88,-1.75 10.4,-1.23 10.4,-0.6 C10.4,0.03 9.88,0.55 9.25,0.55 C8.64,0.55 8.03,0.15 6.8,-0.08 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.26)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M8.56,-1.7 L9.25,-1.75 C9.88,-1.75 10.4,-1.23 10.4,-0.6 C10.4,0.03 9.88,0.55 9.25,0.55 L7.87,0.53" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M4.2,-0.92 C5.43,-1.15 6.04,-0.75 6.65,-0.75 C7.28,-0.75 7.8,-0.23 7.8,0.4 C7.8,1.03 7.28,1.55 6.65,1.55 C6.04,1.55 5.43,1.15 4.2,0.92 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.26)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M5.96,-0.7 L6.65,-0.75 C7.28,-0.75 7.8,-0.23 7.8,0.4 C7.8,1.03 7.28,1.55 6.65,1.55 L5.27,1.53" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M1.6,-0.12 C2.83,-0.35 3.44,0.05 4.05,0.05 C4.68,0.05 5.2,0.57 5.2,1.2 C5.2,1.83 4.68,2.35 4.05,2.35 C3.44,2.35 2.83,1.95 1.6,1.72 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.26)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M3.36,0.1 L4.05,0.05 C4.68,0.05 5.2,0.57 5.2,1.2 C5.2,1.83 4.68,2.35 4.05,2.35 L2.67,2.33" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M-0.8,0.48 C0.42,0.25 1.04,0.65 1.65,0.65 C2.28,0.65 2.8,1.17 2.8,1.8 C2.8,2.43 2.28,2.95 1.65,2.95 C1.04,2.95 0.42,2.55 -0.8,2.32 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.26)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M0.96,0.7 L1.65,0.65 C2.28,0.65 2.8,1.17 2.8,1.8 C2.8,2.43 2.28,2.95 1.65,2.95 L0.27,2.93" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M6.8,-3.92 C8.03,-4.15 8.64,-3.75 9.25,-3.75 C9.88,-3.75 10.4,-3.23 10.4,-2.6 C10.4,-1.97 9.88,-1.45 9.25,-1.45 C8.64,-1.45 8.03,-1.85 6.8,-2.08 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.26)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M8.56,-3.7 L9.25,-3.75 C9.88,-3.75 10.4,-3.23 10.4,-2.6 C10.4,-1.97 9.88,-1.45 9.25,-1.45 L7.87,-1.47" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.bodyColor
                        PathSvg { path: "M3.2,-2.72 C4.43,-2.95 5.04,-2.55 5.65,-2.55 C6.28,-2.55 6.8,-2.03 6.8,-1.4 C6.8,-0.77 6.28,-0.25 5.65,-0.25 C5.04,-0.25 4.43,-0.65 3.2,-0.88 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.26)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M4.96,-2.5 L5.65,-2.55 C6.28,-2.55 6.8,-2.03 6.8,-1.4 C6.8,-0.77 6.28,-0.25 5.65,-0.25 L4.27,-0.27" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.5)
                        strokeWidth: 0.55
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M0.2,-1.2 C6,-3.2 14,-3.8 22,-3.4" }
                    }
                }
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    opacity: root.sheen
                    ShapePath {
                        strokeColor: "transparent"
                        fillTransform: PlanarTransform.fromTranslate(root.sheenShift * 54, root.sheenShift * 16)
                        fillGradient: LinearGradient {
                            x1: 0; y1: -4; x2: 54; y2: 12
                            spread: ShapeGradient.ReflectSpread
                            GradientStop { position: 0; color: root.sheenColors[0] }
                            GradientStop { position: 0.45; color: root.sheenColors[1] }
                            GradientStop { position: 1; color: root.sheenColors[2] }
                        }
                        PathSvg { path: "M0,-1 C8,-3.6 20,-3.8 32,-2.6 C40,-1.8 47.4,-0.8 53.6,0.2 C50,1.8 46,3.4 41,4.8 C34,7.6 25,10.2 17,10.8 C10,11.2 4,9.6 1,6 C-0.8,4 -1,1.4 0,-1 Z" }
                    }
                }
            }

            Item {
                id: head
                z: root.headTucked ? 1 : 3
                transform: [
                    Scale {
                        origin.x: 31
                        origin.y: 21
                        xScale: root.headFlip
                    },
                    Rotation {
                        origin.x: 31
                        origin.y: 21
                        angle: root.headAngle
                    },
                    Translate {
                        y: root.headDrop
                    }
                ]

                Item {
                    transform: Scale {
                        origin.x: 21
                        origin.y: 21
                        xScale: 1 + root.hackles * 0.12
                        yScale: 1 + root.hackles * 0.3
                    }
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 22; y1: 20; x2: 24; y2: 32
                                GradientStop { position: 0; color: root.bodyColor }
                                GradientStop { position: 1; color: root.deep }
                            }
                            PathSvg { path: "M17.8,19.4 C17.0,21.0 16.8,22.8 17.2,24.6 L18.3,23.6 C18.1,25.2 18.2,26.6 18.8,28.2 L19.8,26.8 C20.0,28.2 20.5,29.6 21.3,30.8 L22.1,29.2 C22.7,30.5 23.4,31.4 24.4,32.2 L24.8,30.2 C25.6,31.0 26.6,31.5 27.7,31.7 L27.4,29.6 C28.4,29.8 29.5,29.6 30.4,29.1 L30.8,25 C26.2,24.8 21.6,22.8 17.8,19.4 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.5)
                            strokeWidth: 0.34
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M18.6,21 Q17.8,22.6 17.6,24.2" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.5)
                            strokeWidth: 0.34
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M19.8,22.2 Q18.95,25 18.7,27.8" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.5)
                            strokeWidth: 0.34
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M21.2,23.2 Q20.9,26.8 21.2,30.4" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.5)
                            strokeWidth: 0.34
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M23,24 Q23.3,27.9 24.2,31.8" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.5)
                            strokeWidth: 0.34
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M25,24.6 Q25.9,27.95 27.4,31.3" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.5)
                            strokeWidth: 0.34
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M27.2,25 Q28.3,26.95 30,28.9" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.45)
                            strokeWidth: 0.36
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M17.2,24.6 L18.3,23.6 C18.1,25.2 18.2,26.6 18.8,28.2 L19.8,26.8 C20.0,28.2 20.5,29.6 21.3,30.8 L22.1,29.2 C22.7,30.5 23.4,31.4 24.4,32.2 L24.8,30.2 C25.6,31.0 26.6,31.5 27.7,31.7 L27.4,29.6 C28.4,29.8 29.5,29.6 30.4,29.1" }
                        }
                    }
                }
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: LinearGradient {
                            x1: 27; y1: 4.5; x2: 25; y2: 26
                            GradientStop { position: 0; color: root.mid }
                            GradientStop { position: 0.45; color: root.bodyColor }
                            GradientStop { position: 1; color: root.deep }
                        }
                        PathSvg { path: "M17.2,9.8 C18.2,6.8 21.2,4.9 24.8,4.9 C28.8,4.9 32.4,6.6 34.4,9.8 C36.0,12.4 36.8,16.0 36.4,19.6 L31,27 C27.2,27.6 23.2,27 20.8,24.4 C18.9,22.4 17.8,20 17.4,17.6 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.62)
                        strokeWidth: 0.6
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M18.6,7.6 C20.4,5.8 22.6,5.1 24.8,5.1 C28.8,5.1 32.3,6.8 34.2,9.9 C35.6,12.2 36.3,15 36.3,18" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M22.9,6.9 C23.38,8.1 25.62,8.1 26.1,6.9" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M26.3,7.3 C26.81,8.5 29.19,8.5 29.7,7.3" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M29.6,9.1 C30.08,10.3 32.32,10.3 32.8,9.1" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M25,9.3 C25.42,10.5 27.38,10.5 27.8,9.3" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M28.1,11.3 C28.55,12.5 30.65,12.5 31.1,11.3" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M31.1,12.7 C31.55,13.9 33.65,13.9 34.1,12.7" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M26.2,14.1 C26.62,15.3 28.58,15.3 29,14.1" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M29.1,15.9 C29.55,17.1 31.65,17.1 32.1,15.9" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M32.2,16.7 C32.62,17.9 34.58,17.9 35,16.7" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.2)
                        strokeWidth: 0.3
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M23.9,16.3 C24.29,17.5 26.11,17.5 26.5,16.3" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.5)
                        strokeWidth: 0.42
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        PathSvg { path: "M19.2,9.1 C21,7.9 23.6,7.7 25.8,8.7" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Qt.alpha(root.deep, 0.7)
                        PathSvg { path: "M19.6,11.1 C19.6,9.5 21,8.6 22.4,8.6 C24,8.6 25.2,9.7 25.2,11.1 C25.2,12.6 24,13.6 22.4,13.6 C20.9,13.6 19.6,12.6 19.6,11.1 Z" }
                    }
                }
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.iris
                        PathSvg { path: "M20.85,11 a1.55,1.55 0 1,0 3.1,0 a1.55,1.55 0 1,0 -3.1,0 Z" }
                    }
                    ShapePath {
                        strokeColor: Qt.alpha(root.edgeColor, 0.8)
                        strokeWidth: 0.36
                        fillColor: "transparent"
                        PathSvg { path: "M20.85,11 a1.55,1.55 0 1,0 3.1,0 a1.55,1.55 0 1,0 -3.1,0 Z" }
                    }
                }
                Item {
                    transform: Translate {
                        x: root.gazeX * 0.45
                        y: root.gazeY * 0.35
                    }
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: root.eyeColor
                            PathSvg { path: "M21.3,10.45 a0.52,0.52 0 1,0 1.04,0 a0.52,0.52 0 1,0 -1.04,0 Z" }
                        }
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: Qt.alpha(root.eyeColor, 0.5)
                            PathSvg { path: "M23.1,11.75 a0.22,0.22 0 1,0 0.44,0 a0.22,0.22 0 1,0 -0.44,0 Z" }
                        }
                    }
                }
                Item {
                    visible: root.blink > 0
                    transform: Scale {
                        origin.x: 20.85
                        origin.y: 11
                        xScale: root.blink
                        yScale: Math.sqrt(root.blink * (2 - root.blink))
                    }
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: Qt.alpha(root.membraneColor, 0.92)
                            PathSvg { path: "M20.85,11 a1.55,1.55 0 1,0 3.1,0 a1.55,1.55 0 1,0 -3.1,0 Z" }
                        }
                    }
                }
Item {
                    visible: root.lid > 0
                    opacity: root.lid
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: root.mid
                            PathSvg { path: "M20.7,11 a1.7,1.7 0 1,0 3.4,0 a1.7,1.7 0 1,0 -3.4,0 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.7)
                            strokeWidth: 0.4
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M20.9,11.1 C21.8,11.9 23.1,11.9 23.9,11.1" }
                        }
                    }
                }
                Shape {
                    preferredRendererType: Shape.CurveRenderer
                    visible: root.beakOpen > 0
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: root.deep
                        PathSvg { path: "M18.6,15.8 L7,17.6 L4.8,19.4 L18.6,17.6 Z" }
                    }
                }
                Item {
                    transform: Rotation {
                        origin.x: 18.4
                        origin.y: 16.5
                        angle: -root.beakOpen * 27
                    }
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 10; y1: 16.5; x2: 10; y2: 20.5
                                GradientStop { position: 0; color: root.beakColor }
                                GradientStop { position: 1; color: root.deep }
                            }
                            PathSvg { path: "M18.6,16.5 C13.8,16.7 9.4,17.6 5.6,19.0 C4.9,19.3 4.7,19.8 5.1,20.1 C8.7,20.8 13.3,20.5 18.2,19.7 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.45)
                            strokeWidth: 0.35
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M17.6,19.6 C13,20.3 8.7,20.6 5.6,20.0" }
                        }
                    }
                    Item {
                        id: slot
                        x: 4.6
                        y: 18.6
                    }
                }
                Item {
                    transform: Rotation {
                        origin.x: 18.4
                        origin.y: 16.5
                        angle: root.beakOpen * 7
                    }
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillGradient: LinearGradient {
                                x1: 10; y1: 10; x2: 10; y2: 18
                                GradientStop { position: 0; color: root.beakHi }
                                GradientStop { position: 0.5; color: root.beakColor }
                                GradientStop { position: 1; color: root.deep }
                            }
                            PathSvg { path: "M17.6,9.5 C13.4,9.7 8.6,11.5 5.0,14.9 C3.6,16.3 2.6,17.8 2.3,19.3 C2.2,20.1 2.8,20.5 3.4,19.9 C3.8,19.4 4.4,19.0 5.2,18.7 C9.0,17.3 13.4,16.5 18.4,16.3 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.75)
                            strokeWidth: 0.5
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M17,9.95 C12.8,10.3 8.4,12.1 5.0,15.3 C3.9,16.4 3.1,17.6 2.7,18.7" }
                        }
                        ShapePath {
                            strokeColor: root.deep
                            strokeWidth: 0.4
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M18.3,16.3 C13.4,16.5 9.0,17.3 5.2,18.7 C4.4,19.0 3.8,19.4 3.4,19.9" }
                        }
                    }
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: root.bodyColor
                            PathSvg { path: "M18.8,9.2 Q14.4,9.3 10.6,11.1 Q14.6,10.25 18.8,10.45 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.55)
                            strokeWidth: 0.26
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M18.4,9.5 Q14.4,9.6 10.6,11.1" }
                        }
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: root.bodyColor
                            PathSvg { path: "M18.8,9.95 Q14.4,10.05 11.9,11.95 Q14.6,11 18.8,11.2 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.55)
                            strokeWidth: 0.26
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M18.4,10.25 Q14.4,10.35 11.9,11.95" }
                        }
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: root.bodyColor
                            PathSvg { path: "M18.8,10.7 Q14.4,10.8 13.2,12.8 Q14.6,11.75 18.8,11.95 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.55)
                            strokeWidth: 0.26
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M18.4,11 Q14.4,11.1 13.2,12.8" }
                        }
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: root.bodyColor
                            PathSvg { path: "M18.8,11.45 Q14.4,11.55 14.5,13.65 Q14.6,12.5 18.8,12.7 Z" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.edgeColor, 0.55)
                            strokeWidth: 0.26
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M18.4,11.75 Q14.4,11.85 14.5,13.65" }
                        }
                    }
                }
                Item {
                    visible: root.caw > 0 && root.caw < 1
                    opacity: Math.sin(Math.PI * root.caw)
                    transform: [
                        Scale {
                            origin.x: 2
                            origin.y: 18
                            xScale: 0.6 + 0.7 * root.caw
                            yScale: 0.6 + 0.7 * root.caw
                        },
                        Translate {
                            x: -3 * root.caw
                        }
                    ]
                    Shape {
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: Qt.alpha(root.eyeColor, 0.9)
                            strokeWidth: 0.7
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M-1.2,14.6 C-2.6,16.2 -2.8,18.6 -1.6,20.4" }
                        }
                        ShapePath {
                            strokeColor: Qt.alpha(root.eyeColor, 0.6)
                            strokeWidth: 0.7
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathSvg { path: "M-4.4,12.6 C-6.6,15.4 -6.8,19.2 -5.0,22.2" }
                        }
                    }
                }
            }
        }
    }
}
