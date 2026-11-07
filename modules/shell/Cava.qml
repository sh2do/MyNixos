pragma Singleton

// One cava for every monitor's media pill, so the pills don't all write the
// same config file and run their own copy. A pill acquires it while it shows
// the visualiser and releases it after; the bar levels are shared.
import QtQuick
import Quickshell
import Quickshell.Io
import "media.js" as Media

Singleton {
    id: cava

    readonly property int bars: 5
    // Pills that want it running right now.
    property int users: 0
    // False once cava has failed for this track; the pills then pulse instead.
    property bool ok: true
    property var levels: Media.parseCava("", bars)
    readonly property bool want: users > 0 && ok

    // We stopped it ourselves: its exit isn't a failure, even when a new user
    // arrived before the exit signal did.
    property bool stopAsked: false
    property double startedAt: 0

    function acquire() {
        users++;
    }
    function release() {
        users = Math.max(0, users - 1);
    }
    // A new track gets a fresh chance.
    function reset() {
        ok = true;
    }

    onWantChanged: sync()
    onUsersChanged: if (users === 0) levels = Media.parseCava("", bars)

    function sync() {
        if (want && !proc.running)
            proc.running = true;
        else if (!want && proc.running) {
            stopAsked = true;
            proc.running = false;
        }
    }

    function setLevels(v) {
        if (v.some((x, i) => Math.abs(x - levels[i]) > 0.01))
            levels = v;
    }

    Process {
        id: proc
        command: ["sh", "-c", [
            'f="${XDG_RUNTIME_DIR:-/tmp}/rice-pill-cava.conf"',
            'printf "%s\\n" "[general]" "framerate = 10" "bars = ' + cava.bars + '" ' +
                '"[output]" "method = raw" "raw_target = /dev/stdout" "data_format = ascii" ' +
                '"ascii_max_range = ' + Media.CAVA_MAX + '" "bar_delimiter = 59" "frame_delimiter = 10" "channels = mono" > "$f"',
            'exec cava -p "$f"'
        ].join("\n")]
        stdout: SplitParser {
            onRead: data => cava.setLevels(Media.parseCava(data, cava.bars))
        }
        onRunningChanged: if (running) {
            cava.startedAt = Date.now();
            cava.stopAsked = false;
        }
        onExited: (code, status) => {
            if (Media.cavaFailed(cava.want, cava.stopAsked, code, Date.now() - cava.startedAt))
                cava.ok = false;
            // Wanted again before the old exit arrived: start it afresh.
            cava.sync();
        }
    }
}
