extends SceneTree
## Imports deliberately hostile legacy values and verifies all derived math stays safe.

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("STATE_SANITIZATION: " + message)
	quit(1)

func _run() -> void:
	await process_frame
	GameState.from_dict({
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
	Prestige.from_dict({
		"count": 9_999_999,
		"pgems": -50,
		"total": -100,
		"mult": INF,
		"shop": ["speed_5", "speed_5", "hacked_item", "vip_24h"],
		"ascendant": 9_999_999,
		"run_start": INF,
	})

	if not is_finite(GameState.income_per_sec()) or GameState.income_per_sec() < 0.0:
		_fail("hostile state produced invalid income")
		return
	for key: String in Economy.UPGRADE_ORDER:
		var cost := GameState.upgrade_cost_multi(key, 1)
		if not is_finite(cost) or cost <= 0.0:
			_fail("invalid %s upgrade cost after sanitization" % key)
			return
	if GameState.skin_active != "classic" or GameState.regions_done != [0]:
		_fail("cosmetic or region allowlist bypassed")
		return
	if not is_finite(Prestige.effective_mult()) or Prestige.pgems < 0:
		_fail("hostile prestige state produced invalid multiplier or currency")
		return
	for item_id in Prestige.shop_owned:
		if not Prestige.SHOP.has(item_id):
			_fail("unknown prestige shop item survived migration")
			return

	GameState.reset()
	Prestige.reset()
	SaveSystem.wipe()
	print("STATE_SANITIZATION: PASS (legacy extremes clamped; derived economy finite)")
	quit(0)
