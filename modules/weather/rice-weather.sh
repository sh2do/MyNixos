# rice-weather: the real weather, for both shells' scenes (weather.js).
#   rice-weather       fetch the current weather from Open-Meteo (no key) and
#                      write $RICE_STATE_DIR/weather.json; run every 20 min by
#                      a user timer. Offline, the last file stays.
#   rice-weather map   an Open-Meteo answer on stdin -> the file's JSON on
#                      stdout (pure; tests/rice-weather-test.sh)
# The file: {kind: clear|cloudy|fog|drizzle|rain|storm|snow, intensity: 0..1,
# wind: 0..1, isDay, updated: epoch seconds}.
# Where: RICE_WEATHER_LAT / RICE_WEATHER_LON, Nairobi by default.
set -euo pipefail

state_dir=${RICE_STATE_DIR:-$HOME/.cache/rice}
lat=${RICE_WEATHER_LAT:--1.29}
lon=${RICE_WEATHER_LON:-36.82}

# WMO weather codes (open-meteo.com/en/docs) to a kind and how strong it is.
# Precipitation is mm over the 15 min interval: 2 mm (8 mm/h) is a downpour,
# whatever the code says. Wind: 50 km/h is a full gale for the scene.
map() {
  jq -ce --argjson now "${RICE_WEATHER_NOW:-$(date +%s)}" '
    .current as $c
    | ($c.weather_code | numbers) as $code
    | {
        "0": ["clear", 0], "1": ["clear", 0],
        "45": ["fog", 0.5], "48": ["fog", 0.7],
        "51": ["drizzle", 0.25], "53": ["drizzle", 0.45], "55": ["drizzle", 0.7],
        "56": ["drizzle", 0.4], "57": ["drizzle", 0.7],
        "61": ["rain", 0.35], "63": ["rain", 0.6], "65": ["rain", 0.9],
        "66": ["rain", 0.4], "67": ["rain", 0.8],
        "80": ["rain", 0.4], "81": ["rain", 0.65], "82": ["rain", 1],
        "71": ["snow", 0.3], "73": ["snow", 0.6], "75": ["snow", 0.9],
        "77": ["snow", 0.2], "85": ["snow", 0.5], "86": ["snow", 0.9],
        "95": ["storm", 0.75], "96": ["storm", 0.9], "99": ["storm", 1]
      }[$code | tostring] as $known
    | ($known // ["cloudy", (($c.cloud_cover // 0) / 100)]) as [$kind, $base]
    | (if ["drizzle", "rain", "snow", "storm"] | index($kind)
       then [$base, (($c.precipitation // 0) * 4 / 8)] | max
       else $base end) as $i
    | {
        kind: $kind,
        intensity: ([[$i, 0] | max, 1] | min),
        wind: ([[(($c.wind_speed_10m // 0) / 50), 0] | max, 1] | min),
        isDay: ($c.is_day == 1),
        updated: $now
      }' || { echo "rice-weather: not a weather answer" >&2; return 1; }
}

fetch() {
  local url="https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=weather_code,precipitation,rain,cloud_cover,wind_speed_10m,is_day"
  local answer weather
  if ! answer=$(curl -fsS --max-time 20 "$url"); then
    echo "rice-weather: offline, keeping the last weather" >&2
    return 0
  fi
  if ! weather=$(map <<<"$answer" 2>/dev/null); then
    echo "rice-weather: odd answer from Open-Meteo, keeping the last weather" >&2
    return 0
  fi
  mkdir -p "$state_dir"
  # Atomic, so a shell never reads half a file.
  local tmp
  tmp=$(mktemp "$state_dir/.weather.XXXXXX")
  printf '%s\n' "$weather" > "$tmp"
  mv -f "$tmp" "$state_dir/weather.json"
}

case "${1:-fetch}" in
  map) map ;;
  fetch) fetch ;;
  *) echo "usage: rice-weather [fetch|map]" >&2; exit 2 ;;
esac
