// Animated wallpaper picker: a carousel that slides up over a dimmed screen.
// Toggle it with `qs -c rice ipc call picker toggle` (Mod+Ctrl+W).
// Left/Right (or h/l, or the wheel) to browse, Enter or click to pick, Esc to close.
// Only loaded while open, so the thumbnails cost no memory the rest of the time.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
    id: root

    property bool open: false
    property var walls: []

    readonly property string home: Quickshell.env("HOME")

    function toggle() {
        if (open) {
            loader.item?.close();
        } else {
            scan.running = true;
            open = true;
        }
    }

    IpcHandler {
        target: "picker"
        function toggle(): void {
            root.toggle();
        }
    }

    Process {
        id: scan
        command: ["find", "-L", root.home + "/.local/share/wallpapers/rotation", root.home + "/.local/share/wallpapers/saved", "-maxdepth", "1", "-type", "f"]
        stdout: StdioCollector {
            onStreamFinished: root.walls = text.trim().split("\n").filter(s => s.length).sort()
        }
    }

    LazyLoader {
        id: loader
        active: root.open

        PanelWindow {
            id: win

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "rice-picker"
            color: "transparent"

            property bool leaving: false

            function close() {
                leaving = true;
                closeTimer.start();
            }

            function choose(path) {
                Quickshell.execDetached(["env", "RICE_TRANSITION=grow", "rice-wall", "set", path]);
                close();
            }

            Timer {
                id: closeTimer
                interval: 260
                onTriggered: root.open = false
            }

            Rectangle {
                id: dim
                anchors.fill: parent
                color: Qt.alpha(Theme.surface, 0.55)
                opacity: win.leaving ? 0 : 1
                Component.onCompleted: fadeIn.start()

                NumberAnimation on opacity {
                    id: fadeIn
                    from: 0
                    to: 1
                    duration: 220
                    running: false
                }

                Behavior on opacity {
                    NumberAnimation { duration: 220 }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: win.close()
                }
            }

            Item {
                id: stage
                anchors.fill: parent
                opacity: win.leaving ? 0 : 1
                transform: Translate { id: lift; y: win.leaving ? 60 : 0 }

                Behavior on opacity {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }

                Component.onCompleted: enter.start()

                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: stage; property: "opacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                    NumberAnimation { target: lift; property: "y"; from: 80; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                }

                ListView {
                    id: list

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 300
                    orientation: ListView.Horizontal
                    spacing: 22
                    focus: true
                    model: root.walls
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: (width - 420) / 2
                    preferredHighlightEnd: (width + 420) / 2
                    highlightMoveDuration: 260
                    snapMode: ListView.SnapToItem
                    // matugen reports the resolved store path, so match on the file name.
                    currentIndex: Math.max(0, root.walls.findIndex(w => Theme.wallpaper.endsWith("-" + w.split("/").pop())))

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            win.close();
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            win.choose(root.walls[currentIndex]);
                        } else if (event.key === Qt.Key_L || event.key === Qt.Key_Right) {
                            incrementCurrentIndex();
                        } else if (event.key === Qt.Key_H || event.key === Qt.Key_Left) {
                            decrementCurrentIndex();
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }

                    delegate: Item {
                        id: card

                        required property string modelData
                        required property int index
                        readonly property bool current: ListView.isCurrentItem

                        width: 420
                        height: 300
                        z: current ? 1 : 0

                        ClippingRectangle {
                            anchors.centerIn: parent
                            width: 420
                            height: 236
                            radius: 18
                            color: Theme.surfaceContainer
                            border.width: card.current ? 2 : 0
                            border.color: Theme.primary
                            scale: card.current ? 1.12 : (hover.hovered ? 0.88 : 0.8)
                            opacity: card.current ? 1 : 0.55

                            Behavior on scale {
                                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 260 }
                            }

                            Image {
                                anchors.fill: parent
                                source: "file://" + card.modelData
                                sourceSize.width: 640
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }

                            HoverHandler {
                                id: hover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: card.current ? win.choose(card.modelData) : list.currentIndex = card.index
                            }
                        }
                    }

                    WheelHandler {
                        onWheel: event => event.angleDelta.y < 0 ? list.incrementCurrentIndex() : list.decrementCurrentIndex()
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: list.bottom
                    anchors.topMargin: 18
                    text: "←  →  browse    ⏎  set    esc  close"
                    color: Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }
            }
        }
    }
}
