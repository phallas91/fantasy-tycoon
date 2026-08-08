#!/usr/bin/env bash
set -euo pipefail

# Local debug package only. Release AAB signing is intentionally configured in
# Godot/CI without embedding machine paths, usernames or passwords in Git.
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || {
  echo "Godot not found. Set GODOT to the Godot 4.7.1 console executable." >&2
  exit 1
}

mkdir -p export
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-debug "Android" "export/ArcaneTradeEmpire-debug.apk"
echo "Debug APK -> export/ArcaneTradeEmpire-debug.apk"
