// Time and date. Click for the power menu.
import QtQuick
import Quickshell

Chip {
    icon: "󰥔"
    label: Qt.formatDateTime(clock.date, "HH:mm · ddd d MMM")
    onClicked: Quickshell.execDetached(["rice-menu", "power"])

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
