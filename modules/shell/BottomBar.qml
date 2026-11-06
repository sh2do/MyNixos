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
    property bool shown: pinned

    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "rice-bar"
    color: "transparent"
    implicitHeight: Theme.barHeight + 16

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
        y: root.shown ? parent.height - height - 8 : parent.height + 4
        width: content.implicitWidth + 24
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
            onHoveredChanged: hovered ? hideTimer.stop() : hideTimer.restart()
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 10

            Cobra {
                id: cobra
                running: root.shown
                anchors.verticalCenter: parent.verticalCenter
            }

            Workspaces {
                output: root.modelData.name
                anchors.verticalCenter: parent.verticalCenter
            }

            Separator {}

            Toggles {
                anchors.verticalCenter: parent.verticalCenter
            }

            Separator {}

            Clock {
                anchors.verticalCenter: parent.verticalCenter
            }

            Chip {
                icon: "⏻"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Quickshell.execDetached(["rice-menu", "power"])
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 600
        onTriggered: root.shown = root.pinned
    }

    component Separator: Rectangle {
        width: 1
        height: 18
        color: Qt.alpha(Theme.outline, 0.5)
        anchors.verticalCenter: parent.verticalCenter
    }
}
