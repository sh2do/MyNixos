// Small pond-glass pills low on the lock screen: now playing (art, title,
// artist, previous / play-pause / next), the paired phone's battery and the
// weather. Each shows only when it has something to show. Media is limited to
// those three buttons. Shares media.js, phone.js and weather.js with the shell.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "media.js" as Media
import "lock.js" as L

Row {
    id: root

    spacing: 10

    // The last player that played stays (paused) so play can resume it.
    property var held: null
    readonly property var player: Media.pickPlayer(Mpris.players.values, held, true,
        MprisPlaybackState.Playing, MprisPlaybackState.Paused)
    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing
    onIsPlayingChanged: if (isPlaying) held = player

    readonly property var lines: player
        ? L.cardLines(player.trackTitle, player.trackArtist, player.trackAlbum, player.identity)
        : ({ top: "", bottom: "" })

    // One slab of glass: the bar's surface, rim and faint top light.
    component Glass: Rectangle {
        radius: height / 2
        color: Qt.alpha(Theme.surface, 0.78)
        border.width: 1
        border.color: Qt.alpha(Theme.primary, 0.22)

        Rectangle {
            anchors.top: parent.top
            anchors.topMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.radius * 1.4
            height: 1
            color: Qt.alpha("white", 0.12)
        }
    }

    component Btn: Item {
        id: btn
        property string glyph
        signal clicked
        width: 28
        height: 28

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Qt.alpha(Theme.primary, area.containsMouse ? 0.22 : 0)
        }
        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 4
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component Chip: Glass {
        id: chip
        property string glyph
        property string label
        height: 44
        width: chipRow.implicitWidth + 28

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                color: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 5
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
        }
    }

    // ---- Now playing
    Glass {
        visible: L.hasMedia(root.player)
        height: 44
        width: 44 + 8 + 160 + 8 + 3 * 28 + 12

        ClippingRectangle {
            id: art
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 32
            height: 32
            radius: 16
            color: Qt.alpha(Theme.primaryContainer, 0.6)

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 160

            Text {
                width: parent.width
                text: root.lines.top
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: root.lines.bottom
                elide: Text.ElideRight
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Btn {
                glyph: "󰒮"
                opacity: root.player?.canGoPrevious ? 1 : 0.35
                onClicked: if (root.player?.canGoPrevious) root.player.previous()
            }
            Btn {
                glyph: root.isPlaying ? "󰏤" : "󰐊"
                onClicked: if (root.player?.canTogglePlaying) root.player.togglePlaying()
            }
            Btn {
                glyph: "󰒭"
                opacity: root.player?.canGoNext ? 1 : 0.35
                onClicked: if (root.player?.canGoNext) root.player.next()
            }
        }
    }

    // ---- The paired phone
    Chip {
        visible: L.showPhone(Phone.paired, Phone.battery)
        glyph: "󰄜"
        label: Phone.battery
    }

    // ---- The weather
    Chip {
        visible: L.weatherGlyph(Weather.kind).length > 0
        glyph: L.weatherGlyph(Weather.kind, Weather.current?.isDay)
        label: L.weatherWord(Weather.kind)
    }
}
