#!/usr/bin/env bash
# The two ravens (the niri bar's and Umbriel's) share RavenBody.qml: every
# property either one sets on its RavenBody, or reads through the body's id,
# must be declared on RavenBody's root item (or be an Item built-in). A rename
# there would otherwise only show as a QML error at runtime.
# (run: bash tests/raven-interface-test.sh)
cd "$(dirname "$0")/.." || exit 1
source tests/lib.sh

BODY=${RAVEN_BODY:-modules/umbriel/shell/RavenBody.qml}
USERS=(modules/shell/Raven.qml modules/umbriel/shell/Raven.qml)
# Properties every Item has, which RavenBody needn't declare.
BUILTINS=" id x y z width height visible opacity scale rotation transform parent anchors clip enabled "

# Strip // comments, so a word in a comment isn't taken for code.
code() { sed 's|//.*$||' "$1"; }

# The names declared with `property` on the root item (depth 1) of $1.
declared() {
  code "$1" | awk '
    depth == 1 && match($0, /^[ \t]*(required |readonly |default )*property[ \t]+[^ \t]+[ \t]+[A-Za-z_][A-Za-z0-9_]*/) {
      n = split(substr($0, RSTART, RLENGTH), w, /[ \t]+/); print w[n]
    }
    { o = gsub(/\{/, "{"); c = gsub(/\}/, "}"); depth += o - c }'
}

# The names $1 assigns directly inside its RavenBody { ... } block, and the
# bare names its bindings there read (the body's own, like footX in
# `x: root.homeX - footX`), then `id=<the block id>` on a line of its own.
assigned() {
  code "$1" | awk '
    !inb && /^[ \t]*RavenBody[ \t]*\{/ { inb = 1; depth = 0 }
    inb {
      if (depth == 1 && match($0, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*[ \t]*:/)) {
        name = substr($0, RSTART, RLENGTH); gsub(/[ \t:]/, "", name); print name
        if (name == "id") { v = $0; sub(/^[^:]*:[ \t]*/, "", v); gsub(/[ \t;]/, "", v); print "id=" v }
        else {
          # Words in the binding not after a dot, nor followed by a dot or a
          # call: names on the body itself.
          rhs = substr($0, RSTART + RLENGTH)
          gsub(/"[^"]*"/, "", rhs)
          gsub(/[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)+/, "", rhs)
          gsub(/[A-Za-z_][A-Za-z0-9_]*[ \t]*[({]/, "", rhs)
          while (match(rhs, /[A-Za-z_][A-Za-z0-9_]*/)) {
            w = substr(rhs, RSTART, RLENGTH); rhs = substr(rhs, RSTART + RLENGTH)
            if (w !~ /^(true|false|null|undefined)$/) print w
          }
        }
      }
      o = gsub(/\{/, "{"); c = gsub(/\}/, "}"); depth += o - c
      if (depth == 0 && (o || c)) inb = 0
    }'
}

# Every name $1 uses on RavenBody: assigned in the block, or read as <id>.name.
used() {
  local a id
  a=$(assigned "$1")
  id=$(grep '^id=' <<<"$a" | head -1 | cut -d= -f2)
  grep -v '^id=' <<<"$a"
  [ -n "$id" ] && code "$1" | grep -oE "\\b$id\\.[A-Za-z_][A-Za-z0-9_]*" | cut -d. -f2
}

check_user() {
  local user=$1 decl missing="" n
  decl=" $(declared "$BODY" | tr '\n' ' ') "
  [ "$(used "$user" | wc -l)" -gt 10 ] || { echo "    found too few uses in $user"; return 1; }
  for n in $(used "$user" | sort -u); do
    [[ "$decl" == *" $n "* || "$BUILTINS" == *" $n "* ]] || missing+=" $n"
  done
  [ -z "$missing" ] || { echo "    $user uses, but $BODY doesn't declare:$missing"; return 1; }
}

test_body_declares_its_pose() {
  local decl
  decl=" $(declared "$BODY" | tr '\n' ' ') "
  for n in k footX perchY preen caw beakSlot bodyColor; do
    [[ "$decl" == *" $n "* ]] || { echo "    $BODY: no $n"; return 1; }
  done
}
test_niri_raven_uses_only_declared_properties() { check_user "${USERS[0]}"; }
test_umbriel_raven_uses_only_declared_properties() { check_user "${USERS[1]}"; }

for t in test_body_declares_its_pose test_niri_raven_uses_only_declared_properties \
  test_umbriel_raven_uses_only_declared_properties; do
  run_test "$t"
done
finish
