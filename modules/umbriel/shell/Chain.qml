// Top-left corner: one small chain link per workspace, drawn as an outline.
// Empty links are dim, occupied ones brighter, the active one bright with a
// faint glow. When the active workspace changes its link swings and settles.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as U

PanelWindow {
    id: root

    // Hidden (not just transparent) while a fullscreen window is focused, so
    // nothing renders or animates then.
    visible: !UmbrielIpc.fullscreen && UmbrielIpc.workspaces.length > 0

    anchors {
        top: true
        left: true
    }
    margins {
        top: 14
        left: 20
    }
    implicitWidth: row.width + 16
    implicitHeight: 28
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "umbriel-chain"

    // Links are 16x9 and overlap by 4 px.
    readonly property int linkW: 16
    readonly property int linkH: 9
    readonly property int overlap: 4

    Row {
        id: row
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: -root.overlap

        Repeater {
            model: UmbrielIpc.workspaces

            Item {
                id: link
                required property var modelData
                readonly property bool active: modelData.active
                width: root.linkW
                height: root.linkH
                // The active link rises above its neighbours.
                z: active ? 1 : 0
                transformOrigin: Item.Top

                // Swing when this link becomes the active one, but not when
                // it is created already active (first connect, reconnect).
                onActiveChanged: if (active) swing.restart()

                SequentialAnimation {
                    id: swing
                    NumberAnimation { target: link; property: "rotation"; to: -14; duration: 1; }
                    NumberAnimation { target: link; property: "rotation"; to: 9; duration: 170; easing.type: Easing.InOutSine }
                    NumberAnimation { target: link; property: "rotation"; to: -3; duration: 200; easing.type: Easing.InOutSine }
                    NumberAnimation { target: link; property: "rotation"; to: 0; duration: 230; easing.type: Easing.OutSine }
                }

                // Glow: two wider, fainter copies of the outline.
                Repeater {
                    model: link.active ? [5, 2.5] : []
                    Rectangle {
                        required property real modelData
                        anchors.centerIn: parent
                        width: root.linkW + modelData * 2
                        height: root.linkH + modelData * 2
                        radius: height / 2
                        color: "transparent"
                        border.width: 2
                        border.color: Qt.rgba(U.Palette.bright.r, U.Palette.bright.g, U.Palette.bright.b, 0.07)
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: "transparent"
                    border.width: 2
                    border.color: link.active ? U.Palette.bright
                        : link.modelData.occupied ? U.Palette.muted : U.Palette.line
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: UmbrielIpc.focusWorkspace(link.modelData.index)
                }
            }
        }
    }
}
