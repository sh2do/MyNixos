#!/usr/bin/env bash
# Tests for modules/backup/rice-backup.sh (run: bash tests/rice-backup-test.sh)
# restic, phone-alert and notify-send are stubs; nothing touches the real
# ~/.config/rice-backup or backs up the real $HOME.
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh
RICE_BACKUP=$PWD/modules/backup/rice-backup.sh

NOW=1762750000 # a fixed "now" (epoch seconds)
DAY=86400

# Point every path the script uses into the sandbox and stub its helpers.
# restic stub: logs "restic [arg]..." to $TMP/calls (plus the repository
# credentials it sees), copies any --exclude-file to $TMP/excludes, and exits
# $RICE_TEST_<SUBCOMMAND>_EXIT; `snapshots` prints $RICE_TEST_SNAPSHOTS.
sandbox() {
  export RICE_BACKUP_DIR="$TMP/cfg"
  export RICE_BACKUP_STATE_DIR="$TMP/st"
  export RICE_BACKUP_HOME="$TMP/home"
  export RICE_BACKUP_RESTORE_DIR="$TMP/home/restore"
  export RICE_BACKUP_NOW=$NOW
  mkdir -p "$RICE_BACKUP_HOME"
  stub phone-alert
  stub notify-send
  cat > "$TMP/bin/restic" <<EOF
#!/usr/bin/env bash
printf 'restic' >> "$TMP/calls"
printf ' [%s]' "\$@" >> "$TMP/calls"
echo >> "$TMP/calls"
[ -n "\${B2_ACCOUNT_ID:-}" ] && echo "env B2_ACCOUNT_ID=\$B2_ACCOUNT_ID" >> "$TMP/calls"
prev=
sub=
for a in "\$@"; do
  [ "\$prev" = --exclude-file ] && cat "\$a" > "$TMP/excludes"
  case \$a in
    init|backup|forget|snapshots|restore|cat) [ -z "\$sub" ] && sub=\$a ;;
  esac
  prev=\$a
done
case \$sub in
  init) exit "\${RICE_TEST_INIT_EXIT:-0}" ;;
  cat) exit "\${RICE_TEST_CAT_EXIT:-1}" ;;
  backup) exit "\${RICE_TEST_BACKUP_EXIT:-0}" ;;
  forget) exit "\${RICE_TEST_FORGET_EXIT:-0}" ;;
  snapshots) printf '%s\n' "\${RICE_TEST_SNAPSHOTS:-[]}"; exit "\${RICE_TEST_SNAPSHOTS_EXIT:-0}" ;;
  restore) exit "\${RICE_TEST_RESTORE_EXIT:-0}" ;;
esac
EOF
  chmod +x "$TMP/bin/restic"
}

# A configured setup with a local repository that is "mounted" (has config).
configure_local() {
  mkdir -p "$RICE_BACKUP_DIR" "$TMP/drive/restic"
  : > "$TMP/drive/restic/config"
  echo "$TMP/drive/restic" > "$RICE_BACKUP_DIR/repo"
  echo "secret" > "$RICE_BACKUP_DIR/password"
  chmod 600 "$RICE_BACKUP_DIR/password"
}

# Run as writeShellApplication does: errexit, nounset, pipefail.
backup() { bash -euo pipefail "$RICE_BACKUP" "$@"; }

# --- not configured ---

test_now_unconfigured_exits_zero_quietly() {
  sandbox
  local out
  out=$(backup now)
  assert_contains "$out" "rice-backup init"
  ! grep -q restic "$TMP/calls"
  ! grep -q -e phone-alert -e notify-send "$TMP/calls"
}

test_status_unconfigured() {
  sandbox
  local out
  out=$(backup status)
  assert_contains "$out" "not set up"
}

# --- init ---

test_init_saves_repo_and_makes_password() {
  sandbox
  backup init "$TMP/drive/restic" >/dev/null
  assert_eq "$(cat "$RICE_BACKUP_DIR/repo")" "$TMP/drive/restic"
  [ -s "$RICE_BACKUP_DIR/password" ]
  assert_eq "$(stat -c %a "$RICE_BACKUP_DIR/password")" 600
  [ "$(wc -c < "$RICE_BACKUP_DIR/password")" -ge 20 ]
  grep -qxF "restic [-r] [$TMP/drive/restic] [--password-file] [$RICE_BACKUP_DIR/password] [init]" "$TMP/calls"
}

