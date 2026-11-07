// Notification cards, top-right under the pill: one card per app (at most
// four), newest first. A card shows the app's icon, name, count and age, the
// latest message with its real action buttons, and up to two older ones
// peeking underneath (the chevron opens them). A 3 px line counts down the
// 5 s timeout; a new message from the app restarts it. Cards holding a
// critical message stay until clicked. A click runs the latest message's
// default action and dismisses the card.
// Clear them all with `qs -c rice ipc call notifications clear`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "notify-group.js" as Group

Scope {
    id: root

    readonly property int timeout: 5000

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => {
            root.stamps[n.id] = Date.now();
            n.tracked = true;
        }
    }

    IpcHandler {
        target: "notifications"

        function clear(): void {
            for (const n of server.trackedNotifications.values.slice())
                n.dismiss();
        }
    }

    // When each notification arrived, by id. The server doesn't keep it;
    // notifications kept over a reload count from when they are first seen.
    property var stamps: ({})
    function stamp(n) {
        if (root.stamps[n.id] === undefined)
            root.stamps[n.id] = Date.now();
        return root.stamps[n.id];
    }

    readonly property var notes: server.trackedNotifications.values
    readonly property var items: notes.map(n => ({
                id: n.id,
                app: n.appName || "unknown",
                icon: n.appIcon,
                summary: n.summary,
                body: n.body,
                time: root.stamp(n),
                urgency: n.urgency === NotificationUrgency.Critical ? "critical" : "normal",
                actions: n.actions,
                ref: n
            }))
    readonly property var groups: Group.group(items)

    // When each shown app's card appeared, for the slide-in and so a card
    // waiting behind the four shown ones gets its full timeout once shown.
    property var shownAt: ({})
    // Apps whose card is opened by the chevron.
    property var expanded: ({})
    property real now: Date.now()

    onGroupsChanged: {
        const t = Date.now(), seen = {}, open = {};
        for (const g of groups) {
            seen[g.app] = shownAt[g.app] ?? t;
            if (expanded[g.app])
                open[g.app] = true;
        }
        // Forget the stamps of notifications that are gone.
        const live = {};
        for (const n of notes)
            live[n.id] = true;
        for (const id of Object.keys(stamps))
            if (!live[id])
                delete stamps[id];
        now = t;
        shownAt = seen;
        expanded = open;
    }

    function shownSince(app) {
        return shownAt[app] ?? now;
    }

    function members(app) {
        return items.filter(i => i.app === app).map(i => i.ref);
    }

    function toggle(app) {
        const e = Object.assign({}, expanded);
        e[app] = !e[app];
        expanded = e;
    }

    // Runs the latest message's default action, then clears the card.
    function activate(g) {
        const action = g.latest.ref.actions.find(a => a.identifier === "default");
        if (action)
            action.invoke();
        for (const n of members(g.app))
            n.dismiss();
    }

    // One capped clock for the slide-in (60 Hz for its 280 ms), the timeout
    // lines (15 Hz: each frame of this window costs a few ms of CPU) and the
    // age labels (every 30 s once only critical cards are left). It stops
    // when no card is shown.
    readonly property bool entering: groups.some(g => now - shownSince(g.app) < 300)
    readonly property bool timing: groups.some(g => !g.critical)

    Timer {
        running: root.groups.length > 0
        repeat: true
        interval: root.entering ? 16 : (root.timing ? 66 : 30000)
        onTriggered: {
            root.now = Date.now();
            for (const g of root.groups)
                if (!g.critical && root.now >= Math.max(g.latest.time, root.shownSince(g.app)) + root.timeout)
                    for (const n of root.members(g.app))
                        n.expire();
        }
    }

    // An icon name or path as an image URL, or "" to draw the glyph.
    function iconUrl(icon) {
        if (!icon || icon === Group.GENERIC_ICON)
            return "";
        if (icon.startsWith("/"))
            return "file://" + icon;
        if (icon.includes("://"))
            return icon;
        return Quickshell.iconPath(icon, true);
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
        visible: root.groups.length > 0

        Column {
            id: stack
            width: parent.width
            spacing: 8

            Repeater {
                // Fixed slots, so a new message updates a card in place.
                model: Group.MAX_GROUPS

                Item {
                    id: slot

                    required property int index
                    readonly property var group: root.groups[index] ?? null
                    readonly property var latest: group ? group.latest.ref : null
                    readonly property bool critical: group?.critical ?? false
                    readonly property bool open: group ? root.expanded[group.app] === true : false
                    readonly property int peeks: group && !open ? group.stack.length : 0
                    readonly property real since: group ? root.shownSince(group.app) : 0
                    readonly property real remaining: group ? Math.max(0, Math.max(group.latest.time, since) + root.timeout - root.now) : 0
                    readonly property real enter: Math.max(0, Math.min(1, (root.now - since) / 280))
                    readonly property string appIconUrl: group ? root.iconUrl(group.icon) : ""
                    readonly property string avatar: latest ? (latest.image || appIconUrl) : ""
                    readonly property var buttons: latest ? latest.actions.filter(a => a.identifier !== "default" && a.text.length > 0) : []

                    visible: group !== null
                    width: stack.width
                    height: card.height + peeks * 6
                    opacity: Math.min(1, (root.now - since) / 200)

                    transform: Translate {
                        x: 380 * Math.pow(1 - slot.enter, 3)
                    }

                    // Older messages from the app, as card edges underneath.
                    Repeater {
                        model: slot.peeks

                        Rectangle {
                            required property int index
                            readonly property int depth: slot.peeks - index
                            z: -depth
                            x: 6 * depth
                            width: slot.width - 12 * depth
                            y: card.height - 20 + 6 * depth
                            height: 20
                            radius: Theme.radius - 2 + depth
                            color: Qt.alpha(Theme.surface, 0.86 - 0.08 * depth)
                            border.width: 1
                            border.color: Qt.alpha(Theme.primary, 0.3 - 0.05 * depth)
                        }
                    }

                    Rectangle {
                        id: card

                        width: parent.width
                        height: content.implicitHeight + 22 + (slot.critical ? 0 : 7)
                        radius: Theme.radius
                        color: Qt.alpha(Theme.surface, 0.93)
                        border.width: 1
                        border.color: slot.critical ? Theme.error : Qt.alpha(Theme.primary, 0.3)

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (slot.group) root.activate(slot.group)
                        }

                        Column {
                            id: content
                            x: 12
                            y: 10
                            width: parent.width - 24
                            spacing: 8

                            // Header: icon, name · count, age, chevron.
                            Item {
                                width: parent.width
                                height: 16

                                IconImage {
                                    id: appIcon
                                    // A path that fails to load falls back to the glyph.
                                    visible: slot.appIconUrl.length > 0 && status !== Image.Error
                                    source: slot.appIconUrl
                                    implicitSize: 16
                                }

                                Text {
                                    visible: !appIcon.visible
                                    width: 16
                                    height: 16
                                    text: Group.GENERIC_ICON
                                    color: slot.critical ? Theme.error : Theme.primary
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    x: 24
                                    width: age.x - x - 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: slot.group ? (slot.group.count > 1 ? `${slot.group.app} · ${slot.group.count}` : slot.group.app) : ""
                                    color: slot.critical ? Theme.error : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: age
                                    anchors.right: chevron.visible ? chevron.left : parent.right
                                    anchors.rightMargin: chevron.visible ? 10 : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: slot.group ? Group.age(root.now, slot.group.latest.time) : ""
                                    color: Theme.outline
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 2
                                }

                                Text {
                                    id: chevron
                                    visible: (slot.group?.count ?? 0) > 1
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: slot.open ? "󰅃" : "󰅀"
                                    color: chevronArea.containsMouse ? Theme.text : Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize + 1

                                    MouseArea {
                                        id: chevronArea
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggle(slot.group.app)
                                    }
                                }
                            }

                            // The latest message.
                            Row {
                                width: parent.width
                                spacing: 12

                                Item {
                                    width: 36
                                    height: 36

                                    ClippingRectangle {
                                        anchors.fill: parent
                                        radius: 18
                                        color: Theme.primaryContainer
                                        visible: (slot.latest?.image ?? "").length > 0

                                        Image {
                                            anchors.fill: parent
                                            source: slot.latest?.image ?? ""
                                            fillMode: Image.PreserveAspectCrop
                                            sourceSize: Qt.size(72, 72)
                                            asynchronous: true
                                        }
                                    }

                                    IconImage {
                                        id: avatarIcon
                                        anchors.fill: parent
                                        visible: !(slot.latest?.image) && slot.appIconUrl.length > 0 && status !== Image.Error
                                        source: slot.appIconUrl
                                        implicitSize: 36
                                    }

                                    // No picture at all: the sender's initial.
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 18
                                        visible: slot.avatar.length === 0 || (!(slot.latest?.image) && avatarIcon.status === Image.Error)
                                        color: slot.critical ? Qt.alpha(Theme.error, 0.15) : Theme.primaryContainer

                                        Text {
                                            anchors.centerIn: parent
                                            text: (slot.latest?.summary || "?").charAt(0).toUpperCase()
                                            color: slot.critical ? Theme.error : Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize + 1
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width - 48
                                    spacing: 3

                                    Text {
                                        width: parent.width
                                        text: slot.latest?.summary ?? ""
                                        color: Theme.text
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize
                                        font.bold: true
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        width: parent.width
                                        visible: text.length > 0
                                        text: slot.latest?.body ?? ""
                                        color: Theme.textMuted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSize - 1
                                        wrapMode: Text.Wrap
                                        maximumLineCount: slot.open ? 4 : 2
                                        elide: Text.ElideRight
                                        textFormat: Text.PlainText
                                    }
                                }
                            }

                            // Its real actions.
                            Row {
                                x: 48
                                visible: slot.buttons.length > 0
                                spacing: 6

                                Repeater {
                                    model: slot.buttons

                                    Rectangle {
                                        id: button
                                        required property var modelData
                                        required property int index
                                        width: label.implicitWidth + 28
                                        height: 28
                                        radius: 10
                                        color: index === 0 ? Theme.primaryContainer : Qt.alpha(Theme.text, buttonArea.containsMouse ? 0.13 : 0.07)
                                        border.width: index === 0 && buttonArea.containsMouse ? 1 : 0
                                        border.color: Qt.alpha(Theme.primary, 0.5)

                                        Text {
                                            id: label
                                            anchors.centerIn: parent
                                            text: button.modelData.text
                                            color: Theme.text
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontSize - 1
                                        }

                                        MouseArea {
                                            id: buttonArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            // Invoking dismisses only the latest message, so
                                            // clear the whole card as a click does, unless resident.
                                            onClicked: {
                                                const g = slot.group, resident = slot.latest?.resident ?? false;
                                                button.modelData.invoke();
                                                if (g && !resident)
                                                    for (const n of root.members(g.app))
                                                        n.dismiss();
                                            }
                                        }
                                    }
                                }
                            }

                            // Opened by the chevron: the older messages.
                            Repeater {
                                model: slot.open ? slot.group.stack : []

                                Text {
                                    required property var modelData
                                    x: 48
                                    width: content.width - 48
                                    text: modelData.ref.body ? `${modelData.ref.summary} · ${modelData.ref.body}` : modelData.ref.summary
                                    color: Theme.textMuted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSize - 1
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                            }

                            Text {
                                x: 48
                                visible: slot.open && slot.group.count > 1 + slot.group.stack.length
                                text: slot.group ? `+${slot.group.count - 1 - slot.group.stack.length} more` : ""
                                color: Theme.outline
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize - 2
                            }
                        }

                        // The timeout, as a 3 px line along the bottom.
                        Rectangle {
                            visible: !slot.critical
                            x: 12
                            y: parent.height - 10
                            width: parent.width - 24
                            height: 3
                            radius: 1.5
                            color: Qt.alpha(Theme.text, 0.12)

                            Rectangle {
                                width: parent.width * slot.remaining / root.timeout
                                height: parent.height
                                radius: 1.5
                                color: Theme.primary
                            }
                        }
                    }
                }
            }
        }
    }
}
