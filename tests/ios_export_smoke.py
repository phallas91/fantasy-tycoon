#!/usr/bin/env python3
"""Static iOS readiness checks that can run without macOS or Xcode."""

from pathlib import Path
import struct


ROOT = Path(__file__).resolve().parents[1]
PRESETS = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
BILLING = (ROOT / "scripts" / "billing.gd").read_text(encoding="utf-8")
ADS = (ROOT / "scripts" / "ads.gd").read_text(encoding="utf-8")

required = (
    'name="iOS Xcode (Release Candidate)"',
    'platform="iOS"',
    'application/app_store_team_id="REQUIRED10"',
    'application/bundle_identifier="com.arcanetrade.empire"',
    'application/short_version="0.7.0"',
    'application/version="70"',
    'application/min_ios_version="15.0"',
    'architectures/arm64=true',
    'privacy/tracking_enabled=false',
)
for value in required:
    assert value in PRESETS, f"Missing iOS baseline: {value}"

icon = ROOT / "assets" / "platform" / "ios" / "app_icon_1024.png"
header = icon.read_bytes()[:26]
assert header[:8] == b"\x89PNG\r\n\x1a\n", "iOS icon is not PNG"
assert struct.unpack(">II", header[16:24]) == (1024, 1024), "iOS icon must be 1024x1024"
assert header[25] not in (4, 6), "iOS App Store icon must not contain an alpha channel"

assert "_purchase_simulator_allowed()" in BILLING
assert "_reward_simulator_allowed()" in ADS
for script in (BILLING, ADS):
    assert 'OS.get_name() in ["Windows", "macOS", "Linux"]' in script

docs = (ROOT / "docs" / "IOS_RELEASE_READINESS.md").read_text(encoding="utf-8")
for item in ("REQUIRED10", "StoreKit", "TestFlight", "macOS", "Xcode"):
    assert item in docs, f"iOS handoff documentation missing: {item}"

for locale in ("en-US", "de-DE"):
    metadata = ROOT / "fastlane" / "metadata" / "ios" / locale
    assert (metadata / "name.txt").read_text(encoding="utf-8").strip() == "Arcane Trade Empire"
    assert len((metadata / "subtitle.txt").read_text(encoding="utf-8").strip()) <= 30
    assert len((metadata / "keywords.txt").read_text(encoding="utf-8").strip()) <= 100
    assert (metadata / "description.txt").stat().st_size > 200
    for owner_field in ("privacy_url.txt", "support_url.txt"):
        assert "[REQUIRED:" in (metadata / owner_field).read_text(encoding="utf-8")

print("IOS_EXPORT_SMOKE: PASS (Team ID and native service plugins still required)")
