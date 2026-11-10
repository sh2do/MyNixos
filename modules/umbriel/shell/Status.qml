// Bottom-right corner: focus mode's moon and how long so far (while on,
// Focus.qml), faint phone (when one is paired, Phone.qml), wifi,
// bluetooth, fan boost (while on), the power profile and battery. Small and
// low in contrast on purpose; it mostly reports (the profile glyph cycles on
// a click). The raven perches on its left edge, so it moves with the phone.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import "." as U
import "power.js" as Pw

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
    readonly property var profileNames: ({
        [PowerProfile.PowerSaver]: "power-saver",
        [PowerProfile.Balanced]: "balanced",
        [PowerProfile.Performance]: "performance"
    })
    readonly property var profileValues: ({
        "power-saver": PowerProfile.PowerSaver,
        "balanced": PowerProfile.Balanced,
        "performance": PowerProfile.Performance
    })

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: 8
        spacing: 10

        // Focus mode, a little brighter than the rest: it is a state you chose.
        Text {
            visible: U.Focus.on
            text: "󰽥 focus " + U.Focus.label
            color: U.Palette.text
            opacity: 0.85
            font { family: U.Palette.font; pixelSize: 11 }
        }
        // The paired phone: its battery while reachable, a crossed-out phone
        // when it's away.
        Text {
            visible: U.Phone.paired
            text: (U.Phone.reachable ? "󰄜" : "󰥐") + (U.Phone.battery ? " " + U.Phone.battery : "")
            color: U.Palette.muted
            opacity: 0.7
            font { family: U.Palette.font; pixelSize: 11 }
        }
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
        // Fan boost (Fan.qml), only while the fans are held at max; a click
        // hands them back to the firmware.
        Text {
            visible: U.Fan.boost
            text: "󰈐"
            color: U.Palette.text
            opacity: 0.85
            font { family: U.Palette.font; pixelSize: 11 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: U.Fan.toggle()
            }
        }
        // The power profile (power.js); a click cycles it.
        Text {
            readonly property string profile: root.profileNames[PowerProfiles.profile] ?? ""
            text: Pw.glyph(profile)
            color: U.Palette.muted
            opacity: 0.7
            font { family: U.Palette.font; pixelSize: 11 }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: PowerProfiles.profile = root.profileValues[Pw.next(parent.profile, PowerProfiles.hasPerformanceProfile)]
            }
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
