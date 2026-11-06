// Volume / brightness pop-up. It watches the state itself, so the media keys
// stay plain wpctl / brightnessctl binds. The first value read at startup is
// only remembered, never shown.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

Scope {
    id: root

    property string icon: ""
    property real value: 0
    property bool shown: false

    readonly property var sink: Pipewire.defaultAudioSink

    function show(icon, value) {
        root.icon = icon;
        root.value = value;
        shown = true;
        hideTimer.restart();
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    // -1 means "not read yet", so the startup value doesn't pop the OSD.
    property real lastVolume: -1
    property int lastMuted: -1
    property real lastBrightness: -1

    Connections {
        target: root.sink?.audio ?? null

        function onVolumeChanged() {
            root.volumeChanged();
        }
        function onMutedChanged() {
            root.volumeChanged();
        }
    }

    function volumeChanged() {
        const audio = sink?.audio;
        if (!audio)
            return;
        const first = lastVolume < 0;
        const v = audio.volume;
        const m = audio.muted ? 1 : 0;
        if (!first && (Math.abs(v - lastVolume) > 0.001 || m !== lastMuted))
            show(audio.muted ? "󰝟" : (v > 0.5 ? "󰕾" : "󰖀"), audio.muted ? 0 : v);
        lastVolume = v;
        lastMuted = m;
    }

    Connections {
        target: Brightness

        function onCurrentChanged() {
            const v = Brightness.value;
            if (root.lastBrightness >= 0 && Math.abs(v - root.lastBrightness) > 0.001)
                root.show("󰃠", v);
            root.lastBrightness = v;
        }
    }

    // A sink that appears after startup counts as its own first read.
    onSinkChanged: {
        lastVolume = -1;
        lastMuted = -1;
        volumeChanged();
    }

    Timer {
        id: hideTimer
        interval: 1200
        onTriggered: root.shown = false
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            anchors.bottom: true
            margins.bottom: 120
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-osd"
            color: "transparent"
            implicitWidth: 240
            implicitHeight: 44
            visible: pill.opacity > 0
            // Never takes the pointer.
            mask: Region {}

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: height / 2
                color: Qt.alpha(Theme.surface, 0.88)
                border.width: 1
                border.color: Qt.alpha(Theme.primary, 0.3)
                opacity: root.shown ? 1 : 0

                Behavior on opacity {
                    NumberAnimation { duration: 180 }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: root.icon
                        color: Theme.primary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 5
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 150
                        height: 6
                        radius: 3
                        color: Qt.alpha(Theme.text, 0.12)
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.value))
                            height: parent.height
                            radius: 3
                            color: Theme.primary

                            Behavior on width {
                                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Text {
                        text: Math.round(root.value * 100)
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        width: 26
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
