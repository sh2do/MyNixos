// One item on the bottom bar: an icon, an optional label, and three actions.
// It sits bare on its stone; when `active` its icon is lit and a 3 px dot
// shows under it. Hovering gives it a faint patch.
import QtQuick

Rectangle {
    id: chip

    property string icon: ""
    property string label: ""
    property bool active: false
    property color iconColor: active ? Theme.primary : Theme.textMuted
    signal clicked
    signal rightClicked
    signal scrolled(int direction) // +1 up, -1 down

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 24
    radius: 10
    color: hover.hovered ? Qt.alpha(Theme.text, 0.10) : "transparent"

    Behavior on color {
        ColorAnimation { duration: 160 }
    }

    Row {
        id: row
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        spacing: 5

        Text {
            id: glyph
            text: chip.icon
            color: chip.iconColor
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: chip.label.length > 0
            text: chip.label
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // "On": a dot under the lit icon.
    Rectangle {
        visible: chip.active
        width: 3
        height: 3
        radius: 1.5
        color: Theme.primary
        x: row.x + glyph.x + glyph.width / 2 - width / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => mouse.button === Qt.RightButton ? chip.rightClicked() : chip.clicked()
        onWheel: wheel => chip.scrolled(wheel.angleDelta.y > 0 ? 1 : -1)
    }
}
