#!/usr/bin/env bash
# The only check with a real pass/fail exit code. Sandboxes XDG_DATA_HOME, because Godot resolves
# user:// under it and an unsandboxed run would read and write the developer's real save.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
LOG="$SANDBOX/run.log"

# timeout, because a script that fails to parse never reaches its own quit() and would hang here.
XDG_DATA_HOME="$SANDBOX" timeout 120 "$GODOT" --headless --path "$ROOT" res://dev/tests/RunTests.tscn > "$LOG" 2>&1
CODE=$?
cat "$LOG"

# A headless run exits 0 even when a script failed to compile, so the log is the real check.
if grep -qE "SCRIPT ERROR|Parse Error|Invalid (get|call|set)|nonexistent|null instance" "$LOG"; then
	echo "FAIL: engine errors in the log"
	CODE=1
fi
if [ "$CODE" -eq 0 ]; then echo "PASS"; else echo "FAIL (exit $CODE)"; fi
exit "$CODE"
