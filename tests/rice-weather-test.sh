#!/usr/bin/env bash
# Tests for modules/weather/rice-weather.sh (run: bash tests/rice-weather-test.sh)
# `map` is the pure part: an Open-Meteo answer on stdin, the scene's weather
# on stdout. The fetch writes it to the state dir, and keeps the last file
# when it can't.
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
RICE_WEATHER=$PWD/modules/weather/rice-weather.sh
unset RICE_WEATHER_LAT RICE_WEATHER_LON

# answer CODE [PRECIP] [CLOUD] [WIND] [IS_DAY] — an Open-Meteo `current` block.
answer() {
  printf '{"current":{"time":"2026-11-09T09:45","interval":900,"weather_code":%s,"precipitation":%s,"rain":%s,"cloud_cover":%s,"wind_speed_10m":%s,"is_day":%s}}' \
    "$1" "${2:-0}" "${2:-0}" "${3:-0}" "${4:-0}" "${5:-1}"
}
mapped() { answer "$@" | RICE_WEATHER_NOW=1000 bash "$RICE_WEATHER" map; }
field() { jq -r "$1"; }

test_codes_map_to_kinds() {
  local code kind
  while read -r code kind; do
    assert_eq "$(mapped "$code" | field .kind)" "$kind" || { echo "    (code $code)"; return 1; }
  done <<'EOF'
0 clear
1 clear
2 cloudy
3 cloudy
45 fog
48 fog
51 drizzle
55 drizzle
57 drizzle
61 rain
65 rain
67 rain
80 rain
82 rain
71 snow
75 snow
77 snow
86 snow
95 storm
96 storm
99 storm
EOF
}

test_unknown_code_is_cloudy() {
  assert_eq "$(mapped 42 0 70 | field .kind)" "cloudy"
}

test_intensity_follows_the_code() {
  local light heavy
  light=$(mapped 61 | field .intensity)
  heavy=$(mapped 65 | field .intensity)
  jq -en "$light > 0 and $light < $heavy and $heavy <= 1" >/dev/null
  assert_eq "$(mapped 0 | field .intensity)" "0"
  assert_eq "$(mapped 99 | field .intensity)" "1"
}

test_heavy_precipitation_raises_intensity() {
  # 2 mm in a 15 min interval is 8 mm/h: a downpour, whatever the code says.
  assert_eq "$(mapped 61 2 | field .intensity)" "1"
  assert_eq "$(mapped 61 0 | field .intensity)" "$(mapped 61 0.01 | field .intensity)"
}

test_cloudy_intensity_is_the_cover() {
  assert_eq "$(mapped 3 0 80 | field .intensity)" "0.8"
}

test_wind_and_day_and_stamp() {
  local w
  w=$(mapped 95 0 100 25 0)
  assert_eq "$(field .wind <<<"$w")" "0.5"
  assert_eq "$(field .isDay <<<"$w")" "false"
  assert_eq "$(field .updated <<<"$w")" "1000"
  assert_eq "$(mapped 0 0 0 200 1 | field .wind)" "1"
  assert_eq "$(mapped 0 0 0 0 1 | field .isDay)" "true"
}

test_map_rejects_garbage() {
  local code=0
  echo '{"error":true,"reason":"nope"}' | bash "$RICE_WEATHER" map >/dev/null 2>&1 || code=$?
  assert_eq "$code" "1"
}

# curl stub: logs its args, prints $TMP/answer (or fails without one).
curl_stub() {
  cat > "$TMP/bin/curl" <<EOF
#!/usr/bin/env bash
echo "curl \$*" >> "$TMP/calls"
[ -f "$TMP/answer" ] || exit 6
cat "$TMP/answer"
EOF
  chmod +x "$TMP/bin/curl"
}

test_fetch_writes_the_state_file() {
  curl_stub
  answer 63 0.5 100 10 1 > "$TMP/answer"
  bash "$RICE_WEATHER"
  assert_eq "$(jq -r .kind "$RICE_STATE_DIR/weather.json")" "rain"
  assert_contains "$(cat "$TMP/calls")" "latitude=-1.29&longitude=36.82"
  assert_contains "$(cat "$TMP/calls")" "current=weather_code,precipitation,rain,cloud_cover,wind_speed_10m,is_day"
}

test_fetch_uses_the_location() {
  curl_stub
  answer 0 > "$TMP/answer"
  RICE_WEATHER_LAT=51.5 RICE_WEATHER_LON=-0.12 bash "$RICE_WEATHER"
  assert_contains "$(cat "$TMP/calls")" "latitude=51.5&longitude=-0.12"
}

test_offline_keeps_the_last_file() {
  curl_stub
  echo '{"kind":"storm","intensity":1}' > "$RICE_STATE_DIR/weather.json"
  local err code=0
  err=$(bash "$RICE_WEATHER" 2>&1) || code=$?
  assert_eq "$code" "0"
  assert_eq "$(jq -r .kind "$RICE_STATE_DIR/weather.json")" "storm"
  assert_contains "$err" "keeping the last weather"
}

test_bad_answer_keeps_the_last_file() {
  curl_stub
  echo '<html>gateway</html>' > "$TMP/answer"
  echo '{"kind":"fog","intensity":0.6}' > "$RICE_STATE_DIR/weather.json"
  bash "$RICE_WEATHER" 2>/dev/null
  assert_eq "$(jq -r .kind "$RICE_STATE_DIR/weather.json")" "fog"
  assert_eq "$(ls "$RICE_STATE_DIR")" "weather.json"
}

run_test test_codes_map_to_kinds
run_test test_unknown_code_is_cloudy
run_test test_intensity_follows_the_code
run_test test_heavy_precipitation_raises_intensity
run_test test_cloudy_intensity_is_the_cover
run_test test_wind_and_day_and_stamp
run_test test_map_rejects_garbage
run_test test_fetch_writes_the_state_file
run_test test_fetch_uses_the_location
run_test test_offline_keeps_the_last_file
run_test test_bad_answer_keeps_the_last_file
finish
