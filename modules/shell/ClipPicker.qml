// Clipboard history and emoji, on a slab of pond glass like the wallpaper
// picker's (a lit top rim, a depth gradient and reflection band, faint stones).
// Toggle it with `qs -c rice ipc call clip clipboard` (Mod+Alt+V) or
// `qs -c rice ipc call clip emoji` (Mod+Alt+Period); `clip toggle` reopens the
// last tab. Type to search; Up/Down (and Left/Right in the emoji grid) to move;
// Enter pastes (Shift+Enter only copies), Delete removes a clipboard entry,
// Tab switches tabs, Esc closes.
// The history comes from cliphist and image entries get thumbnails, all through
// rice-clip (modules/shell/rice-clip.sh). The emoji are Unicode's own list
// (emoji-test.txt from nixpkgs' unicode-emoji, copied in beside this file).
// Only loaded while open and nothing moves once it has slid in, so it costs
// nothing the rest of the time. If the shell isn't running, the binds fall
// back to `rice-menu clipboard`.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "clip.js" as Clip
import "emoji.js" as Emoji

Scope {
    id: root

    property bool open: false
    property string tab: "clip"
    property var entries: []
    // Bumped once rice-clip has decoded the thumbnails, so the rows load them.
    property int thumbs: 0
    // Parsed once, on the first visit to the emoji tab.
    property var emojis: null

    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/rice-clip"

    function show(which) {
        if (open && tab === which) {
            loader.item?.close();
            return;
        }
        tab = which;
        if (!open) {
            entries = [];
            thumbs = 0;
            list.running = true;
            open = true;
        }
    }

    function toggle() {
        if (open)
            loader.item?.close();
        else
            show(tab);
    }

    // A faint stone, as under the bar's widgets.
    component Stone: Rectangle {
        radius: 12
        color: Qt.alpha(Theme.text, 0.05)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.07)
    }

    IpcHandler {
        target: "clip"
        function toggle(): void {
            root.toggle();
        }
        function clipboard(): void {
            root.show("clip");
        }
        function emoji(): void {
            root.show("emoji");
        }
    }

    Process {
        id: list
        command: ["rice-clip", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = Clip.parse(text);
                if (root.entries.some(e => e.image))
                    decode.running = true;
            }
        }
    }

    Process {
        id: decode
        command: ["rice-clip", "thumbs", root.thumbDir]
        onExited: root.thumbs++
    }

    FileView {
        id: emojiFile
        path: root.tab === "emoji" && root.emojis === null ? Quickshell.shellDir + "/emoji-test.txt" : ""
        onLoaded: root.emojis = Emoji.parse(text())
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
            WlrLayershell.namespace: "rice-clip"
            color: "transparent"

            property bool leaving: false
            readonly property bool onClip: root.tab === "clip"
            readonly property var clipShown: Clip.filter(root.entries, search.text)
            readonly property var emojiShown: root.emojis ? Emoji.search(root.emojis, search.text) : []

            function close() {
                leaving = true;
                closeTimer.start();
            }

            function activate(copyOnly) {
                const item = onClip ? clipShown[rows.currentIndex] : emojiShown[grid.currentIndex];
                if (!item)
                    return;
                if (onClip)
                    Quickshell.execDetached(["rice-clip", copyOnly ? "copy" : "paste", item.line]);
                else
                    Quickshell.execDetached(["rice-clip", "emoji", item.char]);
                close();
            }

            function remove() {
                const item = onClip ? clipShown[rows.currentIndex] : null;
                if (!item)
                    return;
                const keep = rows.currentIndex;
                Quickshell.execDetached(["rice-clip", "delete", item.line]);
                root.entries = root.entries.filter(e => e.id !== item.id);
                rows.currentIndex = Math.min(keep, clipShown.length - 1);
            }

            Timer {
                id: closeTimer
                interval: 260
                onTriggered: root.open = false
            }

            Rectangle {
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

                RectangularShadow {
                    anchors.fill: glass
                    offset.y: 8
                    spread: -4
                    blur: 10
                    radius: glass.radius
                    color: Qt.alpha("black", 0.45)
                }

                Rectangle {
                    id: glass

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -20
                    width: Math.min(parent.width - 64, 660)
                    height: Math.min(parent.height - 140, 600)
                    radius: 22
                    color: Qt.alpha(Theme.surface, 0.78)
                    border.width: 1
                    border.color: Qt.alpha(Theme.primary, 0.22)

                    MouseArea {
                        anchors.fill: parent
                    }

                    // Depth: lit from above, darker toward the bottom.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: glass.radius - 1
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.07) }
                            GradientStop { position: 0.5; color: Qt.alpha(Theme.surface, 0) }
                            GradientStop { position: 1; color: Qt.alpha("black", 0.3) }
                        }
                    }

                    // The tabs and the search field.
                    Row {
                        id: head
                        x: 18
                        y: 18
                        width: parent.width - 36
                        height: 40
                        spacing: 8

                        Repeater {
                            model: [["clip", "󰅌  Clipboard"], ["emoji", "󰞅  Emoji"]]

                            Stone {
                                id: tabStone
                                required property var modelData
                                readonly property bool active: root.tab === modelData[0]
                                width: tabLabel.implicitWidth + 28
                                height: 40
                                color: active ? Qt.alpha(Theme.primary, 0.18) : Qt.alpha(Theme.text, 0.05)
                                border.color: active ? Qt.alpha(Theme.primary, 0.55) : Qt.alpha(Theme.text, 0.07)

                                Text {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: tabStone.modelData[1]
                                    color: tabStone.active ? Theme.primary : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                }

                                TapHandler {
                                    onTapped: root.tab = tabStone.modelData[0]
                                }
                            }
                        }

                        Stone {
                            width: head.width - x
                            height: 40

                            Text {
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰍉"
                                color: Theme.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 2
                            }

                            TextInput {
                                id: search

                                x: 38
                                width: parent.width - 52
                                anchors.verticalCenter: parent.verticalCenter
                                focus: true
                                color: Theme.text
                                selectionColor: Qt.alpha(Theme.primary, 0.4)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize + 1
                                clip: true

                                onTextChanged: {
                                    rows.currentIndex = 0;
                                    grid.currentIndex = 0;
                                    rows.positionViewAtBeginning();
                                    grid.positionViewAtBeginning();
                                }

                                Text {
                                    visible: !search.text
                                    text: win.onClip ? "search the clipboard" : "search emoji"
                                    color: Qt.alpha(Theme.textMuted, 0.6)
                                    font: search.font
                                }

                                Keys.onPressed: event => {
                                    const shift = event.modifiers & Qt.ShiftModifier;
                                    if (event.key === Qt.Key_Escape) {
                                        win.close();
                                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        win.activate(shift);
                                    } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                                        root.tab = win.onClip ? "emoji" : "clip";
                                    } else if (event.key === Qt.Key_Delete && win.onClip) {
                                        win.remove();
                                    } else if (event.key === Qt.Key_Down) {
                                        win.onClip ? rows.incrementCurrentIndex() : grid.moveCurrentIndexDown();
                                    } else if (event.key === Qt.Key_Up) {
                                        win.onClip ? rows.decrementCurrentIndex() : grid.moveCurrentIndexUp();
                                    } else if (event.key === Qt.Key_Right && !win.onClip) {
                                        grid.moveCurrentIndexRight();
                                    } else if (event.key === Qt.Key_Left && !win.onClip) {
                                        grid.moveCurrentIndexLeft();
                                    } else if (event.key === Qt.Key_PageDown) {
                                        win.onClip ? (rows.currentIndex = Math.min(rows.count - 1, rows.currentIndex + 6)) : (grid.currentIndex = Math.min(grid.count - 1, grid.currentIndex + 5 * grid.columns));
                                    } else if (event.key === Qt.Key_PageUp) {
                                        win.onClip ? (rows.currentIndex = Math.max(0, rows.currentIndex - 6)) : (grid.currentIndex = Math.max(0, grid.currentIndex - 5 * grid.columns));
                                    } else {
                                        return;
                                    }
                                    event.accepted = true;
                                }
                            }
                        }
                    }

                    // The emoji groups: a jump to each one's first emoji.
                    Row {
                        id: groupRow
                        visible: !win.onClip && !search.text && root.emojis !== null
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: head.y + head.height + 10
                        height: visible ? 34 : 0
                        spacing: 4

                        Repeater {
                            model: root.emojis ? Emoji.groups(root.emojis) : []

                            Rectangle {
                                id: groupChip
                                required property var modelData
                                width: 40
                                height: 34
                                radius: 10
                                color: chipHover.hovered ? Qt.alpha(Theme.text, 0.08) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: groupChip.modelData.icon
                                    font.pixelSize: 19
                                }

                                HoverHandler {
                                    id: chipHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        grid.currentIndex = groupChip.modelData.index;
                                        grid.positionViewAtIndex(grid.currentIndex, GridView.Beginning);
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: well
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.top: groupRow.visible ? groupRow.bottom : head.bottom
                        anchors.margins: 14
                        anchors.topMargin: 12
                        clip: true

                        // The clipboard: newest first.
                        ListView {
                            id: rows

                            anchors.fill: parent
                            visible: win.onClip
                            model: win.clipShown
                            spacing: 6
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 120
                            highlightFollowsCurrentItem: true
                            highlight: Item {
                                width: rows.width
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: Qt.alpha(Theme.primary, 0.14)
                                    border.width: 1.5
                                    border.color: Theme.primary
                                }
                            }

                            delegate: Item {
                                id: row

                                required property var modelData
                                required property int index
                                readonly property bool current: ListView.isCurrentItem
                                readonly property bool isImage: !!modelData.image

                                width: rows.width
                                height: isImage ? 92 : Math.min(64, label.implicitHeight + 24)

                                Stone {
                                    anchors.fill: parent
                                    radius: 14
                                    opacity: row.current ? 0 : 1
                                    color: rowHover.hovered ? Qt.alpha(Theme.text, 0.09) : Qt.alpha(Theme.text, 0.05)
                                }

                                ClippingRectangle {
                                    id: thumb
                                    visible: row.isImage
                                    x: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: row.isImage ? Math.min(140, 72 * row.modelData.image.width / Math.max(1, row.modelData.image.height)) : 0
                                    height: 72
                                    radius: 9
                                    color: Theme.surfaceContainer

                                    Image {
                                        anchors.fill: parent
                                        source: row.isImage && root.thumbs > 0 ? "file://" + Clip.thumbPath(root.thumbDir, row.modelData) : ""
                                        sourceSize.height: 144
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                    }
                                }

                                Text {
                                    id: label
                                    anchors.left: row.isImage ? thumb.right : parent.left
                                    anchors.leftMargin: 14
                                    anchors.right: bin.left
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Clip.label(row.modelData)
                                    color: row.current ? Theme.text : Qt.alpha(Theme.text, 0.82)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }

                                // Remove this entry.
                                Text {
                                    id: bin
                                    anchors.right: parent.right
                                    anchors.rightMargin: 14
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰆴"
                                    color: binHover.hovered ? Theme.error : Theme.textMuted
                                    opacity: rowHover.hovered || row.current ? 1 : 0
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize + 2

                                    HoverHandler {
                                        id: binHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: {
                                            rows.currentIndex = row.index;
                                            win.remove();
                                        }
                                    }
                                }

                                HoverHandler {
                                    id: rowHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        rows.currentIndex = row.index;
                                        win.activate(false);
                                    }
                                }
                            }
                        }

                        // The emoji grid.
                        GridView {
                            id: grid

                            readonly property int columns: Math.max(1, Math.floor(width / cellWidth))

                            anchors.fill: parent
                            visible: !win.onClip
                            model: win.emojiShown
                            cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 52)))
                            cellHeight: 52
                            boundsBehavior: Flickable.StopAtBounds
                            highlightMoveDuration: 0
                            highlight: Rectangle {
                                radius: 12
                                color: Qt.alpha(Theme.primary, 0.16)
                                border.width: 1.5
                                border.color: Theme.primary
                            }

                            delegate: Item {
                                id: cell

                                required property var modelData
                                required property int index

                                width: grid.cellWidth
                                height: grid.cellHeight

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    radius: 12
                                    color: cellHover.hovered ? Qt.alpha(Theme.text, 0.08) : "transparent"
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: cell.modelData.char
                                    font.pixelSize: 28
                                }

                                HoverHandler {
                                    id: cellHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        grid.currentIndex = cell.index;
                                        win.activate(false);
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: (win.onClip ? rows.count : grid.count) === 0
                            text: win.onClip ? (root.entries.length ? "nothing matches" : "the clipboard is empty") : (root.emojis ? "no emoji match" : "")
                            color: Theme.textMuted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    // The glass over the list: a reflection band under the rim,
                    // and the rim's highlight, brightest in the middle.
                    Rectangle {
                        x: 16
                        y: 2
                        width: parent.width - 32
                        height: 16
                        radius: 8
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha("white", 0.05) }
                            GradientStop { position: 1; color: Qt.alpha("white", 0) }
                        }
                    }
                    Rectangle {
                        x: 22
                        y: 1
                        width: parent.width - 44
                        height: 1.5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.alpha("white", 0) }
                            GradientStop { position: 0.5; color: Qt.alpha("white", 0.22) }
                            GradientStop { position: 1; color: Qt.alpha("white", 0) }
                        }
                    }
                }

                Stone {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: glass.bottom
                    anchors.topMargin: 18
                    width: hint.implicitWidth + 28
                    height: 28

                    Text {
                        id: hint
                        anchors.centerIn: parent
                        text: win.onClip ? "⏎  paste    ⇧⏎  copy    del  remove    tab  emoji    esc  close" : "⏎  insert    tab  clipboard    esc  close"
                        color: Theme.textMuted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                }
            }
        }
    }
}
