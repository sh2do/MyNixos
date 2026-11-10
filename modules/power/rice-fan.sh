set -euo pipefail
# rice-fan: the OMEN's fans, through the patched hp-wmi driver's hwmon.
#
#   rice-fan status   fan auto  cpu 2300 rpm  gpu 2100 rpm   (the default)
#   rice-fan max      both fans flat out (fan boost); stays until `auto` or a reboot
#   rice-fan auto     back to the firmware's curve
#   rice-fan toggle   auto -> max, anything else -> auto
#
# pwm1_enable: 0 = max, 1 = manual, 2 = auto. Writable by the wheel group
# (a udev rule in modules/power), so no sudo.

hwmon_root=${RICE_HWMON_ROOT:-/sys/class/hwmon}

dir=""
for d in "$hwmon_root"/*; do
  if [ "$(cat "$d/name" 2>/dev/null || true)" = hp ] && [ -e "$d/pwm1_enable" ]; then
    dir=$d
    break
  fi
done
if [ -z "$dir" ]; then
  echo "rice-fan: no hp-wmi fan control (is the hp_wmi module loaded?)" >&2
  exit 1
fi

mode() {
  case $(cat "$dir/pwm1_enable") in
    0) echo max ;;
    1) echo manual ;;
    2) echo auto ;;
    *) echo unknown ;;
  esac
}

rpm() { cat "$dir/$1" 2>/dev/null || echo "?"; }

set_mode() {
  if ! { printf '%s\n' "$1" > "$dir/pwm1_enable"; } 2>/dev/null; then
    echo "rice-fan: can't write $dir/pwm1_enable (in the wheel group? log in again after switching)" >&2
    exit 1
  fi
  echo "fan $2"
}

case ${1:-status} in
  status) echo "fan $(mode)  cpu $(rpm fan1_input) rpm  gpu $(rpm fan2_input) rpm" ;;
  max) set_mode 0 max ;;
  auto) set_mode 2 auto ;;
  # From manual (set by some other tool) it goes back to auto, not to max.
  toggle) if [ "$(mode)" = auto ]; then set_mode 0 max; else set_mode 2 auto; fi ;;
  *)
    echo "usage: rice-fan {status|max|auto|toggle}" >&2
    exit 2
    ;;
esac
