// The auto-hide bar, a slab of pond glass: a lit top rim, a faint depth
// gradient and reflection band, the widgets on three faint stones, and koi
// under the glass. Hidden, it leaves a 120 x 2 px water line at the bottom
// edge; touching the edge slides the bar up. The bar slides back down shortly
// after the pointer leaves. Top layer: fullscreen windows hide it.
// Every decoration is static: drawn once, it only moves with the bar.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import "media.js" as Media

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // RICE_BAR_PINNED=1 keeps the bar up (handy while restyling it).
    readonly property bool pinned: Quickshell.env("RICE_BAR_PINNED") === "1"
    // Koi swim inside the bar; RICE_MASCOT=raven perches a raven on it instead.
    readonly property bool raven: Quickshell.env("RICE_MASCOT") === "raven"
    // The music the top pill plays: the mascot moves to it (null: none).
    readonly property var player: Media.pickPlayer(Mpris.players.values, null, false,
        MprisPlaybackState.Playing, MprisPlaybackState.Paused)
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
            // Raised by the edge, it hides again unless the pointer enters the bar.
            onHoveredChanged: if (hovered) {
                root.shown = true;
                hideTimer.restart();
            }
        }
    }

    // Hidden: a faint glowing water line marks where the bar is.
    Rectangle {
        id: waterLine
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: 120
        height: 2
        radius: 1
        color: Qt.alpha(Theme.primary, 0.4)
        opacity: root.shown ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        RectangularShadow {
            z: -1
            anchors.fill: parent
            spread: 2
            blur: 8
            radius: 4
            color: Qt.alpha(Theme.primary, 0.18)
        }
    }

    // The bar's drop shadow: 8 px down, a little inset, soft.
    RectangularShadow {
        x: bar.x
        y: bar.y
        width: bar.width
        height: bar.height
        offset.y: 8
        spread: -4
        blur: 8
        radius: bar.radius
        color: Qt.alpha("black", 0.45)
        opacity: bar.opacity
        visible: opacity > 0
    }

    // A widget group's faint stone.
    component Stone: Rectangle {
        implicitHeight: 28
        radius: 12
        color: Qt.alpha(Theme.text, 0.05)
        border.width: 1
        border.color: Qt.alpha(Theme.text, 0.07)
        anchors.verticalCenter: parent.verticalCenter
    }

    Rectangle {
        id: bar

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown ? parent.height - height - root.restGap : parent.height + 4
        width: content.implicitWidth + 20
        height: Theme.barHeight
        radius: 16
        color: Qt.alpha(Theme.surface, 0.78)
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.22)
        opacity: root.shown ? 1 : 0
        visible: opacity > 0

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

        // Depth: lit from above, darker toward the bottom.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: bar.radius - 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Theme.primary, 0.07) }
                GradientStop { position: 0.5; color: Qt.alpha(Theme.surface, 0) }
                GradientStop { position: 1; color: Qt.alpha("black", 0.3) }
            }
        }

        Koi {
            id: pond
            visible: !root.raven
            anchors.fill: parent
            anchors.margins: 1
            running: root.shown && visible
            hoverX: barHover.hovered ? barHover.point.position.x - 1 : NaN
            hoverY: barHover.hovered ? barHover.point.position.y - 1 : NaN
            music: root.player !== null
            song: root.player ? [root.player.trackArtist, root.player.trackTitle].join("\n") : ""
        }

        // The glass over the koi: a reflection band under the rim, and the
        // rim's highlight, brightest in the middle.
        Rectangle {
            x: 12
            y: 2
            width: parent.width - 24
            height: 12
            radius: 6
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha("white", 0.05) }
                GradientStop { position: 1; color: Qt.alpha("white", 0) }
            }
        }
        Rectangle {
            x: 16
            y: 1
            width: parent.width - 32
            height: 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha("white", 0) }
                GradientStop { position: 0.5; color: Qt.alpha("white", 0.22) }
                GradientStop { position: 1; color: Qt.alpha("white", 0) }
            }
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
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 22

            Stone {
                width: workspaces.implicitWidth + 12

                Workspaces {
                    id: workspaces
                    output: root.modelData.name
                    anchors.centerIn: parent
                }
            }

            Stone {
                width: toggles.implicitWidth + 8

                Toggles {
                    id: toggles
                    anchors.centerIn: parent
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                Stone {
                    width: clock.implicitWidth + 4

                    Clock {
                        id: clock
                        anchors.centerIn: parent
                    }
                }

                // The paired phone (Phone.qml); hidden when none is paired.
                Stone {
                    visible: Phone.paired
                    width: phoneChip.implicitWidth + 4

                    PhoneChip {
                        id: phoneChip
                        anchors.centerIn: parent
                    }
                }

                Stone {
                    width: 28
                    radius: 14

                    Chip {
                        anchors.centerIn: parent
                        width: 24
                        radius: 12
                        icon: "⏻"
                        iconColor: Theme.tertiary
                        onClicked: Quickshell.execDetached(["rice-menu", "power"])
                    }
                }
            }
        }
    }

    // The raven, its feet on the glass's top rim near the right end; it goes
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
            music: root.player !== null
            hoverX: barHover.hovered ? bar.x + barHover.point.position.x : NaN
            hoverY: barHover.hovered ? bar.y + barHover.point.position.y : NaN
        }
    }

    // The mascot reacts to the bar: a workspace you switch to, or a volume or
    // brightness change, makes the raven turn and caw at it, or the koi
    // startle. x is in pill coordinates. Not while the values first arrive at
    // startup (the workspaces, the sink and the brightness all "change" then).
    property bool settled: false
    Timer {
        running: true
        interval: 2000
        onTriggered: root.settled = true
    }
    function notice(x) {
        if (!settled)
            return;
        if (perched.item)
            perched.item.notice(bar.x + x);
        else
            pond.notice(x - 1);
    }
    Connections {
        target: workspaces
        function onSwitched() {
            root.notice(workspaces.mapToItem(bar, workspaces.activeCenter(), 0).x);
        }
    }
    Connections {
        target: toggles
        function onPoked(chip) {
            root.notice(chip.mapToItem(bar, chip.width / 2, 0).x);
        }
    }

    Timer {
        id: hideTimer
        interval: 600
        onTriggered: root.shown = root.pinned
    }
}