test_init_keeps_existing_password() {
  sandbox
  mkdir -p "$RICE_BACKUP_DIR"
  echo "mine" > "$RICE_BACKUP_DIR/password"
  backup init "b2:bucket:laptop" >/dev/null
  assert_eq "$(cat "$RICE_BACKUP_DIR/password")" "mine"
  assert_eq "$(stat -c %a "$RICE_BACKUP_DIR/password")" 600
  assert_eq "$(cat "$RICE_BACKUP_DIR/repo")" "b2:bucket:laptop"
}

test_init_existing_repository_is_adopted() {
  sandbox
  local out
  out=$(RICE_TEST_CAT_EXIT=0 backup init "sftp:nas:/backups/laptop")
  assert_contains "$out" "already"
  ! grep -q '\[init\]' "$TMP/calls"
  assert_eq "$(cat "$RICE_BACKUP_DIR/repo")" "sftp:nas:/backups/laptop"
}

test_init_failure_leaves_unconfigured() {
  sandbox
  local rc=0
  RICE_TEST_INIT_EXIT=1 backup init "$TMP/drive/restic" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 1
  [ ! -e "$RICE_BACKUP_DIR/repo" ]
}

test_init_without_repo_is_usage_error() {
  sandbox
  local rc=0 err
  err=$(backup init 2>&1 >/dev/null) || rc=$?
  assert_eq "$rc" 2
  assert_contains "$err" "usage: rice-backup"
}

test_init_starts_the_overdue_clock() {
  sandbox
  backup init "$TMP/drive/restic" >/dev/null
  assert_eq "$(cat "$RICE_BACKUP_STATE_DIR/since")" "$NOW"
}

# --- now ---

test_now_backs_up_home_with_excludes_then_prunes() {
  sandbox
  configure_local
  backup now >/dev/null
  local line
  line=$(grep '\[backup\]' "$TMP/calls")
  assert_contains "$line" "[-r] [$TMP/drive/restic] [--password-file] [$RICE_BACKUP_DIR/password]"
  assert_contains "$line" "[$RICE_BACKUP_HOME]"
  assert_contains "$line" "[--one-file-system]"
  assert_contains "$line" "[--exclude-caches]"
  assert_contains "$line" "[--tag] [rice-backup]"
  local ex
  ex=$(cat "$TMP/excludes")
  for p in "$RICE_BACKUP_HOME/.cache" "$RICE_BACKUP_HOME/.local/share/Steam" \
    "$RICE_BACKUP_HOME/.local/share/Trash" node_modules .direnv \
    "$RICE_BACKUP_HOME/Downloads/*.iso" '*.qcow2' '*.vdi' '*.vmdk' \
    "$RICE_BACKUP_RESTORE_DIR"; do
    grep -qxF -- "$p" <<<"$ex" || { echo "    missing exclude: $p"; return 1; }
  done
  grep -qF "[forget] [--tag] [rice-backup] [--prune] [--keep-daily] [7] [--keep-weekly] [4] [--keep-monthly] [6]" "$TMP/calls"
  # backup before forget
  [ "$(grep -n '\[backup\]' "$TMP/calls" | cut -d: -f1)" -lt "$(grep -n '\[forget\]' "$TMP/calls" | cut -d: -f1)" ]
  assert_eq "$(cat "$RICE_BACKUP_STATE_DIR/last-success")" "$NOW"
  ! grep -q -e phone-alert -e notify-send "$TMP/calls"
}

test_now_excludes_nix_result_links_only() {
  sandbox
  configure_local
  mkdir -p "$RICE_BACKUP_HOME/proj" "$RICE_BACKUP_HOME/notes/result"
  ln -s /nix/store/aaaa-thing "$RICE_BACKUP_HOME/proj/result"
  ln -s /nix/store/bbbb-thing "$RICE_BACKUP_HOME/proj/result-man"
  ln -s /etc/hostname "$RICE_BACKUP_HOME/proj/result-other"
  backup now >/dev/null
  local ex
  ex=$(cat "$TMP/excludes")
  grep -qxF "$RICE_BACKUP_HOME/proj/result" <<<"$ex"
  grep -qxF "$RICE_BACKUP_HOME/proj/result-man" <<<"$ex"
  ! grep -qxF "$RICE_BACKUP_HOME/notes/result" <<<"$ex"
  ! grep -qxF "$RICE_BACKUP_HOME/proj/result-other" <<<"$ex"
}

test_now_excludes_a_repo_inside_home() {
  sandbox
  mkdir -p "$RICE_BACKUP_DIR" "$RICE_BACKUP_HOME/backups/restic"
  : > "$RICE_BACKUP_HOME/backups/restic/config"
  echo "$RICE_BACKUP_HOME/backups/restic" > "$RICE_BACKUP_DIR/repo"
  echo secret > "$RICE_BACKUP_DIR/password"
  backup now >/dev/null
  grep -qxF "$RICE_BACKUP_HOME/backups/restic" "$TMP/excludes"
}

