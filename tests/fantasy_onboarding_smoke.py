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
	"const DISTRICT_STAGES := {",
	"func next_district_stage(key: String, level: int) -> Dictionary:",
)
required_main = (
    "func _progression_stage() -> int:",
    "func _nav_unlocked(tab_index: int) -> bool:",
    "_nav_btns[i].visible = dashboard_ready and _nav_unlocked(i)",
    "if not _nav_unlocked(i):",
    "lbl.text = tr(label_text)",
    'tr("%s desbloqueada!") % tr(str(def.get("name", id)))',
	"DisplayServer.SCREEN_LANDSCAPE",
	"const SIDE_PANEL_W := 410.0",
	"func _build_guided_action() -> void:",
	"var dashboard_ready := stage > 0",
	"_focus_card.visible = not dashboard_ready",
	"func _on_prosperity_advanced(",
	"func _show_income_gain(before_income: float, source: Control) -> void:",
	"GameState.auto_bought.connect(_on_auto_bought)",
	"func _show_expansion_confirm() -> void:",
	'"progress_override": true',
	'"upgrade_key": recommended_key',
	"(_mode_btns[mode] as Button).visible = GameState.prosperity_rank >= required_rank",
	"var auto_manager_unlocked := GameState.prosperity_rank >= 2",
	"_auto_mgr_section.visible = auto_manager_unlocked",
)
required_map = (
	'load("res://assets/fantasy/arcane_city_world_v1.webp")',
	"func _draw_realm_details(",
	"func _draw_ground_traffic(",
	"func _draw_district_investments(",
	'GameState.levels.get("cargo", 0)',
	'GameState.levels.get("value", 0)',
	'GameState.levels.get("speed", 0)',
	'GameState.levels.get("routes", 0)',
	"if cargo_level >= 25:",
	"if value_level >= 25:",
	"if speed_level >= 25:",
	"if route_level >= 25:",
	"func _draw_recommended_investment(",
	"func set_recommended_investment(",
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
game_state = (ROOT / "scripts" / "game_state.gd").read_text(encoding="utf-8")
missing += [token for token in (
	"const PROSPERITY_THRESHOLDS := [4, 10, 20, 40]",
	"func _check_prosperity() -> void:",
	'"prosperity_rank": prosperity_rank',
	"func next_prosperity_threshold() -> int:",
	"func prosperity_chapter_progress() -> float:",
	"func recommended_upgrade_key() -> String:",
	"func recommended_affordable_purchase() -> Dictionary:",
	"var buy_mode := 1",
	"drones = Prestige.starting_drones()",
	"levels = Prestige.starting_levels()",
) if token not in game_state]
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
