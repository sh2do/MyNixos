// What one screen shows while locked: the rain video, a big clock, the date
// and the password field. A wrong password shakes the field.
import QtQuick
import QtMultimedia
import Quickshell

Item {
    id: surface

    required property var lockRoot

    Video {
        anchors.fill: parent
        source: Qt.resolvedUrl("lock.mp4")
        fillMode: VideoOutput.PreserveAspectCrop
        loops: MediaPlayer.Infinite
        muted: true
        autoPlay: true
    }

    // Darken the bottom so the text reads on any frame.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.surface, 0.75) }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    LockExtras {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.14
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 96
            font.weight: Font.Light
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            color: Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize + 5
        }

        Item {
            width: 1
            height: 22
        }

        Rectangle {
            id: field

            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 46
            radius: height / 2
            color: Qt.alpha(Theme.surface, 0.7)
            border.width: 1
            border.color: input.activeFocus ? Theme.primary : Qt.alpha(Theme.primary, 0.3)

            transform: Translate { id: shakeOffset }

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: shakeOffset; property: "x"; to: -12; duration: 50; easing.type: Easing.OutQuad }
                NumberAnimation { target: shakeOffset; property: "x"; to: 12; duration: 80; easing.type: Easing.InOutQuad }
                NumberAnimation { target: shakeOffset; property: "x"; to: 0; duration: 50; easing.type: Easing.InQuad }
            }

            Connections {
                target: surface.lockRoot

                function onFailed() {
                    shake.restart();
                }
            }

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 3
                focus: true
                enabled: !surface.lockRoot.busy
                Component.onCompleted: forceActiveFocus()

                // Keep the text in sync across screens.
                text: surface.lockRoot.password
                onTextChanged: surface.lockRoot.password = text

                onAccepted: surface.lockRoot.submit()
                Keys.onEscapePressed: surface.lockRoot.password = ""
            }

            Text {
                anchors.centerIn: parent
                visible: input.text.length === 0
                text: surface.lockRoot.busy ? "checking…" : "password"
                color: Qt.alpha(Theme.textMuted, 0.6)
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize + 1
            }
        }
    }
}
