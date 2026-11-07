// The small pill at the top. While music plays it is a 40 px media pill: the
// album art with a glow in its colour, title and artist, a 5-bar visualiser
// (cava, only while the pill is down) and a progress line; hovering swaps the
// text for previous / play-pause / next. Otherwise it shows the focused
// window's title. It stays tucked away above the screen edge and drops in for
// a few seconds when a song starts or changes, or when you switch workspace;
// the pointer over it keeps it down. Lives on the Top layer, so fullscreen
// windows hide it.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "media.js" as Media

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property var player: Mpris.players.values.find(p => p.playbackState === MprisPlaybackState.Playing) ?? null
    readonly property bool playing: player !== null
    readonly property string text: playing
        ? [player.trackArtist, player.trackTitle].filter(s => s && s.length).join(" — ")
        : Niri.focusedTitle
    readonly property var lines: playing ? Media.fmtArtist(player.trackTitle, player.trackArtist, player.trackAlbum) : ({ top: "", bottom: "" })
    readonly property string artUrl: playing ? (player.trackArtUrl ?? "") : ""
    readonly property bool hovered: hover.hovered

    // What changes bring it down.
    readonly property string track: player ? [player.trackArtist, player.trackTitle].join("\n") : ""
    readonly property int workspace: Niri.workspaces.find(w => w.isFocused)?.id ?? -1
    onTrackChanged: {
        cavaOk = true;
        if (playing)
            peek();
    }
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
        onTriggered: if (!root.hovered) root.shown = false
    }

    // Room around the pill for the art's glow.
    readonly property int pad: 24
    anchors.top: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-pill"
    color: "transparent"
    implicitWidth: pill.width + 2 * pad
    implicitHeight: playing ? 64 : 34
    visible: text.length > 0
    // Only the pill takes input, and only while it's down.
    mask: Region {
        item: root.shown ? pill : null
    }

    // ---- The visualiser: cava's raw output, only while it plays and shows.
    readonly property int bars: 5
    readonly property bool live: playing && shown
    property var levels: Media.parseCava("", bars)
    // False once cava has failed for this track; then the bars pulse gently.
    property bool cavaOk: true
    function setLevels(v) {
        if (v.some((x, i) => Math.abs(x - levels[i]) > 0.01))
            levels = v;
    }
    onLiveChanged: if (!live) levels = Media.parseCava("", bars)

    Process {
        id: cava
        running: root.live && root.cavaOk
        command: ["sh", "-c", [
            'f="${XDG_RUNTIME_DIR:-/tmp}/rice-pill-cava.conf"',
            'printf "%s\\n" "[general]" "framerate = 10" "bars = ' + root.bars + '" ' +
                '"[output]" "method = raw" "raw_target = /dev/stdout" "data_format = ascii" ' +
                '"ascii_max_range = ' + Media.CAVA_MAX + '" "bar_delimiter = 59" "frame_delimiter = 10" "channels = mono" > "$f"',
            'exec cava -p "$f"'
        ].join("\n")]
        stdout: SplitParser {
            onRead: data => root.setLevels(Media.parseCava(data, root.bars))
        }
        // Exiting while still wanted means cava is missing or broken.
        onExited: if (root.live) root.cavaOk = false
    }

    // Without cava: a pulse that follows the playback position.
    property real pulseT: 0
    Timer {
        interval: 100
        repeat: true
        running: root.live && !root.cavaOk
        onTriggered: {
            root.pulseT += interval / 1000;
            root.setLevels(Media.pulse(root.pulseT, root.bars));
        }
    }

    // Mpris only refreshes the position when asked.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.live
        onTriggered: {
            root.player.positionChanged();
            root.pulseT = root.player.position;
        }
    }
    readonly property real progress: playing ? Media.progress(player.position, player.length) : 0

    // ---- The glow: the art's colour, sampled once per track (local art only).
    ColorQuantizer {
        id: quant
        source: root.artUrl.startsWith("file://") ? root.artUrl : ""
        depth: 0
        rescaleSize: 16
    }
    readonly property color glowColour: {
        const c = quant.colors.length ? quant.colors[0] : null;
        if (!c || !root.artUrl.startsWith("file://"))
            return Theme.primary;
        // Lift dark or grey art so the glow still reads on a dark wall.
        return Qt.hsla(c.hslHue < 0 ? 0 : c.hslHue, Math.max(c.hslSaturation, 0.35), Math.max(c.hslLightness, 0.62), 1);
    }

    Rectangle {
        id: pill
        x: root.pad
        y: root.shown ? 6 : -height - 2
        opacity: root.shown ? 1 : 0
        height: root.playing ? 40 : 28
        width: root.playing
            ? Math.max(300, Math.min(480, Math.ceil(Math.max(titleSize.advanceWidth, artistSize.advanceWidth)) + 44 + 16 + 27 + 22))
            : Math.min(row.implicitWidth + 28, 520)
        radius: height / 2
        color: Qt.alpha(Theme.surface, root.playing ? 0.84 : 0.82)
        border.width: 1
        border.color: Qt.alpha(Theme.primary, root.playing ? 0.28 : 0.25)

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 420; easing.type: root.shown ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.4 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 260 }
        }

        // The text's natural widths (the Texts themselves elide to the pill).
        TextMetrics {
            id: titleSize
            text: root.lines.top
            font: title.font
        }
        TextMetrics {
            id: artistSize
            text: root.lines.bottom
            font: artist.font
        }

        HoverHandler {
            id: hover
            onHoveredChanged: if (!hovered) hideTimer.restart()
        }

        // ---- No music: the focused window's title.
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            visible: !root.playing

            Text {
                text: "󰖯"
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: label
                text: root.playing ? "" : root.text
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

        // ---- Music: the media pill.
        Item {
            anchors.fill: parent
            visible: root.playing

            // Behind the pill (negative z draws under the parent), centred on the art.
            Shape {
                z: -1
                x: 20 - width / 2
                y: 20 - height / 2
                width: 84
                height: 84
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: RadialGradient {
                        centerX: 42; centerY: 42; centerRadius: 42
                        focalX: 42; focalY: 42
                        GradientStop { position: 0; color: Qt.alpha(root.glowColour, 0.45) }
                        GradientStop { position: 0.45; color: Qt.alpha(root.glowColour, 0.22) }
                        GradientStop { position: 1; color: Qt.alpha(root.glowColour, 0) }
                    }
                    PathRectangle { x: 0; y: 0; width: 84; height: 84 }
                }
            }

            // A faint highlight along the top rim.
            Rectangle {
                x: 20
                y: 1
                width: parent.width - 40
                height: 1
                color: Qt.alpha("white", 0.08)
            }

            ClippingRectangle {
                x: 6
                y: 6
                width: 28
                height: 28
                radius: 8
                color: Theme.surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "󰎈"
                    color: Theme.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.artUrl
                    sourceSize.width: 56
                    sourceSize.height: 56
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            // Title and artist, or the controls while hovered.
            Column {
                x: 44
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                width: parent.width - 44 - 16 - 27 - 22
                opacity: root.hovered ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }

                Text {
                    id: title
                    width: parent.width
                    text: root.lines.top
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    id: artist
                    width: parent.width
                    visible: text.length > 0
                    text: root.lines.bottom
                    color: Qt.alpha(Theme.textMuted, 0.75)
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 27
                y: 7
                height: 19
                spacing: 3
                opacity: root.hovered ? 0 : 1
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }

                Repeater {
                    model: root.bars
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 3
                        height: 3 + 16 * (root.levels[index] ?? 0)
                        radius: 1.5
                        color: Theme.primary
                    }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -1
                x: 44 + (parent.width - 44 - width) / 2
                spacing: 8
                opacity: root.hovered ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }

                Repeater {
                    model: [
                        { glyph: "󰒮", big: false, act: "previous", can: "canGoPrevious" },
                        { glyph: "", big: true, act: "togglePlaying", can: "canTogglePlaying" },
                        { glyph: "󰒭", big: false, act: "next", can: "canGoNext" }
                    ]
                    Rectangle {
                        required property var modelData
                        readonly property bool can: root.player?.[modelData.can] ?? false
                        anchors.verticalCenter: parent.verticalCenter
                        width: modelData.big ? 28 : 24
                        height: width
                        radius: width / 2
                        color: modelData.big ? Theme.primary : Theme.surfaceContainerHigh
                        opacity: can ? (press.containsMouse ? 1 : 0.9) : 0.4

                        Text {
                            anchors.centerIn: parent
                            // Playing is the only state the pill is shown in, so this is pause.
                            text: parent.modelData.big ? "󰏤" : parent.modelData.glyph
                            color: parent.modelData.big ? Theme.textOnPrimary : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: parent.modelData.big ? 15 : 13
                        }

                        MouseArea {
                            id: press
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: parent.can
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.player[parent.modelData.act]()
                        }
                    }
                }
            }

            // The progress line, 2 px inside the bottom rim.
            Item {
                x: 18
                y: parent.height - 5
                width: parent.width - 36
                height: 2

                Rectangle {
                    anchors.fill: parent
                    radius: 1
                    color: Qt.alpha(Theme.text, 0.12)
                }
                Rectangle {
                    width: parent.width * root.progress
                    height: 2
                    radius: 1
                    color: Theme.primary
                }
                Rectangle {
                    visible: root.progress > 0
                    x: parent.width * root.progress - 4
                    y: -3
                    width: 8
                    height: 8
                    radius: 4
                    color: Qt.alpha(Theme.primary, 0.35)
                    Rectangle {
                        anchors.centerIn: parent
                        width: 5
                        height: 5
                        radius: 2.5
                        color: Theme.primary
                    }
                }
            }
        }
    }
}
