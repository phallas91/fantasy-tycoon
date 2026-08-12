#!/usr/bin/env python3
"""Guard the fantasy map and calm progressive first-session experience."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
economy = (ROOT / "scripts" / "economy.gd").read_text(encoding="utf-8")
main = (ROOT / "scripts" / "main.gd").read_text(encoding="utf-8")
map_view = (ROOT / "scripts" / "map_view.gd").read_text(encoding="utf-8")
bonus = (ROOT / "scripts" / "bonus_drone.gd").read_text(encoding="utf-8")
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
	"if GameState.cities_unlocked >= 3:",
	"func _refresh_focus_action() -> void:",
	"if GameState.drones >= 4 or upgrade_total >= 2:",
	'if _progression_stage() == 0:',
	"func _opening_city_chapter_active() -> bool:",
	"func _courier_objective() -> Dictionary:",
	"const OPENING_FLEET_TARGET := 4",
	'"progress_override": true, "accent": UITheme.ACCENT, "icon": "ic_drone"',
	"if _opening_city_chapter_active():",
	"return _prosperity_objective()",
	"func _next_prosperity_unlock_text() -> String:",
	'"focus": _focus_btn, "cost": GameState.drone_cost_multi(1)',
    "func _nav_unlocked(tab_index: int) -> bool:",
	"5: return stage >= 2",
	"2: return stage >= 3",
	"4: return stage >= 4",
	"3: return stage >= 5",
	"func _available_contract_count() -> int:",
	"func _update_contract_visibility() -> void:",
	'_claim_all_btn.set_meta("progression_hidden", true)',
	"ready and GameState.current_country >= 1",
    "_nav_btns[i].visible = dashboard_ready and _nav_unlocked(i)",
    "if not _nav_unlocked(i):",
    "lbl.text = tr(label_text)",
    'tr("%s desbloqueada!") % tr(str(def.get("name", id)))',
	"DisplayServer.SCREEN_LANDSCAPE",
	"const SIDE_PANEL_W := 410.0",
	"const LANDSCAPE_PANEL_TOP := 204.0",
	"func _build_guided_action() -> void:",
	"var dashboard_ready := stage > 0",
	"_focus_card.visible = not dashboard_ready",
	"func _on_prosperity_advanced(",
	"func _show_income_gain(before_income: float, source: Control) -> void:",
	"GameState.auto_bought.connect(_on_auto_bought)",
	"const OFFLINE_POPUP_MIN_SECONDS := 60.0",
	"func _collect_short_offline_reward() -> void:",
	"Daily.reward_ready.connect(_refresh_daily_hud)",
	"func _refresh_daily_hud() -> void:",
	'_streak_lbl.text = tr("Recolher") if Daily.pending else "%dd" % Daily.streak',
	"func _show_expansion_confirm() -> void:",
	'"progress_override": true',
	'"upgrade_key": recommended_key',
	"(_mode_btns[mode] as Button).visible = GameState.prosperity_rank >= required_rank",
	"var auto_manager_unlocked := GameState.prosperity_rank >= 2",
	"if auto_manager_unlocked != _auto_manager_panel_unlocked:",
	"var prestige_panel_unlocked := GameState.current_country >= 3 or Prestige.count > 0",
	'_auto_mgr_section.set_meta("progression_hidden", not auto_manager_unlocked)',
	'not GameState.is_upgrade_unlocked(unlock_key)',
	'get_meta("progression_hidden", false)',
	"func _reveal_prosperity_unlocks(rank: int) -> void:",
	'call_deferred("_reveal_prosperity_unlocks", rank)',
	"_map.reveal_landmark(key, landmark_name)",
)
required_map = (
	'load("res://assets/fantasy/arcane_city_world_v1.webp")',
	"func _draw_realm_details(",
	"func _draw_ground_traffic(",
	"func _draw_district_investments(",
	"_draw_city_district(cp, i, true)",
	"_draw_city_district(cp, i, false)",
	'GameState.levels.get("cargo", 0)',
	'GameState.levels.get("value", 0)',
	'GameState.levels.get("speed", 0)',
	'GameState.levels.get("routes", 0)',
	"if cargo_level >= 25:",
	"if value_level >= 25:",
	"if speed_level >= 25:",
	"if route_level >= 25:",
	"func _draw_recommended_investment(",
	"func _draw_construction_activity(",
	"func reveal_landmark(key: String, landmark_name: String) -> void:",
	"func _draw_landmark_reveal(cap: Vector2) -> void:",
	"func _income_chip(p: Vector2, income: String) -> void:",
	"var trip := 1.0 - absf(phase * 2.0 - 1.0)",
	"if phase < 0.5:",
	"func set_recommended_investment(",
	"_frontier_income_str",
    "# A luminous river crosses the realm",
    "# Mountain chain:",
    "# Forest groves",
    "# Roads connect every settlement",
)

missing = [token for token in required_economy if token not in economy]
missing += [token for token in required_main if token not in main]
missing += [token for token in required_map if token not in map_view]
missing += [token for token in (
	"GameState.current_country == 0 and GameState.cities_unlocked <= 1",
	"and GameState.prosperity_rank < 2:",
	'"label": "Lucros ×2 durante 3 minutos!"',
) if token not in bonus]
missing += [token for token in (
	'rare_btn.text = tr("Recolher")',
	'tr(str(reward.get("label",',
) if token not in main]
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
	'const UPGRADE_UNLOCK_RANK := {"cargo": 0, "speed": 1, "value": 1, "routes": 2}',
	"func is_upgrade_unlocked(key: String) -> bool:",
	"func upgrade_keys_unlocked_at(rank: int) -> Array[String]:",
	"func projected_upgrade_income_gain(key: String, count: int, current_income := -1.0) -> float:",
	"func city_network_mult(route_count := -1) -> float:",
	"func projected_city_income_gain(current_income := -1.0) -> float:",
	"var last_city_income_gain := 0.0",
	"func cargo_mult(level := -1) -> float:",
	"func value_mult(level := -1) -> float:",
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

post_boot = main.split("func _post_boot(loaded: bool) -> void:", 1)[1].split(
    "func _has_modal_overlay()", 1
)[0]
fresh_launch = post_boot.split("elif _should_show_offline_popup():", 1)[0]
if "_show_welcome_popup()" in fresh_launch:
    raise SystemExit("FANTASY_ONBOARDING: FAIL: fresh launch is still blocked by a tutorial modal")
if "Fx.shimmer(_focus_btn, UITheme.GREEN, true)" not in fresh_launch:
    raise SystemExit("FANTASY_ONBOARDING: FAIL: fresh launch no longer highlights its in-world action")

print("FANTASY_ONBOARDING: PASS (fantasy geometry + staged navigation + deferred bonus griffin)")
