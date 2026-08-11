#!/usr/bin/env python3
"""Guard distinct audio feedback for every visible construction branch."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
audio = (ROOT / "scripts" / "audio.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")

for kind in ("speed", "cargo", "value", "routes"):
    for prefix in ("upgrade", "landmark"):
        token = f'_streams["{prefix}_{kind}"]'
        if token not in audio:
            raise SystemExit(f"CONSTRUCTION_AUDIO: FAIL: missing {token}")

required = (
    "func play_upgrade(kind: String, landmark := false) -> void:",
    'play(("landmark_" if landmark else "upgrade_") + kind)',
    "Audio.play_upgrade(key, landmark_built or milestone_crossed)",
)
missing = [token for token in required if token not in audio + main]
if missing:
    raise SystemExit("CONSTRUCTION_AUDIO: FAIL: missing wiring: " + ", ".join(missing))

upgrade_block = main.split("func _make_upgrade_row", 1)[1].split("func _make_talent_row", 1)[0]
if 'Audio.play("buy")' in upgrade_block or 'Audio.play("milestone")' in upgrade_block:
    raise SystemExit("CONSTRUCTION_AUDIO: FAIL: generic sound still masks construction identity")

print("CONSTRUCTION_AUDIO: PASS (4 investment signatures + 4 landmark variants)")
