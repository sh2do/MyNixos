// The auto-hide bar. Hidden, it leaves a 3 px strip at the bottom edge that
// listens for the pointer; touching it slides the bar up. The bar slides back
// down shortly after the pointer leaves. Top layer: fullscreen windows hide it.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // RICE_BAR_PINNED=1 keeps the bar up (handy while restyling it).
    readonly property bool pinned: Quickshell.env("RICE_BAR_PINNED") === "1"
    // Koi swim inside the bar; RICE_MASCOT=python wraps it in the python instead.
    readonly property bool python: Quickshell.env("RICE_MASCOT") === "python"
    property bool shown: pinned

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-bar"
    color: "transparent"
    // Room for the python: the pill rests higher (lower loops below it) and the
    // head rises above it.
    readonly property int bodyW: Math.round(Theme.barHeight * 0.5)
    readonly property int restGap: python ? 8 + bodyW + 1 : 8
    implicitHeight: Theme.barHeight + restGap + (python ? 64 : 4)

    // Only the visible part takes input; the rest passes clicks through.
    mask: Region {
        item: root.shown ? bar : edge
    }

    Item {
        id: edge
        anchors.bottom: parent.bottom
        width: parent.width
        height: 3

        HoverHandler {
            onHoveredChanged: if (hovered) {
                hideTimer.stop();
                root.shown = true;
            }
        }
    }

    Loader {
        active: root.python
        sourceComponent: Python {
            pill: bar
            gaps: root.gaps
            side: "back"
            t: front.item ? front.item.t : 0
            slide: front.item ? front.item.slide : 0
            squeeze: front.item ? front.item.squeeze : 0
            flinch: front.item ? front.item.flinch : 0
            texture: front.item ? front.item.texture : null
        }
    }

    Rectangle {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? parent.height - height - root.restGap : parent.height + 4
        width: content.implicitWidth + root.leftPad + 12
        height: Theme.barHeight
        radius: Theme.radius
        color: Qt.alpha(Theme.surface, 0.82)
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.35)
        opacity: root.shown ? 1 : 0

        Behavior on y {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        HoverHandler {
            id: barHover
            onHoveredChanged: hovered ? hideTimer.stop() : hideTimer.restart()
        }

        Koi {
            id: pond
            visible: !root.python
            anchors.fill: parent
            anchors.margins: 1
            running: root.shown && visible
            hoverX: barHover.hovered ? barHover.point.position.x - 1 : NaN
            hoverY: barHover.hovered ? barHover.point.position.y - 1 : NaN
        }

        // A click on open water (not on a widget) feeds the koi.
        TapHandler {
            enabled: pond.visible
            onTapped: (point) => {
                // Workspace pills have their own TapHandler; leave their clicks alone.
                const p = content.mapFromItem(bar, point.position.x, point.position.y);
                if (!content.childAt(p.x, p.y))
                    pond.feed(point.position.x - 1, point.position.y - 1);
            }
        }

        Row {
            id: content
            x: root.leftPad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Workspaces {
                id: workspaces
                output: root.modelData.name
                anchors.verticalCenter: parent.verticalCenter
            }

            CoilGap {}

            Toggles {
                id: toggles
                anchors.verticalCenter: parent.verticalCenter
            }

            CoilGap {}

            Clock {
                id: clock
                anchors.verticalCenter: parent.verticalCenter
            }

            Chip {
                icon: "⏻"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Quickshell.execDetached(["rice-menu", "power"])
            }
        }
    }

    Loader {
        id: front
        active: root.python
        sourceComponent: Python {
            pill: bar
            gaps: root.gaps
            side: "front"
            running: root.shown
            hoverX: barHover.hovered ? barHover.point.position.x : NaN
        }
    }

    // The mascot reacts to the bar: a workspace you switch to, or a volume or
    // brightness change, makes the python look and flinch, or the koi startle.
    function notice(x) {
        if (front.item)
            front.item.notice(x);
        else
            pond.notice(x - 1);
    }
    Connections {
        target: workspaces
        function onActiveIdxChanged() {
            root.notice(content.x + workspaces.x + workspaces.activeCenter());
        }
    }
    Connections {
        target: toggles
        function onPoked(chip) {
            root.notice(content.x + toggles.x + chip.x + chip.width / 2);
        }
    }

    Timer {
        id: hideTimer
        interval: 600
        onTriggered: root.shown = root.pinned
    }

    // The python's front crossings go in the gaps between widget groups (never
    // over a widget): one at the left end, and one in each CoilGap, which takes
    // the place of a separator line.
    // Without the python they are plain spacing.
    readonly property int leftPad: python ? bodyW + 19 : 14
    component CoilGap: Item {
        width: root.python ? root.bodyW + 6 : 8
        height: 1
    }

    // Free spans in pill coordinates; they follow the widgets as they resize.
    readonly property var gaps: [
        { x: 8, w: leftPad - 10 },
        { x: content.x + workspaces.x + workspaces.width + 2, w: toggles.x - workspaces.x - workspaces.width - 4 },
        { x: content.x + toggles.x + toggles.width + 2, w: clock.x - toggles.x - toggles.width - 4 }
    ]
}
