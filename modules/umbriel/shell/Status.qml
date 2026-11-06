// Bottom-right corner: faint wifi, bluetooth and battery. Small and low in
// contrast on purpose; it only reports.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import "." as U

PanelWindow {
    id: root

    visible: !UmbrielIpc.fullscreen

    anchors {
        bottom: true
        right: true
    }
    margins {
        bottom: 14
        right: 20
    }
    implicitWidth: row.width + 16
    implicitHeight: 28
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "umbriel-status"

    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real pct: (battery?.percentage ?? 0) * 100
    readonly property bool charging: battery?.state === UPowerDeviceState.Charging

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
