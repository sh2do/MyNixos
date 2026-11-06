// The small pill at the top: the song while music plays, otherwise the
// focused window's title. It stays tucked away above the screen edge and
// drops in for a few seconds when a song starts or changes, or when you
// switch workspace; the pointer over it keeps it down. Lives on the Top
// layer, so fullscreen windows hide it.
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

    // What changes bring it down.
    readonly property string track: player ? [player.trackArtist, player.trackTitle].join("\n") : ""
    readonly property int workspace: Niri.workspaces.find(w => w.isFocused)?.id ?? -1
    onTrackChanged: if (playing) peek()
    onPlayingChanged: if (playing) peek()
    onWorkspaceChanged: peek()

    property bool shown: false
    function peek() {
        shown = true;
        hideTimer.restart();
    }
    Timer {
        id: hideTimer
        interval: 3500
        onTriggered: if (!hover.hovered) root.shown = false
    }

    anchors.top: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-pill"
    color: "transparent"
    implicitWidth: pill.width
    implicitHeight: 34
    visible: text.length > 0
    // Only the pill takes input, and only while it's down.
    mask: Region {
        item: root.shown ? pill : null
    }

    Rectangle {
        id: pill
        y: root.shown ? 6 : -height - 2
        opacity: root.shown ? 1 : 0
        height: 28
        width: Math.min(row.implicitWidth + 28, 520)
        radius: height / 2
        color: Qt.alpha(Theme.surface, 0.82)
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.25)

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 420; easing.type: root.shown ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.4 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 260 }
        }

        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered) hideTimer.restart()
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
