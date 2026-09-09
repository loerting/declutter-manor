#!/usr/bin/env bash
# Proves a shipped build contains the game and nothing else. The repo may be as cluttered as it
# likes; the PCK may not. Run after any change to export_presets.cfg's exclude_filter.
#
#   dev/tests/check_export.sh [preset] [output]
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
PRESET="${1:-Linux}"
OUT="${2:-$ROOT/build/linux/DeclutterManor.x86_64}"
mkdir -p "$(dirname "$OUT")"

timeout 600 "$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$OUT" > /tmp/export_check.log 2>&1
if [ $? -ne 0 ]; then echo "FAIL: export failed"; tail -5 /tmp/export_check.log; exit 1; fi

PCK="${OUT%.*}.pck"
[ -f "$PCK" ] || PCK="$OUT"   # embedded-pck builds
PATHS="$(strings -n 8 "$PCK" | grep -oE 'res://[A-Za-z0-9_./-]+' | sort -u)"

FOUND="$(echo "$PATHS" | grep -E '^res://(dev|docs|tools|screenshots|\.claude)/|\.(md|sh|py)$' || true)"
if [ -n "$FOUND" ]; then
	echo "FAIL: dev content leaked into the export:"
	echo "$FOUND"
	exit 1
fi
echo "PASS: export is clean ($(echo "$PATHS" | wc -l) resource paths, $(du -h "$PCK" | cut -f1))"
