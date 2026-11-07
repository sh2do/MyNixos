// Time and date: the time bold, the date faint. Click for the power menu.
import QtQuick
import Quickshell

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 24
    radius: 10
    color: hover.hovered ? Qt.alpha(Theme.text, 0.10) : "transparent"

    Behavior on color {
        ColorAnimation { duration: 160 }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: Theme.outline
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: Quickshell.execDetached(["rice-menu", "power"])
    }
}
