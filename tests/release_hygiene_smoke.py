#!/usr/bin/env python3
"""Reject stale identity and credential material from release-critical files."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
FILES = [
    ROOT / "tools/make_keystore.sh",
    ROOT / "tools/build_apk.sh",
    ROOT / "docs/PLAY_STORE_SUBMISSION.md",
    ROOT / "export_presets.cfg",
    ROOT / ".github/workflows/godot-check.yml",
]
FORBIDDEN = (
    "drone123",
    "LuisPCFialho",
    "CN=Drone Tycoon",
    "Godot_v4.6",
    "build-tools/35",
    "com.lpcf.dronetycoon",
    "actions/checkout@v4",
    "actions/setup-java@v4",
    "actions/upload-artifact@v4",
)

REQUIRED_ACTIONS = (
    "actions/checkout@v5",
    "actions/setup-java@v5",
    "actions/upload-artifact@v6",
)

for path in FILES:
    text = path.read_text(encoding="utf-8")
    for secret_or_stale_value in FORBIDDEN:
        if secret_or_stale_value in text:
            print(
                f"RELEASE_HYGIENE: FAIL: {secret_or_stale_value!r} in {path.relative_to(ROOT)}",
                file=sys.stderr,
            )
            raise SystemExit(1)

workflow = (ROOT / ".github/workflows/godot-check.yml").read_text(encoding="utf-8")
for action in REQUIRED_ACTIONS:
    if action not in workflow:
        print(f"RELEASE_HYGIENE: FAIL: missing current action {action}", file=sys.stderr)
        raise SystemExit(1)

ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
for pattern in ("*.keystore", "*.jks", "keystore/", "secrets/"):
    if pattern not in ignore:
        print(f"RELEASE_HYGIENE: FAIL: missing ignore pattern {pattern}", file=sys.stderr)
        raise SystemExit(1)

print("RELEASE_HYGIENE: PASS")
