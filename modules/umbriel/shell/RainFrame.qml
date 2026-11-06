// Rain inside the hydrangea's frame (walls.json `rainRect`) and the slow
// breathing of the mist behind the trees (`glow`). All drawn by rain.frag;
// `time` comes from Background's clock, which only ticks while live.
// Fills its parent; the shader's quad covers only the frame.
import QtQuick

Item {
    id: frame

    // Fractions of the screen, from walls.json.
    property var rect
    property var glow
    property real time: 0

    ShaderEffect {
        readonly property real time: frame.time
        readonly property size size: Qt.size(width, height)
        readonly property point glowPos: Qt.point((frame.glow.x - frame.rect.x) * frame.width, (frame.glow.y - frame.rect.y) * frame.height)
        readonly property real glowRadius: frame.glow.r * frame.width

        x: frame.rect.x * frame.width
        y: frame.rect.y * frame.height
        width: frame.rect.w * frame.width
        height: frame.rect.h * frame.height
        fragmentShader: "rain.frag.qsb"
    }
}
