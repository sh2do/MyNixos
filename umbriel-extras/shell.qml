// Umbriel extras: small Quickshell widgets that sit next to Noctalia.
// Run with:  qs -c umbriel-extras   (autostarted by the Umbriel session)
//
// Control it from a terminal or a keybind:
//   qs -c umbriel-extras ipc call stats toggle
//   qs -c umbriel-extras ipc call stats show
//   qs -c umbriel-extras ipc call stats hide

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool shown: true
    property int cpu: 0
    property int mem: 0
    property int temp: 0

    IpcHandler {
        target: "stats"

        function toggle(): void {
            root.shown = !root.shown;
        }

        function show(): void {
            root.shown = true;
        }

        function hide(): void {
            root.shown = false;
        }
    }

    // stats.sh prints "<cpu%> <mem%> <tempC>" and exits.
    Process {
        id: sampler
        command: ["sh", Quickshell.shellPath("stats.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(" ");
                if (p.length === 3) {
                    root.cpu = parseInt(p[0]);
                    root.mem = parseInt(p[1]);
                    root.temp = parseInt(p[2]);
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: root.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sampler.running)
                sampler.running = true;
        }
    }

    component StatRow: Item {
        id: row
        property string label
        property int value: 0
        property string suffix: "%"
        property real fraction: Math.min(1, Math.max(0, value / 100))
        property color accent: value >= 85 ? "#e0605e" : "#c9a554"

        implicitWidth: 160
        implicitHeight: 34

        Text {
            id: name
            text: row.label
            color: "#c2c2b0"
            font.pixelSize: 12
            anchors.left: parent.left
            anchors.top: parent.top
        }

        Text {
            text: row.value + row.suffix
            color: "#f0efe6"
            font.pixelSize: 12
            font.bold: true
            anchors.right: parent.right
            anchors.top: parent.top
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 6
            radius: 3
            color: "#33ffffff"

            Rectangle {
                width: parent.width * row.fraction
                height: parent.height
                radius: 3
                color: row.accent

                Behavior on width {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "umbriel-extras-stats"

        anchors {
            bottom: true
            left: true
        }
        margins {
            bottom: 16
            left: 16
        }

        implicitWidth: 192
        implicitHeight: card.implicitHeight + 24

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 14
            color: "#b3222222"
            border.width: 1
            border.color: "#40c9a554"
            implicitHeight: col.implicitHeight + 24

            Column {
                id: col
                anchors.centerIn: parent
                spacing: 8

                StatRow {
                    label: "CPU"
                    value: root.cpu
                }
                StatRow {
                    label: "Memory"
                    value: root.mem
                }
                StatRow {
                    label: "Temp"
                    value: root.temp
                    suffix: "°C"
                }
            }
        }
    }
}
