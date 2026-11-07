// Umbriel's shell ("qs -c umbriel"), started by Umbriel's autostart.
// Later tasks add the launcher here.
import QtQuick
import Quickshell

ShellRoot {
    id: root

    // The laptop panel; elements that exist once go here.
    readonly property var primary: Quickshell.screens.find(s => s.name === "eDP-2") ?? Quickshell.screens[0]

    Background {
        id: wallpaper
        screen: root.primary
    }

    Chain {
        screen: root.primary
    }

    Status {
        id: status
        screen: root.primary
    }

    Island {
        id: island
        screen: root.primary
    }

    Raven {
        screen: root.primary
        island: island
        status: status
    }

    Picker {
        background: wallpaper
    }
}
