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
    // Koi swim inside the bar; RICE_MASCOT=raven perches a raven on it instead.
    readonly property bool raven: Quickshell.env("RICE_MASCOT") === "raven"
    property bool shown: pinned

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-bar"
    color: "transparent"
    readonly property int restGap: 8
    // Room above the pill for the raven (44 px, plus its hops).
    implicitHeight: Theme.barHeight + restGap + (raven ? 60 : 4)

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

    Rectangle {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? parent.height - height - root.restGap : parent.height + 4
        width: content.implicitWidth + 26
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
            visible: !root.raven
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
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Workspaces {
                id: workspaces
                output: root.modelData.name
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 8; height: 1 }

            Toggles {
                id: toggles
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: 8; height: 1 }

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

    // The raven, its feet on the pill's top edge near the right end; it goes
    // with the pill as it slides and fades.
    Loader {
        id: perched
        anchors.fill: parent
        active: root.raven
        sourceComponent: Raven {
            readonly property real perchInset: 34
            perchY: bar.y
            homeX: bar.x + bar.width - perchInset
            noticeY: bar.y + bar.height / 2
            reachLeft: bar.width - 2 * perchInset
            opacity: bar.opacity
            visible: opacity > 0
            running: root.shown
            hoverX: barHover.hovered ? bar.x + barHover.point.position.x : NaN
            hoverY: barHover.hovered ? bar.y + barHover.point.position.y : NaN
        }
    }

    // The mascot reacts to the bar: a workspace you switch to, or a volume or
    // brightness change, makes the raven turn and caw at it, or the koi
    // startle. x is in pill coordinates.
    function notice(x) {
        if (perched.item)
            perched.item.notice(bar.x + x);
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
}
