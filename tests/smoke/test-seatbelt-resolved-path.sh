#!/usr/bin/env bash
# test-seatbelt-resolved-path.sh — kernel-level check of the premise behind the
# generate-lockdown-config resolved-symlink deny (commit 79937c4): that macOS
# Seatbelt enforces a file-read deny on the RESOLVED target of an open(). Uses
# `sandbox-exec` directly — no host API, no Claude Code. macOS-only.
#
# HONEST SCOPE: this proves the fix is SUFFICIENT at the kernel (denying the
# resolved target blocks a read through an out-pointing symlink). It does NOT
# reproduce the LEAK of a lexical-only deny — raw sandbox-exec blocks that too
# (reported as INFO). Whether Claude Code's own denyRead glob compilation leaks
# (making the fix strictly necessary) needs a real sandbox-enabled CC session.
#
# Gotcha baked in: mktemp returns /var/... but Seatbelt canonicalizes to
# /private/var/..., so deny subpaths MUST be canonicalized (pwd -P) or they
# silently never match. A direct-read sanity check guards against that.
set -uo pipefail
export LC_ALL=C

PASS=0; FAIL=0
pass(){ echo "  PASS: $1"; PASS=$((PASS+1)); }
fail(){ echo "  FAIL: $1"; FAIL=$((FAIL+1)); }
info(){ echo "  INFO: $1"; }

[ "$(uname)" = "Darwin" ] || { echo "SKIP: macOS / Seatbelt only"; exit 0; }
command -v sandbox-exec >/dev/null 2>&1 || { echo "SKIP: sandbox-exec not available"; exit 0; }

B="$(cd "$(mktemp -d)" && pwd -P)"; trap 'rm -rf "$B"' EXIT
mkdir -p "$B/proj/realdir" "$B/ext"
printf 'SECRET-12345\n' > "$B/ext/secret.txt"
printf 'x\n'            > "$B/proj/realdir/real.txt"
ln -s "$B/ext/secret.txt" "$B/proj/realdir/flink"   # file symlink pointing OUT of realdir

# returns 0 (BLOCKED) if reading $2 under a file-read deny of subpath $1 is denied
denies_read(){
  printf '(version 1)\n(allow default)\n(deny file-read* (subpath "%s"))\n' "$1" > "$B/prof.sb"
  if sandbox-exec -f "$B/prof.sb" /bin/cat "$2" >/dev/null 2>&1; then return 1; else return 0; fi
}

echo "=== Seatbelt resolved-path kernel test ==="

# sanity: deny realdir, read a REAL file directly in it -> must BLOCK
if denies_read "$B/proj/realdir" "$B/proj/realdir/real.txt"; then
  pass "sanity — sandbox-exec enforces file-read deny (canonical paths OK)"
else
  fail "sanity — sandbox not enforcing; remaining results INVALID"
  echo "  ---- $PASS passed, $FAIL failed ----"; exit 1
fi

# THE FIX'S BASIS: deny the RESOLVED target, read through the out-pointing symlink -> BLOCK
if denies_read "$B/ext" "$B/proj/realdir/flink"; then
  pass "resolved-target deny blocks the symlinked read (kernel matches the resolved path)"
else
  fail "resolved-target deny did NOT block — Seatbelt not matching the resolved path"
fi

# informational: does the lexical dir deny alone block the symlinked read?
if denies_read "$B/proj/realdir" "$B/proj/realdir/flink"; then
  info "lexical dir-deny ALSO blocks the symlinked read under raw sandbox-exec"
  info "  => leak premise not reproduced here; Claude Code denyRead compilation is separate (restart-gated)"
else
  info "lexical dir-deny LEAKS the symlinked read (resolved-path escape reproduced)"
fi

echo
echo "  ---- $PASS passed, $FAIL failed (INFO checks excluded) ----"
[ "$FAIL" -eq 0 ]
