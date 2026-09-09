#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
fail=0
LUA=lua; command -v lua >/dev/null 2>&1 || LUA=lua5.4
LUAC=luac; command -v luac >/dev/null 2>&1 || LUAC=luac5.4

step() { printf '%-28s ' "$1"; }
pass() { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }

step "luac"
bad_files=""
while IFS= read -r f; do $LUAC -p "$f" 2>/dev/null || bad_files="$bad_files $f"; done < <(find . -name '*.lua' -not -path './.git/*')
[ -z "$bad_files" ] && pass "all files parse" || bad "$bad_files"

step "harness DEBUG"
out=$($LUA test/harness/run.lua . 1 2>&1 | tail -1); case "$out" in *" 0 failed"*) pass "$out";; *) bad "$out";; esac
step "harness release"
out=$($LUA test/harness/run.lua . 0 2>&1 | tail -1); case "$out" in *" 0 failed"*) pass "$out";; *) bad "$out";; esac

if [ "$fail" = "0" ]; then echo "== GATE: clean =="; else echo "== GATE: NOT CLEAN =="; fi
exit $fail
