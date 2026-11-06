// Notification toasts, stacked top-right under the pill. They leave after
// 5 s; critical ones stay until clicked. A click runs the default action.
// Clear them all with `qs -c rice ipc call notifications clear`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

Scope {
    id: root

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => n.tracked = true
    }

    IpcHandler {
        target: "notifications"

        function clear(): void {
            for (const n of server.trackedNotifications.values.slice())
                n.dismiss();
        }
    }

    PanelWindow {
        anchors.top: true
        anchors.right: true
        margins.top: 42
        margins.right: 12
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-notifications"
        color: "transparent"
        implicitWidth: 360
        implicitHeight: Math.max(1, stack.implicitHeight)
        visible: server.trackedNotifications.values.length > 0

        Column {
            id: stack
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                Item {
                    id: toast

                    required property var modelData
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    readonly property string iconSource: modelData.image || (modelData.appIcon ? Quickshell.iconPath(modelData.appIcon, true) : "")

                    width: stack.width
                    height: card.height

                    function activate() {
                        const action = modelData.actions.find(a => a.identifier === "default");
                        if (action)
                            action.invoke();
                        modelData.dismiss();
                    }

                    Timer {
                        running: !toast.critical
                        interval: 5000
                        onTriggered: toast.modelData.expire()
                    }

                    Rectangle {
                        id: card

                        width: parent.width
                        height: content.implicitHeight + 24
                        radius: Theme.radius
                        color: Qt.alpha(Theme.surface, 0.92)
                        border.width: 1
                        border.color: toast.critical ? Theme.error : Qt.alpha(Theme.primary, 0.3)

                        // Slide in from the right.
                        transform: Translate { id: slide; x: 0 }
                        Component.onCompleted: enter.start()

                        ParallelAnimation {
                            id: enter
                            NumberAnimation { target: slide; property: "x"; from: 380; to: 0; duration: 280; easing.type: Easing.OutCubic }
                            NumberAnimation { target: card; property: "opacity"; from: 0; to: 1; duration: 200 }
                        }

                        Row {
                            id: content
                            x: 12
                            y: 12
                            width: parent.width - 24
                            spacing: 12

                            IconImage {
                                visible: toast.iconSource.length > 0
                                source: toast.iconSource
                                implicitSize: 36
                            }

                            Column {
                                width: parent.width - (toast.iconSource.length > 0 ? 48 : 0)
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: toast.modelData.summary
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: toast.modelData.body
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                            }
                        }

                        TapHandler {
                            onTapped: toast.activate()
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }
}
