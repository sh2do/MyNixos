# rice-dpms: switch the monitors off or on in whichever session is running.
#
#   rice-dpms off|on
#
# Umbriel sets $UMBRIEL_SOCKET; anything else is taken to be niri. niri wakes
# the monitors on input by itself, so "on" does nothing there.

case "${1:-}" in
  off | on) ;;
  *)
    echo "usage: rice-dpms off|on" >&2
    exit 2
    ;;
esac

if [ -n "${UMBRIEL_SOCKET:-}" ]; then
  exec umbriel msg "dpms-$1"
elif [ "$1" = off ]; then
  exec niri msg action power-off-monitors
fi
