# phone-alert: show a message on the paired phone through KDE Connect.
#   phone-alert "switch done"           e.g.  nh os switch; phone-alert "switch done"
#   phone-alert --critical "disk full"  the same, marked critical
# It goes to the first paired phone that is reachable, and fails (exit 1) when
# none is. The niri bar uses --critical to forward critical notifications.

usage() {
  echo 'usage: phone-alert [--critical] [--] "<message>"'
}

critical=0
while [ $# -gt 0 ]; do
  case $1 in
    --critical) critical=1; shift ;;
    -h | --help) usage; exit 0 ;;
    --) shift; break ;;
    -*) echo "phone-alert: unknown option $1" >&2; usage >&2; exit 2 ;;
    *) break ;;
  esac
done

msg="$*"
if [ -z "$msg" ]; then
  usage >&2
  exit 2
fi
[ "$critical" = 1 ] && msg="Critical: $msg"

if ! command -v kdeconnect-cli >/dev/null 2>&1; then
  echo "phone-alert: kdeconnect-cli not found (is programs.kdeconnect enabled?)" >&2
  exit 1
fi

# -a: paired and reachable. It prints "0 devices found" to stderr when there
# are none, and fails when the daemon isn't running.
id=$(kdeconnect-cli -a --id-only 2>/dev/null | head -n 1 || true)
if [ -z "$id" ]; then
  echo "phone-alert: no paired phone is reachable (same Wi-Fi? KDE Connect open on the phone?)" >&2
  exit 1
fi

if ! kdeconnect-cli -d "$id" --ping-msg "$msg"; then
  echo "phone-alert: could not reach the phone ($id)" >&2
  exit 1
fi
