// Top-centre: the island. A small black pill with the time that springs open
// into the playing song, a notification, or the volume / brightness OSD, then
// shrinks back. What shows when is IslandQueue.js; this file only feeds it
// events and draws its views.
//
// It is the session's notification server (the niri bar's never runs here).
// The media keys stay plain wpctl / brightnessctl binds; the island watches
// the values themselves. Hidden while a fullscreen window is focused, except
// for a critical notification or the open launcher.
//
// openLauncher() / closeLauncher() / expanded: the pill grows down into the
// launcher's panel (Launcher.qml), with the viper wound around it, and takes
// the keyboard while open. anchorBottom is the underside centre in
// screen coordinates (the spider hangs from it). The hanging viper
// (HangingViper.qml) hangs 30 px right of it.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import "." as U
import "IslandQueue.js" as Q

PanelWindow {
    id: root

    property bool expanded: false
    function openLauncher() {
        expanded = true;
    }
    function closeLauncher() {
        expanded = false;
    }
    readonly property point anchorBottom: Qt.point((screen?.width ?? 0) / 2, margins.top + pill.y + pill.height)

    // The queue's state; `view` is what shows.
    property var queue: Q.initial()
    readonly property string view: queue.view
    readonly property var item: queue.item
    // The last notice and OSD shown, so their content stays while it fades.
    property var lastNotice: ({})
    property var lastOsd: ({ glyph: "", value: 0 })
    onItemChanged: {
        if (view === "notify")
            lastNotice = item;
        else if (view === "osd")
            lastOsd = item;
    }
    readonly property bool critical: view === "notify" && (item?.critical ?? false)

    // The hanging viper keeps it shown while it hisses and pulls up for a
    // fullscreen window.
    visible: !UmbrielIpc.fullscreen || critical || expanded || hanging.holdsIsland

    // The pill sits 14 px down the window, which starts at the screen's top
    // edge: room for the viper's head over the launcher's corner.
    anchors.top: true
    margins.top: 0
    // Room for the largest view, the launcher with the viper around it, and
    // the spring's overshoot, and down the whole screen for the hanging
    // viper's venom to fall onto the windows below; only the pill takes the
    // pointer.
    implicitWidth: 360
    implicitHeight: Math.max(400, screen?.height ?? 0)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "umbriel-island"
    mask: Region {
        item: pill
    }

    function push(type, payload) {
        const prev = queue;
        queue = Q.next(queue, { type: type, payload: payload }, Date.now());
        // A notice that has had its turn leaves the server too.
        if (prev.view === "notify" && !prev.item.life.closed && !Q.holds(queue, prev.item.id))
            prev.item.notification.expire();
        if (queue.until === Infinity) {
            expiry.stop();
        } else {
            expiry.interval = Math.max(1, queue.until - Date.now());
            expiry.restart();
        }
    }

    // One wake-up when the shown view runs out; nothing ticks in between.
    Timer {
        id: expiry
        onTriggered: root.push("tick")
    }

    // Notifications

    NotificationServer {
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => {
            n.tracked = true;
            const id = n.id;
            const life = { closed: false };
            // Sent again on a replacement (replaces_id), which updates the
            // same object in place.
            const send = () => {
                if (!life.closed)
                    root.push("notify", root.entryFor(n, life));
            };
            n.closed.connect(() => {
                life.closed = true;
                root.push("dismiss", { id: id });
            });
            n.summaryChanged.connect(() => Qt.callLater(send));
            n.bodyChanged.connect(() => Qt.callLater(send));
            n.imageChanged.connect(() => Qt.callLater(send));
            n.appIconChanged.connect(() => Qt.callLater(send));
            send();
        }
    }

    // The text is copied, so the view can still fade it out after the
    // notification object is gone.
    function entryFor(n, life) {
        return {
            id: n.id,
            critical: n.urgency === NotificationUrgency.Critical,
            summary: n.summary,
            body: n.body,
            icon: iconSource(n.image) || iconSource(n.appIcon),
            notification: n,
            life: life
        };
    }

    // An image or icon hint is a path, a URL, or a theme icon name (which
    // the server may already have made "image://icon/<name>"). A name the
    // theme lacks gives "", so no broken-image square shows.
    function iconSource(s) {
        if (!s)
            return "";
        if (s.startsWith("image://icon/"))
            return Quickshell.iconPath(s.slice(13), true);
        if (s.startsWith("/"))
            return "file://" + s;
        return s.includes(":") ? s : Quickshell.iconPath(s, true);
    }

    function activate() {
        const entry = item;
        if (!entry || entry.life.closed)
            return;
        const action = entry.notification.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        entry.notification.dismiss();
        push("dismiss", { id: entry.id });
    }

    // Music: whichever player is playing, else the first one. A new track
    // (or playback starting) opens the music view.

    readonly property var player: Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
    readonly property string track: playing ? [player.trackTitle, player.trackArtist].join("\n") : ""
    onTrackChanged: if (track.length > 0) push("music", {})

    // Volume and brightness. The first value read is only remembered.

    readonly property var sink: Pipewire.defaultAudioSink
    property real lastVolume: -1
    property int lastMuted: -1
    property real lastBrightness: -1

    PwObjectTracker {
        objects: [root.sink]
    }

    // Not while fullscreen: it would only push a critical notice off-screen.
    function osd(glyph, value) {
        if (!UmbrielIpc.fullscreen)
            push("osd", { glyph: glyph, value: Math.max(0, Math.min(1, value)) });
    }

    function volumeChanged() {
        const audio = sink?.audio;
        if (!audio)
            return;
        const v = audio.volume;
        const m = audio.muted ? 1 : 0;
        if (lastVolume >= 0 && (Math.abs(v - lastVolume) > 0.001 || m !== lastMuted))
            osd(audio.muted ? "󰝟" : (v > 0.5 ? "󰕾" : "󰖀"), audio.muted ? 0 : v);
        lastVolume = v;
        lastMuted = m;
    }

    onSinkChanged: {
        lastVolume = -1;
        lastMuted = -1;
        volumeChanged();
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() {
            root.volumeChanged();
        }
        function onMutedChanged() {
            root.volumeChanged();
        }
    }

    // Brightness only polls while the island can show it; the first value
    // read after that is only remembered again.
    onVisibleChanged: if (visible) lastBrightness = -1
    Binding {
        target: Brightness
        property: "watching"
        value: root.visible
    }

    Connections {
        target: Brightness
        function onCurrentChanged() {
            const v = Brightness.value;
            if (root.lastBrightness >= 0 && Math.abs(v - root.lastBrightness) > 0.001)
                root.osd("󰃠", v);
            root.lastBrightness = v;
        }
    }

    SystemClock {
        id: clock
        enabled: root.visible
        precision: SystemClock.Minutes
    }

    // The pill

    // The viper's body behind the launcher's panel.
    U.Viper {
        side: "back"
        phase: viper.phase
        bands: launcher.bands
        x: Math.round((root.width - panelW) / 2)
        y: pill.y
    }

    // The viper hanging from under the pill, and its venom.
    U.HangingViper {
        id: hanging
        island: root
    }

    // A faint wider outline: the accent's glow, for critical notices.
    Rectangle {
        anchors.fill: pill
        anchors.margins: -3
        radius: pill.radius + 3
        color: "transparent"
        border.width: 2
        border.color: U.Palette.bright
        opacity: root.critical ? 0.18 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }

    Rectangle {
        id: pill

        anchors.horizontalCenter: parent.horizontalCenter
        y: 14
        width: root.expanded ? launcher.width : root.view === "music" ? 280 : root.view === "notify" ? 300 : root.view === "osd" ? 220 : 76
        height: root.expanded ? launcher.height : root.view === "notify" ? 64 : root.view === "clock" ? 28 : 32
        radius: Math.min(height / 2, 20)
        // Opaque while open, so the viper's back coils don't show through.
        color: root.expanded ? Qt.alpha(U.Palette.panel, 1) : U.Palette.panel
        border.width: 1
        border.color: root.critical ? U.Palette.bright : U.Palette.line
        clip: true

        Behavior on width {
            NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        Behavior on height {
            NumberAnimation { duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }

        TapHandler {
            onTapped: if (root.view === "notify" && !root.expanded) root.activate()
        }

        U.Launcher {
            id: launcher
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            island: root
            viper: viper
        }

        // Clock
        View {
            shown: root.view === "clock" && !root.expanded
            Text {
                anchors.centerIn: parent
                text: Qt.formatTime(clock.date, "HH:mm")
                color: U.Palette.text
                font { family: U.Palette.font; pixelSize: 12 }
            }
        }

        // Music: equaliser, title · artist, time
        View {
            id: music
            shown: root.view === "music" && !root.expanded
            readonly property bool moving: shown && root.visible && root.playing

            Row {
                id: bars
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                height: 12
                spacing: 2

                Repeater {
                    model: [420, 300, 520, 360]

                    Rectangle {
                        id: bar
                        required property int modelData
                        anchors.bottom: parent.bottom
                        width: 2
                        height: 3
                        radius: 1
                        color: U.Palette.bright

                        SequentialAnimation on height {
                            running: music.moving
                            loops: Animation.Infinite
                            NumberAnimation { to: 12; duration: bar.modelData; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 4; duration: bar.modelData * 0.8; easing.type: Easing.InOutSine }
                            onRunningChanged: if (!running) bar.height = 3
                        }
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: bars.x + bars.width + 10
                width: time.x - x - 10
                text: [root.player?.trackTitle, root.player?.trackArtist].filter(s => s && s.length).join(" · ")
                color: U.Palette.text
                elide: Text.ElideRight
                font { family: U.Palette.font; pixelSize: 11 }
            }

            Text {
                id: time
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 14
                text: root.player?.positionSupported ? root.clockText(root.player.position) : root.player?.lengthSupported ? root.clockText(root.player.length) : ""
                color: U.Palette.muted
                font { family: U.Palette.font; pixelSize: 11 }
            }

            // Mpris doesn't announce position changes; ask once a second, and
            // only while this view shows.
            Timer {
                running: music.shown && root.visible && (root.player?.positionSupported ?? false)
                repeat: true
                interval: 1000
                onTriggered: root.player.positionChanged()
            }
        }

        // Notification: icon or image, title, body. A click dismisses it.
        View {
            id: notice
            shown: root.view === "notify" && !root.expanded
            readonly property string icon: root.lastNotice.icon ?? ""

            IconImage {
                id: noticeIcon
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: notice.icon.length > 0
                source: notice.icon
                implicitSize: 32
            }

            Column {
                x: noticeIcon.visible ? 58 : 18
                width: parent.width - x - 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: root.lastNotice.summary ?? ""
                    color: U.Palette.bright
                    elide: Text.ElideRight
                    font { family: U.Palette.font; pixelSize: 12; bold: true }
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.lastNotice.body ?? ""
                    color: U.Palette.muted
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font { family: U.Palette.font; pixelSize: 11 }
                }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
        }

        // OSD: glyph, bar, value
        View {
            shown: root.view === "osd" && !root.expanded

            Row {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.lastOsd.glyph
                    color: U.Palette.text
                    font { family: U.Palette.font; pixelSize: 14 }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    height: 4
                    radius: 2
                    color: U.Palette.line

                    // The fill, with a faint wider copy under it for the glow.
                    Rectangle {
                        visible: fill.width > 0
                        x: -1
                        y: -2
                        width: fill.width + 2
                        height: parent.height + 4
                        radius: height / 2
                        color: U.Palette.bright
                        opacity: 0.15
                    }
                    Rectangle {
                        id: fill
                        width: parent.width * root.lastOsd.value
                        height: parent.height
                        radius: 2
                        color: U.Palette.bright
                        Behavior on width {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    text: Math.round(root.lastOsd.value * 100)
                    color: U.Palette.muted
                    font { family: U.Palette.font; pixelSize: 11 }
                }
            }
        }
    }

    // The hidden spider, hanging from the pill's underside now and then.
    U.Spider {
        island: root
    }

    // The crossings and head in front of the panel.
    U.Viper {
        id: viper
        side: "front"
        bands: launcher.bands
        x: Math.round((root.width - panelW) / 2)
        y: pill.y
    }

    function clockText(seconds) {
        const s = Math.max(0, Math.floor(seconds));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // A view's content: fades in once the pill has started to open, and is
    // not drawn at all while another view shows.
    component View: Item {
        property bool shown: false
        anchors.fill: parent
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: 160 }
        }
    }
}
