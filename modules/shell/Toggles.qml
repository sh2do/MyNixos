// Quick toggles (focus mode first). Left click acts, scroll adjusts, right click opens the
// matching rofi menu. Missing hardware shows as off (or hides, for battery).
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "power.js" as Pw

Row {
    id: root
    spacing: 2

    // A value on one of the chips changed (the mascot reacts to it).
    signal poked(Item chip)

    function menu(name) {
        Quickshell.execDetached(["rice-menu", name]);
    }

    // ---- focus mode (Focus.qml): the moon lit, and how long so far
    Chip {
        icon: "󰽥"
        label: Focus.on ? "focus " + Focus.label : ""
        active: Focus.on
        onClicked: Focus.toggle()
    }

    // ---- wifi
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice?.networks.values.find(n => n.connected) ?? null

    Chip {
        icon: !Networking.wifiEnabled ? "󰖪" : (root.wifiNetwork ? "󰖩" : "󰤯")
        label: root.wifiNetwork?.name ?? ""
        active: Networking.wifiEnabled && root.wifiDevice !== null
        onClicked: if (root.wifiDevice) Networking.wifiEnabled = !Networking.wifiEnabled
        onRightClicked: root.menu("wifi")
    }

    // ---- bluetooth
    readonly property var adapter: Bluetooth.defaultAdapter

    Chip {
        icon: root.adapter?.enabled ? "󰂯" : "󰂲"
        active: root.adapter?.enabled ?? false
        onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        onRightClicked: root.menu("bluetooth")
    }

    // ---- volume
    readonly property var sink: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: [root.sink]
    }

    Chip {
        readonly property real volume: root.sink?.audio?.volume ?? 0
        readonly property bool muted: root.sink?.audio?.muted ?? true
        onVolumeChanged: root.poked(this)
        onMutedChanged: root.poked(this)
        icon: muted ? "󰝟" : (volume > 0.5 ? "󰕾" : "󰖀")
        label: muted ? "muted" : Math.round(volume * 100) + "%"
        onClicked: if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted
        onScrolled: dir => {
            if (root.sink?.audio)
                root.sink.audio.volume = Math.max(0, Math.min(1, volume + dir * 0.05));
        }
        onRightClicked: root.menu("audio")
    }

    // ---- brightness
    Chip {
        visible: Brightness.available
        readonly property real level: Brightness.value
        onLevelChanged: root.poked(this)
        icon: "󰃠"
        label: Math.round(Brightness.value * 100) + "%"
        onScrolled: dir => Brightness.change(dir)
    }

    // ---- power profile: a glyph by the battery (power.js); click cycles,
    // right click opens the profile menu (with fan boost). Unplugging switches
    // to power-saver by itself (rice-power-auto, modules/power).
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

    Chip {
        readonly property string profile: root.profileNames[PowerProfiles.profile] ?? ""
        icon: Pw.glyph(profile)
        // Lit off the middle road: saving, or flat out.
        active: profile === "power-saver" || profile === "performance"
        onClicked: PowerProfiles.profile = root.profileValues[Pw.next(profile, PowerProfiles.hasPerformanceProfile)]
        onRightClicked: root.menu("profile")
    }

    // ---- fan boost (Fan.qml): only while the fans are held at max; a click
    // hands them back to the firmware.
    Chip {
        visible: Fan.boost
        icon: "󰈐"
        label: "boost"
        active: true
        onClicked: Fan.toggle()
        onRightClicked: root.menu("profile")
    }

    // ---- battery (hidden on machines without one)
    readonly property var battery: UPower.displayDevice

    Chip {
        readonly property real pct: (root.battery?.percentage ?? 0) * 100
        readonly property bool charging: root.battery?.state === UPowerDeviceState.Charging
        visible: root.battery?.isLaptopBattery ?? false
        icon: charging ? "󰂄" : (pct > 80 ? "󰁹" : pct > 50 ? "󰁾" : pct > 20 ? "󰁼" : "󰁺")
        label: Math.round(pct) + "%"
    }
}
