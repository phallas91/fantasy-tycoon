#!/usr/bin/env python3
"""Keep store privacy evidence aligned with the enabled service inventory."""

from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
POLICY = (ROOT / "docs/PRIVACY_POLICY_TEMPLATE.md").read_text(encoding="utf-8")
INVENTORY = (ROOT / "docs/PLAY_DATA_SAFETY_INVENTORY.md").read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"PRIVACY_SMOKE: FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


for phrase in (
    "Arcane Trade Empire",
    "Local game data",
    "Google Play Games cloud save",
    "Advertising and consent",
    "In-app purchases",
    "Local notifications",
    "Retention, security and deletion",
    "Children and target audience",
):
    if phrase not in POLICY:
        fail(f"privacy policy is missing: {phrase}")

for phrase in (
    "Game progress and settings",
    "Cloud game snapshot",
    "Purchase activity and token",
    "IP / approximate location",
    "App interactions",
    "Diagnostics",
    "Device/account identifiers",
    "Post notifications",
):
    if phrase not in INVENTORY:
        fail(f"Data Safety inventory is missing: {phrase}")

blockers = POLICY.count("[REQUIRED:")
print(f"PRIVACY_SMOKE: PASS ({blockers} owner decisions remain before release)")
