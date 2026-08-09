#!/usr/bin/env python3
"""Static guard for the Android hardware release gate documentation."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOC = (ROOT / "docs" / "ANDROID_DEVICE_RELEASE_CHECKLIST.md").read_text(encoding="utf-8")
PROJECT = (ROOT / "project.godot").read_text(encoding="utf-8")
PRESETS = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")

required_sections = (
    "## Required device matrix",
    "## Installation and first launch",
    "## Core gameplay smoke",
    "## Save, kill and restore",
    "## Background and offline progression",
    "## Billing",
    "## Rewarded ads",
    "## Notifications",
    "## Connectivity and recovery",
    "## Performance and stability",
    "## Visual and localization pass",
    "## Release evidence",
)
for section in required_sections:
    assert section in DOC, f"Android device gate missing section: {section}"

required_release_risks = (
    "force-stop",
    "offline",
    "duplicate",
    "Cancelled purchase",
    "Rewarded ad failure",
    "airplane mode",
    "crash or ANR",
    "German and English",
    "Commit SHA",
    "release blocker",
)
for risk in required_release_risks:
    assert risk.lower() in DOC.lower(), f"Android device gate missing risk coverage: {risk}"

assert 'config/version="0.7.0-rc1"' in PROJECT, "device gate must track the current release candidate"
assert 'package/unique_name="com.arcanetrade.empire"' in PRESETS, "unexpected Android package id"
assert "architectures/arm64-v8a=true" in PRESETS, "ARM64 must remain enabled"
assert "architectures/armeabi-v7a=false" in PRESETS, "32-bit ARM must remain disabled"

print("ANDROID_DEVICE_GATE_SMOKE: PASS")
