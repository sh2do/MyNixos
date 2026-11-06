// The rice shell: top pill, auto-hide bottom bar, wallpaper picker, OSD and notifications.
// Run with `qs -c rice` (niri starts it at login). Colours: Theme.qml.
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        TopPill {}
    }

    Variants {
        model: Quickshell.screens
        BottomBar {}
    }

    WallpaperPicker {}
    Osd {}
    Notifications {}
}
