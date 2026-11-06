// Workspace pills for one output. The active one stretches and fills in.
import QtQuick

Row {
    id: root

    property string output: ""
    readonly property var list: Niri.workspacesOn(root.output)
    readonly property int activeIdx: list.find(w => w.isActive)?.idx ?? -1

    // Centre of the active pill, in this row's coordinates.
    function activeCenter() {
        const i = list.findIndex(w => w.isActive), item = i >= 0 ? pills.itemAt(i) : null;
        return item ? item.x + item.width / 2 : width / 2;
    }

    spacing: 6

    Repeater {
        id: pills
        model: root.list

        Rectangle {
            required property var modelData

            width: modelData.isActive ? 34 : 24
            height: 24
            radius: 12
            color: modelData.isActive ? Theme.primary : (hover.hovered ? Qt.alpha(Theme.text, 0.18) : Qt.alpha(Theme.text, 0.08))
            anchors.verticalCenter: parent.verticalCenter

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 160 }
            }

            Text {
                anchors.centerIn: parent
                text: modelData.idx
                color: modelData.isActive ? Theme.textOnPrimary : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Niri.focusWorkspace(modelData.idx)
            }
        }
    }
}
