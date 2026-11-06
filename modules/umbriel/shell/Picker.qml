// The wallpaper picker: a centred panel of thumbnails over a dimmed screen.
// Toggle it with `qs -c umbriel ipc call picker toggle` (Mod+Ctrl+W).
// Arrows or hjkl move, Enter or a click picks, Esc or a click outside closes.
// Picking runs `umbriel-wall set ID`; Background follows the state file.
// Only loaded while open, so the thumbnails cost nothing the rest of the time.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "." as U
import Quickshell.Widgets

Scope {
    id: root

    // Background, for the wall directory and the current id.
    required property var background

    property bool open: false
    property var ids: []

    function toggle() {
        if (open) {
            open = false;
        } else {
            list.running = true;
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
        id: list
        command: ["umbriel-wall", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.ids = text.trim().split("\n").filter(s => s.length && root.background.walls[s])
        }
    }

    LazyLoader {
        active: root.open

        PanelWindow {
            id: win

            screen: root.background.screen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "umbriel-picker"
            color: "transparent"

            function choose(id) {
                Quickshell.execDetached(["umbriel-wall", "set", id]);
                root.open = false;
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(U.Palette.bg, 0.6)

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.open = false
                }
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: grid.width + 48
                height: grid.height + title.height + 64
                radius: 14
                color: U.Palette.panel
                border.width: 1
                border.color: U.Palette.line
                opacity: 0
                scale: 0.97

                Component.onCompleted: enter.start()

                ParallelAnimation {
                    id: enter
                    NumberAnimation { target: card; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: card; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                }

                // Swallow clicks so they don't reach the dim layer.
                MouseArea {
                    anchors.fill: parent
                }

                Text {
                    id: title
                    x: 24
                    y: 20
                    text: "wallpaper"
                    color: U.Palette.muted
                    font.family: U.Palette.font
                    font.pixelSize: 13
                    font.letterSpacing: 2
                }

                GridView {
                    id: grid

                    readonly property int columns: 4

                    x: 24
                    anchors.top: title.bottom
                    anchors.topMargin: 16
                    width: columns * cellWidth
                    height: Math.ceil(count / columns) * cellHeight
                    cellWidth: 264
                    cellHeight: 182
                    interactive: false
                    focus: true
                    model: root.ids
                    currentIndex: Math.max(0, root.ids.indexOf(root.background.wallId))

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape)
                            root.open = false;
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            win.choose(root.ids[currentIndex]);
                        else if (event.key === Qt.Key_L || event.key === Qt.Key_Right)
                            moveCurrentIndexRight();
                        else if (event.key === Qt.Key_H || event.key === Qt.Key_Left)
                            moveCurrentIndexLeft();
                        else if (event.key === Qt.Key_J || event.key === Qt.Key_Down)
                            moveCurrentIndexDown();
                        else if (event.key === Qt.Key_K || event.key === Qt.Key_Up)
                            moveCurrentIndexUp();
                        else
                            return;
                        event.accepted = true;
                    }

                    delegate: Item {
                        id: cell

                        required property string modelData
                        required property int index
                        readonly property bool current: GridView.isCurrentItem
                        readonly property bool shown: modelData === root.background.wallId

                        width: grid.cellWidth
                        height: grid.cellHeight

                        // The accent: a soft bright halo around the selection.
                        Rectangle {
                            anchors.fill: thumb
                            anchors.margins: -4
                            radius: 12
                            color: "transparent"
                            border.width: 4
                            border.color: Qt.alpha(U.Palette.bright, 0.12)
                            visible: cell.current
                        }

                        ClippingRectangle {
                            id: thumb
                            x: 8
                            y: 8
                            width: parent.width - 16
                            height: parent.height - 16
                            radius: 8
                            color: U.Palette.raised
                            border.width: 1
                            border.color: cell.current ? U.Palette.bright : U.Palette.line
                            opacity: cell.current || hover.hovered ? 1 : 0.6

                            Behavior on opacity {
                                NumberAnimation { duration: 140 }
                            }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 1
                                source: "file://" + root.background.wallDir + "/" + root.background.walls[cell.modelData].file
                                sourceSize: Qt.size(width * 1.5, height * 1.5)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }

                            // A small dot marks the one on screen now.
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                width: 6
                                height: 6
                                radius: 3
                                color: U.Palette.bright
                                visible: cell.shown
                            }

                            HoverHandler {
                                id: hover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: win.choose(cell.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
