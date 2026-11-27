#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT
mkdir -p "$workspace/addons"
cp -R "$root/addons/action5" "$workspace/addons/action5"
cp "$root/tests/fixtures/blank_project/project.godot" "$workspace/project.godot"
cp "$root/tests/fixtures/blank_project/smoke.gd" "$workspace/smoke.gd"
godot_bin="${GODOT:-godot}"
python_bin="${PYTHON:-python3}"
"$godot_bin" --headless --path "$workspace" --import >"$workspace/import.log" 2>&1
"$python_bin" "$root/tools/check_godot_log.py" "$workspace/import.log"
"$godot_bin" --headless --path "$workspace" --script res://smoke.gd >"$workspace/smoke.log" 2>&1
"$python_bin" "$root/tools/check_godot_log.py" "$workspace/smoke.log"
grep -q ACTION5_BLANK_ADDON_OK "$workspace/smoke.log"
echo ACTION5_BLANK_ADDON_OK
