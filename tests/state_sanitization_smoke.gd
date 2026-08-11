extends SceneTree
## Imports deliberately hostile legacy values and verifies all derived math stays safe.

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("STATE_SANITIZATION: " + message)
	quit(1)

func _run() -> void:
	await process_frame
	var game_state := root.get_node("GameState")
	var prestige := root.get_node("Prestige")
	var economy := root.get_node("Economy")
	var save_system := root.get_node("SaveSystem")
	var billing := root.get_node("Billing")
	game_state.from_dict({
		"credits": INF,
		"gems": 9_999_999_999,
		"current_country": 9_999_999,
		"cities_unlocked": 9_999_999,
		"drones": 9_999_999_999,
		"levels": {"speed": 9_999_999, "cargo": -8, "value": 9_999_999, "routes": 9_999_999},
		"talents": {"global": 999, "speed": -4, "value": 999, "hangar": 999},
		"gem_boost": 9_999_999,
		"earn_boost_timer": INF,
		"total_earned": INF,
		"regions_done": [-1, 0, 0, 999],
		"skins_owned": ["classic", "not-a-skin"],
		"skin_active": "not-a-skin",
	})
	prestige.from_dict({
		"count": 9_999_999,
		"pgems": -50,
		"total": -100,
		"mult": INF,
		"shop": ["speed_5", "speed_5", "hacked_item", "vip_24h"],
		"ascendant": 9_999_999,
		"run_start": INF,
	})
	billing.from_dict({
		"perm_mult": INF,
		"processed_tokens": ["", " valid-token ", "valid-token"] + range(250),
	})

	if not is_finite(game_state.income_per_sec()) or game_state.income_per_sec() < 0.0:
		_fail("hostile state produced invalid income")
		return
	for key: String in economy.UPGRADE_ORDER:
		var cost: float = game_state.upgrade_cost_multi(key, 1)
		if not is_finite(cost) or cost <= 0.0:
			_fail("invalid %s upgrade cost after sanitization" % key)
			return
	if game_state.skin_active != "classic" or game_state.regions_done != [0]:
		_fail("cosmetic or region allowlist bypassed")
		return
	if not is_finite(prestige.effective_mult()) or prestige.pgems < 0:
		_fail("hostile prestige state produced invalid multiplier or currency")
		return
	for item_id in prestige.shop_owned:
		if not prestige.SHOP.has(item_id):
			_fail("unknown prestige shop item survived migration")
			return
	if not is_finite(billing.premium_income_mult()) or billing.premium_income_mult() < 1.0:
		_fail("hostile billing state produced invalid multiplier")
		return
	if billing._processed_tokens.size() > 200 or "" in billing._processed_tokens:
		_fail("billing token history was not sanitized")
		return

	game_state.reset()
	if not game_state.is_upgrade_unlocked("cargo") or game_state.is_upgrade_unlocked("speed") \
			or game_state.is_upgrade_unlocked("value") or game_state.is_upgrade_unlocked("routes"):
		_fail("opening construction paths are not progressively gated")
		return
	game_state.prosperity_rank = 1
	if not game_state.is_upgrade_unlocked("speed") or not game_state.is_upgrade_unlocked("value") \
			or game_state.is_upgrade_unlocked("routes"):
		_fail("city rank 1 construction unlocks are inconsistent")
		return
	game_state.prosperity_rank = 2
	if not game_state.is_upgrade_unlocked("routes"):
		_fail("route construction does not unlock with automation")
		return
	game_state.credits = 1.0e12
	game_state.drones = 4
	var advised_kind := str(game_state.recommended_affordable_purchase().get("kind", ""))
	var drones_before: int = int(game_state.drones)
	var levels_before: Dictionary = game_state.levels.duplicate(true)
	game_state._try_auto_buy()
	if advised_kind == "drone":
		if game_state.drones != drones_before + 1:
			_fail("automatic manager ignored its courier recommendation")
			return
	elif advised_kind.is_empty() or int(game_state.levels.get(advised_kind, 0)) != int(levels_before.get(advised_kind, 0)) + 1:
		_fail("automatic manager ignored its best-value construction recommendation")
		return
	prestige.reset()
	save_system.wipe()
	print("STATE_SANITIZATION: PASS (legacy extremes clamped; value-led automation consistent)")
	quit(0)
