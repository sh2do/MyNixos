// One item on the bottom bar: an icon, an optional label, and three actions.
// Filled when `active`, faint when not.
import QtQuick

Rectangle {
    id: chip

    property string icon: ""
    property string label: ""
    property bool active: false
    signal clicked
    signal rightClicked
    signal scrolled(int direction) // +1 up, -1 down

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 28
    radius: 10
    color: active ? Theme.primary : (hover.hovered ? Qt.alpha(Theme.text, 0.14) : Qt.alpha(Theme.text, 0.07))

    Behavior on color {
        ColorAnimation { duration: 160 }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: chip.icon
            color: chip.active ? Theme.textOnPrimary : Theme.primary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 2
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: chip.label.length > 0
            text: chip.label
            color: chip.active ? Theme.textOnPrimary : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
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