test_now_skips_unmounted_drive() {
  sandbox
  configure_local
  mkdir -p "$RICE_BACKUP_STATE_DIR"
  echo $((NOW - DAY)) > "$RICE_BACKUP_STATE_DIR/last-success"
  rm -rf "$TMP/drive"
  local out rc=0
  out=$(backup now) || rc=$?
  assert_eq "$rc" 0
  assert_contains "$out" "not mounted"
  ! grep -q restic "$TMP/calls"
  assert_eq "$(cat "$RICE_BACKUP_STATE_DIR/last-success")" $((NOW - DAY))
  ! grep -q -e phone-alert -e notify-send "$TMP/calls"
}

test_overdue_alerts_once_a_day() {
  sandbox
  configure_local
  rm -rf "$TMP/drive"
  mkdir -p "$RICE_BACKUP_STATE_DIR"
  echo $((NOW - 9 * DAY)) > "$RICE_BACKUP_STATE_DIR/last-success"
  backup now >/dev/null
  assert_eq "$(grep -c '^phone-alert' "$TMP/calls")" 1
  assert_eq "$(grep -c '^notify-send' "$TMP/calls")" 1
  assert_contains "$(cat "$TMP/calls")" "9 days"
  # Again the same day: nothing new.
  RICE_BACKUP_NOW=$((NOW + 3600)) backup now >/dev/null
  assert_eq "$(grep -c '^phone-alert' "$TMP/calls")" 1
  assert_eq "$(grep -c '^notify-send' "$TMP/calls")" 1
  # A day later: one more of each.
  RICE_BACKUP_NOW=$((NOW + DAY)) backup now >/dev/null
  assert_eq "$(grep -c '^phone-alert' "$TMP/calls")" 2
  assert_eq "$(grep -c '^notify-send' "$TMP/calls")" 2
}

test_overdue_counts_from_init_when_never_backed_up() {
  sandbox
  configure_local
  rm -rf "$TMP/drive"
  mkdir -p "$RICE_BACKUP_STATE_DIR"
  echo $((NOW - 8 * DAY)) > "$RICE_BACKUP_STATE_DIR/since"
  backup now >/dev/null
  assert_eq "$(grep -c '^phone-alert' "$TMP/calls")" 1
  assert_contains "$(grep '^phone-alert' "$TMP/calls")" "8 days"
}

test_not_overdue_within_a_week() {
  sandbox
  configure_local
  rm -rf "$TMP/drive"
  mkdir -p "$RICE_BACKUP_STATE_DIR"
  echo $((NOW - 6 * DAY)) > "$RICE_BACKUP_STATE_DIR/last-success"
  backup now >/dev/null
  ! grep -q -e phone-alert -e notify-send "$TMP/calls"
}

test_unreachable_phone_does_not_break_skip() {
  sandbox
  configure_local
  rm -rf "$TMP/drive"
  stub phone-alert 1
  stub notify-send 1
  mkdir -p "$RICE_BACKUP_STATE_DIR"
  echo $((NOW - 9 * DAY)) > "$RICE_BACKUP_STATE_DIR/last-success"
  local rc=0
  backup now >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 0
}

test_backup_failure_alerts_phone() {
  sandbox
  configure_local
  mkdir -p "$RICE_BACKUP_STATE_DIR"
  echo $((NOW - DAY)) > "$RICE_BACKUP_STATE_DIR/last-success"
  local rc=0
  RICE_TEST_BACKUP_EXIT=1 backup now >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 1
  assert_contains "$(grep '^phone-alert' "$TMP/calls")" "failed"
  assert_eq "$(cat "$RICE_BACKUP_STATE_DIR/last-success")" $((NOW - DAY))
  ! grep -q '\[forget\]' "$TMP/calls"
}

test_unreadable_files_still_count_as_success() {
  sandbox
  configure_local
  local rc=0
  RICE_TEST_BACKUP_EXIT=3 backup now >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 0
  assert_eq "$(cat "$RICE_BACKUP_STATE_DIR/last-success")" "$NOW"
  grep -q '\[forget\]' "$TMP/calls"
}

test_prune_failure_alerts_but_keeps_success() {
  sandbox
  configure_local
  local rc=0
  RICE_TEST_FORGET_EXIT=1 backup now >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 1
  assert_eq "$(cat "$RICE_BACKUP_STATE_DIR/last-success")" "$NOW"
  assert_contains "$(grep '^phone-alert' "$TMP/calls")" "prun"
}

