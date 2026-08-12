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
	prestige.reset()
	billing.starter_owned = true
	game_state.reset()
	if game_state.drones != 3:
		_fail("founder pack does not grant its permanent realm-start courier bonus")
		return
	prestige._soft_reset()
	if game_state.drones != 3:
		_fail("founder courier bonus is lost on prestige")
		return
	billing.starter_owned = false
	game_state.reset()
	# Spending influence on a talent must be a power gain, never a hidden loss of
	# the same global reputation multiplier used to advertise progression.
	game_state.influence = 8
	game_state.influence_total = 8
	if not is_equal_approx(float(game_state.influence_reputation_mult()), 1.4) \
			or not is_equal_approx(float(game_state.influence_reputation_mult(12)), 1.6):
		_fail("permanent realm reputation preview does not match earned influence")
		return
	var pre_talent_mult := float(game_state.global_mult())
	if not game_state.buy_talent("global") or float(game_state.global_mult()) <= pre_talent_mult:
		_fail("spending influence on a talent makes the player weaker")
		return
	game_state.reset()
	var breakdown_labels: Array[String] = []
	for row: Array in game_state.mult_breakdown():
		breakdown_labels.append(str(row[0]))
	for expected_label in ["Rede de cidades", "Capacidade de Carga", "Valor da Encomenda", "Bónus Premium"]:
		if not breakdown_labels.has(expected_label):
			_fail("income breakdown omits %s" % expected_label)
			return
	if breakdown_labels.has("Combo"):
		_fail("temporary delivery combo is presented as permanent income")
		return
	# Every settlement must be a real tycoon expansion, not a cosmetic route
	# that silently dilutes the same fleet across more destinations.
	for country_index in range(economy.num_countries()):
		game_state.current_country = country_index
		game_state.drones = 10
		game_state.cities_unlocked = 1
		while game_state.cities_unlocked < game_state.max_cities():
			var city_income_before: float = float(game_state.income_per_sec())
			var city_gain: float = float(game_state.projected_city_income_gain(city_income_before))
			game_state.cities_unlocked += 1
			var city_gain_measured: float = float(game_state.income_per_sec()) - city_income_before
			if city_gain <= 0.0 or not is_equal_approx(city_gain, city_gain_measured):
				_fail("city expansion is not guaranteed positive in realm %d" % country_index)
				return
	game_state.reset()
	game_state.drones = 10
	game_state.credits = 1.0e12
	var signalled_city_gain := float(game_state.projected_city_income_gain())
	if not game_state.unlock_city() or not is_equal_approx(
			float(game_state.last_city_income_gain), signalled_city_gain):
		_fail("city unlock feedback does not report its exact income gain")
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
	if game_state.upgrade_keys_unlocked_at(1) != ["speed", "value"] \
			or game_state.upgrade_keys_unlocked_at(2) != ["routes"]:
		_fail("chapter unlock reveal does not match the actual construction gates")
		return
	# Every realm is its own visible city-building chapter. Permanent influence
	# and talents survive, while local construction, bulk buying and automation
	# must not silently arrive completed in the next realm.
	prestige.reset()
	game_state.current_country = 0
	game_state.cities_unlocked = game_state.max_cities()
	game_state.credits = 1.0e18
	game_state.levels = {"speed": 40, "cargo": 40, "value": 40, "routes": 40}
	game_state.prosperity_rank = game_state.PROSPERITY_THRESHOLDS.size()
	game_state.buy_mode = -1
	game_state.auto_manager = true
	game_state.influence = 3
	game_state.influence_total = 3
	if not game_state.expand_country():
		_fail("fully built realm cannot expand during chapter reset check")
		return
	if game_state.current_country != 1 or game_state.prosperity_rank != 0 \
			or game_state.buy_mode != 1 or game_state.investment_total() != 0:
		_fail("new realm inherits completed local construction progression")
		return
	if not game_state.auto_manager or game_state.auto_manager_available():
		_fail("automation preference is not paused until the new city earns it")
		return
	game_state.prosperity_rank = 2
	if not game_state.auto_manager_available():
		_fail("earned automation does not resume in the rebuilt city")
		return
	var income_before_projection: float = float(game_state.income_per_sec())
	var projected_gain: float = float(game_state.projected_upgrade_income_gain("cargo", 10, income_before_projection))
	game_state.levels["cargo"] = int(game_state.levels["cargo"]) + 10
	var measured_gain: float = float(game_state.income_per_sec()) - income_before_projection
	game_state.levels["cargo"] = int(game_state.levels["cargo"]) - 10
	if not is_equal_approx(projected_gain, measured_gain):
		_fail("bulk construction card does not preview its exact income gain")
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
