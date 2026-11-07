// The paired phone on the bar: its battery, and the "on" dot while it's
// reachable. Click to ring it; right-click to send it a file.
import QtQuick

Chip {
    icon: Phone.reachable ? "󰄜" : "󰥐"
    label: Phone.battery
    active: Phone.reachable
    onClicked: Phone.ring()
    onRightClicked: Phone.sendFile()
}
