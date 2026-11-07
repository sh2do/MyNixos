// The bottom-right corner's contents: faint wifi, bluetooth and battery.
// Small and low in contrast on purpose; it only reports. The python's window
// (Python.qml) hosts it between its coils.
//
// glyphs: the row's own rectangle in this item's coordinates, for the coils
// to wrap.
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import "." as U

Item {
    id: root

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real pct: (battery?.percentage ?? 0) * 100
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging
    readonly property rect glyphs: Qt.rect(row.x, row.y, row.width, row.height)

    implicitWidth: row.width + 16
    implicitHeight: 28

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        spacing: 10

        Text {
            text: !Networking.wifiEnabled ? "󰖪" : (root.wifiNetwork ? "󰖩" : "󰤯")
            color: U.Palette.muted
            opacity: 0.7
            font { family: U.Palette.font; pixelSize: 11 }
        }
        Text {
            text: root.adapter?.enabled ? "󰂯" : "󰂲"
            color: U.Palette.muted
            opacity: 0.7
            font { family: U.Palette.font; pixelSize: 11 }
        }
        Text {
            visible: root.hasBattery
            text: (root.charging ? "󰂄" : root.pct > 80 ? "󰁹" : root.pct > 50 ? "󰁾" : root.pct > 20 ? "󰁼" : "󰁺")
                + " " + Math.round(root.pct)
            color: U.Palette.muted
            opacity: 0.7
            font { family: U.Palette.font; pixelSize: 11 }
        }
    }
}
