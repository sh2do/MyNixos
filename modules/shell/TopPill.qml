// The small pill at the top: the song while music plays, otherwise the
// focused window's title. Lives on the Top layer, so fullscreen windows hide it.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property var player: Mpris.players.values.find(p => p.playbackState === MprisPlaybackState.Playing) ?? null
    readonly property bool playing: player !== null
    readonly property string text: playing
        ? [player.trackArtist, player.trackTitle].filter(s => s && s.length).join(" — ")
        : Niri.focusedTitle

    anchors.top: true
    margins.top: 6
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-pill"
    color: "transparent"
    implicitWidth: pill.width
    implicitHeight: 28
    visible: text.length > 0

    Rectangle {
        id: pill
        height: parent.height
        width: Math.min(row.implicitWidth + 28, 520)
        radius: height / 2
        color: Qt.alpha(Theme.surface, 0.82)
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.25)

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: root.playing ? "󰎈" : "󰖯"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: label
                text: root.text
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 520 - 28 - 8 - 16)
                anchors.verticalCenter: parent.verticalCenter

                // Fade between titles instead of snapping.
                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: label; property: "opacity"; to: 0; duration: 75 }
                        PropertyAction {}
                        NumberAnimation { target: label; property: "opacity"; to: 1; duration: 75 }
                    }
                }
            }
        }
    }
}
