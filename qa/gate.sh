#!/usr/bin/env bash
set -o pipefail
cd "$(dirname "$0")/.." || exit 1
LUA=lua; command -v lua >/dev/null 2>&1 || LUA=lua5.1
LUAC=luac; command -v luac >/dev/null 2>&1 || LUAC=luac5.1
fail=0

echo "== luac"
bad=""
while IFS= read -r f; do $LUAC -p "$f" >/dev/null 2>&1 || bad="$bad $f"; done < <(find . -name '*.lua' -not -path './.git/*')
if [ -n "$bad" ]; then echo "FAIL parse:$bad"; fail=1; else echo "ok   every file parses"; fi

for mode in 0 1; do
  echo "== harness DEBUG=$mode"
  out=$($LUA test/harness/run.lua . $mode 2>&1); rc=$?
  echo "$out" | grep -E "^FAIL|^      |^== "
  if [ $rc -ne 0 ]; then fail=1; fi
done

if [ "${1:-}" != "--quick" ]; then
  echo "== robot"
  python -m robot --outputdir qa/robot/output qa/robot/gate.robot 2>&1 | grep -E "\| (PASS|FAIL) \||tests,"
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then fail=1; fi
fi

if [ $fail -eq 0 ]; then echo "GATE: green"; else echo "GATE: RED"; fi
exit $fail
