// SDDM greeter for the rice: the train landscape video, a big clock, and a
// card of pond glass (the bar's and rofi's glass: frosted, a lit top rim,
// drips) holding the last user's avatar, a password field and a quiet session
// picker under it (niri or Umbriel; click it or press Left/Right to cycle).
// Colours and the video file come from theme.conf; drips.png and hang.png are
// rendered in those colours by the theme's derivation (modules/sddm).
import QtQuick
import QtQuick.Effects
import QtMultimedia

Item {
    id: root

    width: 1920
    height: 1080

    readonly property color primary: config.stringValue("primary")
    readonly property color textOnPrimary: config.stringValue("onPrimary")
    readonly property color surface: config.stringValue("surface")
    readonly property color text: config.stringValue("text")
    readonly property color textMuted: config.stringValue("textMuted")
    readonly property color error: config.stringValue("error")
    readonly property string fontFamily: config.stringValue("font")
    // The clock sits on the video's bright sky, so it is dark, unlike the rest.
    readonly property color clockColour: config.stringValue("clock")

    property string userName: userModel.lastUser
    property string realName: ""
    property string avatar: ""
    property bool busy: false
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property var sessionNames: []

    // Collect the session names, in model order, for the picker.
    Repeater {
        id: sessions
        model: sessionModel

        Item {
            required property int index
            required property string name

            Component.onCompleted: {
                const names = root.sessionNames.slice();
                names[index] = name;
                root.sessionNames = names;
            }
        }
    }

    function cycleSession(step) {
        if (busy || sessions.count < 2)
            return;
        sessionIndex = (sessionIndex + step + sessions.count) % sessions.count;
    }

    // Pick up the last user's display name and avatar from the user model.
    Repeater {
        model: userModel

        Item {
            required property string name
            required property string realName
            required property string icon

            Component.onCompleted: {
                if (root.userName === "")
                    root.userName = name;
                if (name === root.userName) {
                    root.realName = realName;
                    root.avatar = icon;
                }
            }
        }
    }

    function login() {
        if (busy || password.text.length === 0)
            return;
        busy = true;
        message.text = "";
        sddm.login(userName, password.text, sessionIndex);
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.busy = false;
            password.text = "";
            message.text = "wrong password";
            shake.restart();
            password.forceActiveFocus();
        }

        function onLoginSucceeded() {
            message.text = "";
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.surface
    }

    Video {
        id: video
        anchors.fill: parent
        source: Qt.resolvedUrl(config.stringValue("background"))
        fillMode: VideoOutput.PreserveAspectCrop
        loops: MediaPlayer.Infinite
        muted: true
        autoPlay: true
    }

    // Darken the bottom so the text reads on any frame.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.35; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(root.surface, 0.8) }
        }
    }

    Timer {
        id: tick
        property date now: new Date()
        interval: 1000
        running: true
        repeat: true
        onTriggered: now = new Date()
    }

    Column {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 64
        spacing: 4

        Text {
            text: Qt.formatTime(tick.now, "HH:mm")
            color: root.clockColour
            font.family: root.fontFamily
            font.pixelSize: 104
            font.weight: Font.Light
        }

        Text {
            text: Qt.formatDate(tick.now, "dddd, d MMMM")
            color: Qt.alpha(root.clockColour, 0.75)
            font.family: root.fontFamily
            font.pixelSize: 20
        }
    }

    // ---- The login card: a slab of pond glass, as the bar and rofi have it.
    // The video frosted behind it, a translucent tint, a faint depth gradient,
    // a reflection band and a lit top rim; water gathered along its lower
    // edge (rofi's drips) and a few drops hanging under it. All static.
    readonly property real cardRadius: 22

    // A soft shadow under the slab.
    RectangularShadow {
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        offset.y: 10
        spread: -6
        blur: 22
        radius: root.cardRadius
        color: Qt.alpha("black", 0.4)
    }

    // The video behind the card, blurred: frosted glass.
    ShaderEffectSource {
        id: behind
        sourceItem: video
        sourceRect: Qt.rect(card.x, card.y, card.width, card.height)
        // MultiEffect sizes itself from its source: without a size, nothing shows.
        width: card.width
        height: card.height
        visible: false
    }
    Rectangle {
        id: cardMask
        width: card.width
        height: card.height
        radius: root.cardRadius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        source: behind
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 48
        saturation: -0.2
        maskEnabled: true
        maskSource: cardMask
    }

    Rectangle {
        id: card

        width: 418
        // Room for the avatar's lower half above the content, and for the
        // gathered water below it.
        height: cardContent.y + cardContent.implicitHeight + 40
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - root.height * 0.1 - height)
        radius: root.cardRadius
        color: Qt.alpha(root.surface, 0.7)
        border.width: 1
        border.color: Qt.alpha(root.primary, 0.22)

        // Depth: a little light from above, a little shade below.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(root.primary, 0.08) }
                GradientStop { position: 0.5; color: Qt.alpha(root.surface, 0) }
                GradientStop { position: 1; color: Qt.alpha("black", 0.28) }
            }
        }
        // The reflection band under the rim.
        Rectangle {
            x: 14
            y: 2
            width: parent.width - 28
            height: 16
            radius: 8
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha("white", 0.06) }
                GradientStop { position: 1; color: Qt.alpha("white", 0) }
            }
        }
        // The rim's highlight, brightest in the middle.
        Rectangle {
            x: 20
            y: 1
            width: parent.width - 40
            height: 1.5
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.alpha("white", 0) }
                GradientStop { position: 0.35; color: Qt.alpha("white", 0.3) }
                GradientStop { position: 0.6; color: Qt.alpha("white", 0.14) }
                GradientStop { position: 0.8; color: Qt.alpha("white", 0.24) }
                GradientStop { position: 1; color: Qt.alpha("white", 0) }
            }
        }
        // Water run down the glass, gathered at the bottom edge (418 x 46).
        Image {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            anchors.horizontalCenter: parent.horizontalCenter
            width: 418
            height: 46
            source: "drips.png"
            sourceSize: Qt.size(836, 92)
            opacity: 0.9
        }
        // Drops hanging under the lower edge.
        Image {
            anchors.top: parent.bottom
            anchors.topMargin: -1
            anchors.horizontalCenter: parent.horizontalCenter
            width: 418
            height: 24
            source: "hang.png"
            sourceSize: Qt.size(836, 48)
        }

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: shakeOffset; property: "x"; to: -12; duration: 50; easing.type: Easing.OutQuad }
            NumberAnimation { target: shakeOffset; property: "x"; to: 12; duration: 80; easing.type: Easing.InOutQuad }
            NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 50; easing.type: Easing.InQuad }
        }

        // Avatar: the AccountsService picture, or the first letter of the
        // name; it sits on the card's top edge, half above the glass.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height / 2
            width: 96
            height: 96
            radius: 48
            color: Qt.alpha(root.surface, 0.85)
            border.width: 2
            border.color: root.primary
            clip: true

            Image {
                id: face
                anchors.fill: parent
                anchors.margins: 3
                source: root.avatar
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            Rectangle {
                id: faceMask
                anchors.fill: face
                radius: width / 2
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: face
                visible: face.status === Image.Ready
                source: face
                maskEnabled: true
                maskSource: faceMask
            }

            Text {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: (root.realName || root.userName).charAt(0).toUpperCase()
                color: root.primary
                font.family: root.fontFamily
                font.pixelSize: 40
            }
        }

        Column {
            id: cardContent

            anchors.horizontalCenter: parent.horizontalCenter
            y: 48 + 16
            spacing: 14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.realName || root.userName
                color: root.text
                font.family: root.fontFamily
                font.pixelSize: 20
            }

            // The password field: a raised pane of glass in the card.
            Rectangle {
                id: field

                anchors.horizontalCenter: parent.horizontalCenter
                width: 320
                height: 48
                radius: height / 2
                color: Qt.alpha(root.surface, 0.55)
                border.width: 1
                border.color: password.activeFocus ? Qt.alpha(root.primary, 0.75) : Qt.alpha(root.primary, 0.25)

                // A wrong password shakes the field (the card's glass stays put).
                transform: Translate { id: shakeOffset }

                Behavior on border.color {
                    ColorAnimation { duration: 140 }
                }

                // Its own small rim of light.
                Rectangle {
                    x: 24
                    y: 1
                    width: parent.width - 48
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha("white", 0) }
                        GradientStop { position: 0.5; color: Qt.alpha("white", 0.16) }
                        GradientStop { position: 1; color: Qt.alpha("white", 0) }
                    }
                }

                TextInput {
                    id: password

                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: root.text
                    font.family: root.fontFamily
                    font.pixelSize: 17
                    focus: true
                    enabled: !root.busy
                    Component.onCompleted: forceActiveFocus()
                    onAccepted: root.login()
                    // The password is hidden, so the arrows pick the session instead.
                    Keys.onLeftPressed: root.cycleSession(-1)
                    Keys.onRightPressed: root.cycleSession(1)
                }

                Text {
                    anchors.centerIn: parent
                    visible: password.text.length === 0
                    text: root.busy ? "logging in…" : "password"
                    color: Qt.alpha(root.textMuted, 0.6)
                    font.family: root.fontFamily
                    font.pixelSize: 15
                }
            }

            // Session picker: "‹ niri ›", muted until hovered.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: sessions.count > 1
                text: "‹  " + (root.sessionNames[root.sessionIndex] || "").toLowerCase() + "  ›"
                color: Qt.alpha(root.textMuted, sessionHover.hovered ? 0.95 : 0.6)
                font.family: root.fontFamily
                font.pixelSize: 14

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                HoverHandler {
                    id: sessionHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onTapped: (point, button) => root.cycleSession(button === Qt.RightButton ? -1 : 1)
                }
            }

            Text {
                id: message
                anchors.horizontalCenter: parent.horizontalCenter
                height: 20
                color: root.error
                font.family: root.fontFamily
                font.pixelSize: 14
            }
        }
    }

    // Suspend, reboot, power off.
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 40
        spacing: 12

        Repeater {
            model: [
                { icon: "󰤄", label: "suspend", enabled: sddm.canSuspend, run: () => sddm.suspend() },
                { icon: "󰜉", label: "reboot", enabled: sddm.canReboot, run: () => sddm.reboot() },
                { icon: "󰐥", label: "power off", enabled: sddm.canPowerOff, run: () => sddm.powerOff() }
            ]

            Rectangle {
                required property var modelData

                visible: modelData.enabled
                width: 48
                height: 48
                radius: 24
                color: hover.hovered ? Qt.alpha(root.primary, 0.25) : Qt.alpha(root.surface, 0.6)
                border.width: 1
                border.color: Qt.alpha(root.primary, 0.3)

                // A glint of the card's rim on each pebble of glass.
                Rectangle {
                    x: 12
                    y: 1
                    width: parent.width - 24
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha("white", 0) }
                        GradientStop { position: 0.5; color: Qt.alpha("white", 0.22) }
                        GradientStop { position: 1; color: Qt.alpha("white", 0) }
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 140 }
                }

                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    color: root.primary
                    font.family: root.fontFamily
                    font.pixelSize: 20
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: modelData.run()
                }
            }
        }
    }
}
