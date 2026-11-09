// Rain inside the hydrangea's frame (walls.json `rainRect`) and the slow
// breathing of the mist behind the trees (`glow`). All drawn by rain.frag;
// `time` and `fallen` come from Background's clocks, which only tick while
// live; the rest from the real weather (Weather.scene), today's rain by
// default.
// Fills its parent; the shader's quad covers only the frame.
import QtQuick

Item {
    id: frame

    // Fractions of the screen, from walls.json.
    property var rect
    property var glow
    property real time: 0
    property real fallen: time
    property real amount: 1
    property real slant: 0
    property real fall: 1
    property real mist: 1

    ShaderEffect {
        readonly property real time: frame.time
        readonly property size size: Qt.size(width, height)
        readonly property point glowPos: Qt.point((frame.glow.x - frame.rect.x) * frame.width, (frame.glow.y - frame.rect.y) * frame.height)
        readonly property real glowRadius: frame.glow.r * frame.width
        readonly property real fallen: frame.fallen
        readonly property real amount: frame.amount
        readonly property real slant: frame.slant
        readonly property real fall: frame.fall
        readonly property real mist: frame.mist

        x: frame.rect.x * frame.width
        y: frame.rect.y * frame.height
        width: frame.rect.w * frame.width
        height: frame.rect.h * frame.height
        fragmentShader: "rain.frag.qsb"
    }
}
