# phone-commands: put the rice's buttons into KDE Connect's "Run command" list
# for every paired phone, so they show in the phone app and run here.
# Runs on each switch; after pairing a new phone, run it by hand.
# It replaces the list, so add buttons below rather than in the app.

dir=${KDECONNECT_CONFIG:-$HOME/.config/kdeconnect}
ids=$(sed -n 's/^\[\(.*\)\]$/\1/p' "$dir/trusted_devices" 2>/dev/null || true)
if [ -z "$ids" ]; then
  echo "phone-commands: no paired phone yet"
  exit 0
fi

sink=@DEFAULT_AUDIO_SINK@
changed=0
for id in $ids; do
  # Key order is the order the phone lists them in.
  json=$(jq -cn --arg id "$id" --arg sink "$sink" '{
    rice_lock:  {name: "Lock screen",     command: "rice-lock"},
    rice_play:  {name: "Play / pause",    command: "playerctl play-pause"},
    rice_next:  {name: "Next track",      command: "playerctl next"},
    rice_prev:  {name: "Previous track",  command: "playerctl previous"},
    rice_volup: {name: "Volume up",       command: "wpctl set-volume -l 1 \($sink) 10%+"},
    rice_voldn: {name: "Volume down",     command: "wpctl set-volume \($sink) 10%-"},
    rice_mute:  {name: "Mute",            command: "wpctl set-mute \($sink) toggle"},
    rice_wall:  {name: "Next wallpaper",  command: "rice-wall next"},
    rice_shot:  {name: "Screenshot to phone",
                 command: "f=${XDG_RUNTIME_DIR:-/tmp}/phone-shot.png; grim \"$f\" && kdeconnect-cli -d \($id) --share \"$f\""},
    rice_sleep: {name: "Sleep",           command: "systemctl suspend"},
    rice_off:   {name: "Shut down",       command: "systemctl poweroff"}
  }')
  # KConfig stores it as a byte array with quotes and backslashes escaped.
  escaped=$(printf '%s' "$json" | sed 's/\\/\\\\/g; s/"/\\"/g')
  conf="$dir/$id/kdeconnect_runcommand/config"
  want=$(printf '[General]\ncommands="@ByteArray(%s)"\n' "$escaped")
  if [ "$(cat "$conf" 2>/dev/null)" != "$want" ]; then
    mkdir -p "$(dirname "$conf")"
    printf '%s\n' "$want" > "$conf"
    changed=1
  fi
done

if [ "$changed" = 0 ]; then
  echo "phone-commands: already set"
  exit 0
fi
# The daemon reads the list at start: restart it if it runs. Any D-Bus call
# starts it again, with the session's environment.
if pkill -x kdeconnectd; then
  sleep 1
  kdeconnect-cli -l >/dev/null 2>&1 || true
fi
echo "phone-commands: buttons set for $(echo "$ids" | wc -w) phone(s)"
