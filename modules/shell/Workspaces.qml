// Workspace pills for one output. The active one is a glowing capsule; the
// others are bare numbers.
import QtQuick
import QtQuick.Effects

Row {
    id: root

    property string output: ""
    readonly property var list: Niri.workspacesOn(root.output)
    readonly property int activeIdx: list.find(w => w.isActive)?.idx ?? -1

    // The active workspace changed from one to another (not the first sync
    // at startup, when the list arrives).
    signal switched
    property int seenIdx: -1
    onActiveIdxChanged: {
        if (seenIdx !== -1 && activeIdx !== -1)
            switched();
        if (activeIdx !== -1)
            seenIdx = activeIdx;
    }

    // Centre of the active pill, in this row's coordinates.
    function activeCenter() {
        const i = list.findIndex(w => w.isActive), item = i >= 0 ? pills.itemAt(i) : null;
        return item ? item.x + item.width / 2 : width / 2;
    }

    spacing: 4

    Repeater {
        id: pills
        model: root.list

        Rectangle {
            id: pill
            required property var modelData
            readonly property bool active: modelData.isActive

            width: active ? 38 : 24
            height: 24
            radius: 12
            color: active ? Theme.primary : (hover.hovered ? Qt.alpha(Theme.text, 0.10) : Qt.alpha(Theme.text, 0))
            anchors.verticalCenter: parent.verticalCenter

            Behavior on width {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 160 }
            }

            // The capsule's glow (a static shader; it only follows the pill).
            RectangularShadow {
                z: -1
                anchors.fill: parent
                visible: pill.active
                radius: pill.radius
                blur: 8
                color: Qt.alpha(Theme.primary, 0.55)
            }

            Text {
                anchors.centerIn: parent
                text: pill.modelData.idx
                color: pill.active ? Theme.textOnPrimary : Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
                font.bold: pill.active
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Niri.focusWorkspace(pill.modelData.idx)
            }
        }
    }
}
