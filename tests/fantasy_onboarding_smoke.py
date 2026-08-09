#!/usr/bin/env python3
"""Guard the fantasy map and calm progressive first-session experience."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
economy = (ROOT / "scripts" / "economy.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")
map_view = (ROOT / "scripts" / "map_view.gd").read_text(encoding="utf-8")
project = (ROOT / "project.godot").read_text(encoding="utf-8")

required_economy = (
    'WORLD[i]["outline"] = _fantasy_outline(i)',
    'cities[city_idx]["x"] =',
    'cities[city_idx]["y"] =',
    '"Die Goldenen Marken"',
    '"Der Aetherthron"',
)
required_main = (
    "func _progression_stage() -> int:",
    "func _nav_unlocked(tab_index: int) -> bool:",
    "_nav_btns[i].visible = _nav_unlocked(i)",
    "if not _nav_unlocked(i):",
    "lbl.text = tr(label_text)",
    'tr("%s desbloqueada!") % tr(str(def.get("name", id)))',
	"DisplayServer.SCREEN_LANDSCAPE",
	"const SIDE_PANEL_W := 410.0",
)
required_map = (
	'load("res://assets/fantasy/arcane_city_world_v1.webp")',
	"func _draw_realm_details(",
    "# A luminous river crosses the realm",
    "# Mountain chain:",
    "# Forest groves",
    "# Roads connect every settlement",
)

missing = [token for token in required_economy if token not in economy]
missing += [token for token in required_main if token not in main]
missing += [token for token in required_map if token not in map_view]
missing += [token for token in (
	"window/size/viewport_width=1280",
	"window/size/viewport_height=720",
	"window/handheld/orientation=0",
) if token not in project]
if missing:
    raise SystemExit("FANTASY_ONBOARDING: FAIL: missing guards: " + ", ".join(missing))

if not (ROOT / "assets" / "fantasy" / "arcane_city_world_v1.webp").is_file():
    raise SystemExit("FANTASY_ONBOARDING: FAIL: illustrated city world is missing")

# The first-launch tutorial must introduce one action, not advertise every
# system before the player has earned access to it.
slides = main.split("var slides: Array = [", 1)[1].split("\n\t]", 1)[0]
if slides.count('["ic_') != 1:
    raise SystemExit("FANTASY_ONBOARDING: FAIL: first launch must teach one action")

print("FANTASY_ONBOARDING: PASS (fantasy geometry + staged navigation)")
