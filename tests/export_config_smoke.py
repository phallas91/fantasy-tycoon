#!/usr/bin/env python3
"""Dependency-free Play Store export configuration smoke test."""

from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
PRESETS = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"EXPORT_SMOKE: FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def sections(text: str, prefix: str) -> list[str]:
    matches = list(re.finditer(r"(?m)^\[([^]]+)\]\s*$", text))
    result: list[str] = []
    for index, match in enumerate(matches):
        if match.group(1).startswith(prefix):
            end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
            result.append(text[match.end():end])
    return result


options = sections(PRESETS, "preset.")
option_blocks = [block for block in options if "gradle_build/export_format=" in block]
if len(option_blocks) != 2:
    fail("expected APK and AAB option blocks")

for block in option_blocks:
    required = {
        'gradle_build/target_sdk="36"': "target API 36",
        "architectures/arm64-v8a=true": "64-bit ARM",
        'package/unique_name="com.arcanetrade.empire"': "stable package id",
        "package/show_as_launcher_app=true": "launcher visibility",
        "permissions/internet=true": "network permission",
        "permissions/vibrate=true": "haptic permission",
        "version/code=70": "monotonic version code",
        'version/name="0.7.0"': "release version name",
    }
    for needle, label in required.items():
        if needle not in block:
            fail(f"missing {label}")

if "gradle_build/export_format=1" not in PRESETS:
    fail("Play Store AAB preset missing")
if 'config/version="0.7.0-rc1"' not in PROJECT:
    fail("project and export release versions are out of sync")
if 'config/features=PackedStringArray("4.7", "GL Compatibility")' not in PROJECT:
    fail("project is not pinned to Godot 4.7")

print("EXPORT_SMOKE: PASS")