test_cloud_repo_is_not_checked_for_a_mount() {
  sandbox
  mkdir -p "$RICE_BACKUP_DIR"
  echo "b2:bucket:laptop" > "$RICE_BACKUP_DIR/repo"
  echo secret > "$RICE_BACKUP_DIR/password"
  backup now >/dev/null
  grep -q '\[backup\]' "$TMP/calls"
}

test_env_file_reaches_restic() {
  sandbox
  mkdir -p "$RICE_BACKUP_DIR"
  echo "b2:bucket:laptop" > "$RICE_BACKUP_DIR/repo"
  echo secret > "$RICE_BACKUP_DIR/password"
  printf 'B2_ACCOUNT_ID=key123\nB2_ACCOUNT_KEY=shh\n' > "$RICE_BACKUP_DIR/env"
  backup now >/dev/null
  grep -qxF "env B2_ACCOUNT_ID=key123" "$TMP/calls"
}

test_second_run_while_one_runs_skips() {
  sandbox
  configure_local
  mkdir -p "$RICE_BACKUP_STATE_DIR"
  local out rc=0
  out=$(flock "$RICE_BACKUP_STATE_DIR/lock" bash -euo pipefail "$RICE_BACKUP" now) || rc=$?
  assert_eq "$rc" 0
  assert_contains "$out" "already running"
  ! grep -q '\[backup\]' "$TMP/calls"
}

# --- status ---

test_status_shows_last_snapshot_and_age() {
  sandbox
  configure_local
  local t out
  t=$(date -u -d @$((NOW - 2 * DAY)) +%Y-%m-%dT%H:%M:%S.123456789Z)
  out=$(RICE_TEST_SNAPSHOTS="[{\"short_id\":\"ab12cd34\",\"time\":\"$t\"}]" backup status)
  assert_contains "$out" "$TMP/drive/restic"
  assert_contains "$out" "ab12cd34"
  assert_contains "$out" "2 days ago"
  grep -qF '[snapshots] [--latest] [1] [--json]' "$TMP/calls"
}

test_status_unmounted_shows_last_success() {
  sandbox
  configure_local
  rm -rf "$TMP/drive"
  mkdir -p "$RICE_BACKUP_STATE_DIR"
  echo $((NOW - 3 * DAY)) > "$RICE_BACKUP_STATE_DIR/last-success"
  local out
  out=$(backup status)
  assert_contains "$out" "not mounted"
  assert_contains "$out" "3 days ago"
  ! grep -q restic "$TMP/calls"
}

# --- restore ---

test_restore_goes_to_dated_folder() {
  sandbox
  configure_local
  local out day
  day=$(date -d @$NOW +%F)
  out=$(backup restore "$RICE_BACKUP_HOME/Documents/cv.odt")
  grep -qxF "restic [-r] [$TMP/drive/restic] [--password-file] [$RICE_BACKUP_DIR/password] [restore] [latest] [--target] [$RICE_BACKUP_RESTORE_DIR/$day] [--include] [$RICE_BACKUP_HOME/Documents/cv.odt]" "$TMP/calls"
  assert_contains "$out" "$RICE_BACKUP_RESTORE_DIR/$day"
}

test_restore_relative_path_and_snapshot() {
  sandbox
  configure_local
  mkdir -p "$RICE_BACKUP_HOME/Music"
  (cd "$RICE_BACKUP_HOME/Music" && bash -euo pipefail "$RICE_BACKUP" restore ./mix.flac ab12cd34 >/dev/null)
  grep -qF "[restore] [ab12cd34] [--target]" "$TMP/calls"
  grep -qF "[--include] [$RICE_BACKUP_HOME/Music/mix.flac]" "$TMP/calls"
}

test_restore_without_path_is_usage_error() {
  sandbox
  configure_local
  local rc=0
  backup restore >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 2
  ! grep -q restic "$TMP/calls"
}

test_restore_failure_propagates() {
  sandbox
  configure_local
  local rc=0
  RICE_TEST_RESTORE_EXIT=1 backup restore "$RICE_BACKUP_HOME/x" >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 1
}

# --- usage ---

test_unknown_command_is_usage_error() {
  sandbox
  local rc=0
  backup frobnicate >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" 2
}

test_help() {
  sandbox
  local out
  out=$(backup --help)
  assert_contains "$out" "usage: rice-backup"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  run_test "$t"
done
finish
