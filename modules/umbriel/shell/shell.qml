// Umbriel's shell ("qs -c umbriel"), started by Umbriel's autostart.
// Later tasks add the corners, island and launcher here.
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

    Picker {
        background: wallpaper
    }
}
