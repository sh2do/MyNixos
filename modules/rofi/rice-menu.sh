set -euo pipefail
# rice-menu: rofi menus for the desktop.
#
#   rice-menu apps | wifi | bluetooth | audio | profile | power | clipboard | wallpaper
#
# Every menu does nothing when cancelled (Escape).

state_dir=${RICE_STATE_DIR:-$HOME/.cache/rice}
wall_dir=${RICE_WALL_DIR:-$HOME/.local/share/wallpapers/rotation}
saved_dir=${RICE_SAVED_DIR:-$(dirname "$wall_dir")/saved}
theme=${RICE_ROFI_THEME:-$HOME/.config/rofi/theme.rasi}

# Used when rice-wall hasn't generated colours yet (first boot).
fallback_colours='* { primary: #dbbce5; on-primary: #3e2848; primary-container: #62496c; secondary: #d2c1d4; tertiary: #f6b6c1; surface: #151315; surface-container: #211f21; surface-high: #2c292c; on-surface: #e7e1e4; on-surface-variant: #cec3ce; outline: #978e97; error: #ffb4ab; }'

theme_args() {
  local args=(-theme "$theme")
  [ -f "$state_dir/colors.rasi" ] || args+=(-theme-str "$fallback_colours")
  printf '%s\0' "${args[@]}"
}

# pick PROMPT [rofi args...] < rows — prints the chosen row, or nothing if cancelled
pick() {
  local prompt=$1 targs=()
  shift
  mapfile -d '' targs < <(theme_args)
  rofi -dmenu -i -p "$prompt" "${targs[@]}" "$@" || true
}

apps() {
  local targs=()
  mapfile -d '' targs < <(theme_args)
  rofi -show drun "${targs[@]}"
}

power() {
  local choice
  choice=$(printf '%s\n' "Lock" "Suspend" "Log out" "Reboot" "Shut down" | pick "power")
  case $choice in
    Lock) rice-lock ;;
    Suspend) systemctl suspend ;;
    "Log out") niri msg action quit --skip-confirmation ;;
    Reboot) systemctl reboot ;;
    "Shut down") systemctl poweroff ;;
  esac
}

profile() {
  local now choice p
  now=$(powerprofilesctl get 2>/dev/null || true)
  choice=$(for p in power-saver balanced performance; do
    if [ "$p" = "$now" ]; then echo "● $p"; else echo "  $p"; fi
  done | pick "power profile")
  choice=${choice#??}
  [ -n "$choice" ] && powerprofilesctl set "$choice"
}

wifi() {
  local rows choice ssid security
  rows=$(nmcli -t -f SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null |
    awk -F: '$1 != "" && !seen[$1]++ { printf "%s  ·  %s%%%s\n", $1, $2, ($3 == "" ? "" : "  ·  󰌾") }' || true)
  choice=$(printf '%s\n%s\n' "󰖩  Toggle Wi-Fi" "$rows" | pick "wi-fi")
  [ -n "$choice" ] || return 0
  if [ "$choice" = "󰖩  Toggle Wi-Fi" ]; then
    if [ "$(nmcli radio wifi)" = enabled ]; then nmcli radio wifi off; else nmcli radio wifi on; fi
    return
  fi
  ssid=${choice%%  ·  *}
  if nmcli -g NAME connection show | grep -qxF "$ssid"; then
    nmcli connection up id "$ssid"
  elif [[ $choice == *󰌾* ]]; then
    security=$(pick "password for $ssid" -password < /dev/null)
    [ -n "$security" ] && nmcli dev wifi connect "$ssid" password "$security"
  else
    nmcli dev wifi connect "$ssid"
  fi
}

bluetooth() {
  local rows choice mac
  rows=$(bluetoothctl devices Paired 2>/dev/null | while read -r _ mac name; do
    if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
      echo "● $name  ·  $mac"
    else
      echo "  $name  ·  $mac"
    fi
  done || true)
  choice=$(printf '%s\n%s\n' "󰂯  Toggle Bluetooth" "$rows" | pick "bluetooth")
  [ -n "$choice" ] || return 0
  if [ "$choice" = "󰂯  Toggle Bluetooth" ]; then
    if bluetoothctl show | grep -q "Powered: yes"; then bluetoothctl power off; else bluetoothctl power on; fi
    return
  fi
  mac=${choice##*  ·  }
  if [[ $choice == ●* ]]; then bluetoothctl disconnect "$mac"; else bluetoothctl connect "$mac"; fi
}

audio() {
  local now choice
  now=$(pactl get-default-sink 2>/dev/null || true)
  choice=$(pactl -f json list sinks 2>/dev/null |
    jq -r --arg now "$now" '.[] | (if .name == $now then "● " else "  " end) + .description + "  ·  " + .name' |
    pick "audio output" || true)
  [ -n "$choice" ] && pactl set-default-sink "${choice##*  ·  }"
}

clipboard() {
  local choice
  choice=$(cliphist list | pick "clipboard")
  [ -n "$choice" ] && cliphist decode <<<"$choice" | wl-copy
}

wallpaper() {
  local choice
  choice=$({ find -L "$wall_dir" "$saved_dir" -maxdepth 1 -type f 2>/dev/null || true; } | sort |
    while IFS= read -r f; do printf '%s\0icon\x1f%s\n' "$f" "$f"; done |
    pick "wallpaper" -show-icons -theme-str 'listview { columns: 3; lines: 3; } element { orientation: vertical; } element-icon { size: 160px; } element-text { enabled: false; }')
  [ -n "$choice" ] && rice-wall set "$choice"
}

case ${1:-} in
  apps | wifi | bluetooth | audio | profile | power | clipboard | wallpaper) "$1" ;;
  *)
    echo "usage: rice-menu {apps|wifi|bluetooth|audio|profile|power|clipboard|wallpaper}" >&2
    exit 2
    ;;
esac
