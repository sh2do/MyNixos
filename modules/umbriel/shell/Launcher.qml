// The launcher: the island dropped open into a 240×320 panel, with a search
// field and up to 8 apps, the viper wound around it. Toggle it with
// `qs -c umbriel ipc call launcher toggle` (Mod+Space).
//
// Typing filters (fuzzy.js), Up/Down move, Enter or a click launches: the
// viper strikes at the row first, then the app starts and the panel closes.
// Esc or a click outside closes. Terminal=true apps open in Umbriel's kitty.
//
// It lives inside the island's pill (Island.qml makes the pill this size and
// takes the keyboard while it's open). The rows leave two gaps, `bands`, for
// the viper's front crossings, so they never cover a row or the search field.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "." as U
import "fuzzy.js" as Fuzzy

Item {
    id: root

    required property var island
    // The front Viper; its phase follows the launcher.
    required property var viper

    readonly property bool open: island.expanded

    width: 240
    height: 320

    // Rows: 24 px tall on a 26 px pitch, with a 24 px gap after the third
    // and the sixth.
    readonly property int rowsTop: 50
    function rowY(i) {
        return rowsTop + 26 * i + 24 * (i >= 3 ? 1 : 0) + 24 * (i >= 6 ? 1 : 0);
    }
    readonly property var bands: [[rowY(2) + 24, rowY(3)], [rowY(5) + 24, rowY(6)]]

    property string query: ""
    property int selected: 0
    readonly property var apps: open ? DesktopEntries.applications.values.filter(e => !e.noDisplay) : []
    readonly property var results: Fuzzy.rank(query, apps).slice(0, 8)
    onResultsChanged: selected = 0

    onOpenChanged: {
        if (open) {
            query = "";
            input.text = "";
            selected = 0;
            viper.phase = "entering";
            input.forceActiveFocus();
        } else {
            viper.phase = "hidden";
        }
    }

    function toggle() {
        if (open)
            island.closeLauncher();
        else
            island.openLauncher();
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            root.toggle();
        }
    }

    // Enter, or a click on a row: strike, then launch (onStruck).
    property var chosen: null
    function choose(i) {
        if (viper.phase === "strike" || i < 0 || i >= results.length)
            return;
        selected = i;
        chosen = results[i];
        viper.strikeTarget = Qt.point(200, rowY(i) + 12);
        viper.phase = "strike";
    }

    Connections {
        target: root.viper
        function onStruck() {
            root.launch(root.chosen);
            root.chosen = null;
            root.island.closeLauncher();
        }
    }

    function launch(entry) {
        if (!entry)
            return;
        if (entry.runInTerminal) {
            const dir = (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/umbriel-term";
            // kitty takes the program as its trailing arguments (no -e).
            Quickshell.execDetached({
                command: ["env", "STARSHIP_CONFIG=" + dir + "/starship.toml", "kitty", "--class", "umbriel-term", "--config", dir + "/kitty.conf"].concat(Array.from(entry.command)),
                workingDirectory: entry.workingDirectory
            });
        } else {
            entry.execute();
        }
    }

    // Fades in once the pill has started to open.
    opacity: open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity {
        NumberAnimation { duration: 160 }
    }

    // A click anywhere else closes: a clear layer under the island while open.
    LazyLoader {
        active: root.open

        PanelWindow {
            screen: root.island.screen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "umbriel-launcher-dismiss"

            MouseArea {
                anchors.fill: parent
                onClicked: root.island.closeLauncher()
            }
        }
    }

    // The search field, leaving the top-right corner to the viper's head.
    Rectangle {
        x: 12
        y: 12
        width: 196
        height: 28
        radius: 9
        color: U.Palette.raised

        TextInput {
            id: input
            x: 12
            width: parent.width - 24
            anchors.verticalCenter: parent.verticalCenter
            color: U.Palette.bright
            selectionColor: U.Palette.line
            clip: true
            font { family: U.Palette.font; pixelSize: 12 }
            onTextChanged: root.query = text

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    root.island.closeLauncher();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.choose(root.selected);
                else if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier))
                    root.selected = Math.min(root.results.length - 1, root.selected + 1);
                else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier))
                    root.selected = Math.max(0, root.selected - 1);
                else
                    return;
                event.accepted = true;
            }
        }

        // The rest of the selected name, after what's typed, when it starts
        // with it.
        Text {
            readonly property string name: root.results[root.selected]?.name ?? ""
            x: input.x + input.contentWidth
            anchors.verticalCenter: parent.verticalCenter
            visible: root.query.length > 0 && name.toLowerCase().startsWith(root.query.toLowerCase())
            text: name.slice(root.query.length)
            color: U.Palette.muted
            font: input.font
        }

        Text {
            x: input.x
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: "search"
            color: U.Palette.muted
            font: input.font
        }
    }

    Repeater {
        model: root.results

        Rectangle {
            id: row

            required property var modelData
            required property int index
            readonly property bool current: index === root.selected
            // A theme icon name or a path; "" when the theme lacks it.
            readonly property string icon: {
                const i = modelData.icon;
                return !i ? "" : i.startsWith("/") ? "file://" + i : Quickshell.iconPath(i, true);
            }

            x: 12
            y: root.rowY(index)
            width: 216
            height: 24
            radius: 8
            color: current ? U.Palette.line : "transparent"

            IconImage {
                id: glyph
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: row.icon.length > 0
                source: row.icon
                implicitSize: 16
            }
            // No icon in the theme: a plain app glyph.
            Text {
                anchors.centerIn: glyph
                visible: !glyph.visible
                text: "󰣆"
                color: U.Palette.muted
                font { family: U.Palette.font; pixelSize: 14 }
            }

            Text {
                x: 32
                width: parent.width - x - 10
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                color: row.current ? U.Palette.bright : U.Palette.muted
                elide: Text.ElideRight
                font { family: U.Palette.font; pixelSize: 12 }
            }

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: root.choose(row.index)
            }
        }
    }
}
