# rice-lock: lock the session with the Quickshell config "rice-lock".
#
# Starts the locker in the background and returns once the lock is secure
# (the locker touches $XDG_RUNTIME_DIR/rice-lock.secure), so swayidle -w can
# let the machine sleep only after the screen is really locked.
# A second call while locked is a no-op (qs -n) and returns at once.
#
#   RICE_LOCK_WAIT   seconds to wait for the lock before giving up (default 5)

marker="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/rice-lock.secure"
wait_s="${RICE_LOCK_WAIT:-5}"

setsid -f qs -c rice-lock -n >/dev/null 2>&1 < /dev/null

for _ in $(seq $((wait_s * 10))); do
  [ -e "$marker" ] && exit 0
  sleep 0.1
done

echo "rice-lock: the lock did not engage within ${wait_s}s" >&2
exit 1
