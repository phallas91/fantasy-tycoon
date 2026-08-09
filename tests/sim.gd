extends Node
## Headless sim: drives GameState ~30 min, buying/unlocking/expanding, to validate
## the delivery-based country progression. Credits come only from deliveries.

func _ready() -> void:
	var dt := 0.1
	var t := 0.0
	var iter := 0
	print("=== Arcane Trade Empire world sim ===")
	while t < 1800.0:
		GameState._process(dt)
		if not _state_is_valid():
			push_error("SIM_SMOKE: invalid state at t=%.1f" % t)
			get_tree().quit(1)
			return
		if iter % 10 == 0:
			_auto_buy()
		t += dt; iter += 1
		if iter % 1500 == 0:
			_report(t)
	_report(t)
	if GameState.total_deliveries <= 0 or GameState.total_earned <= 0.0:
		push_error("SIM_SMOKE: economy produced no deliveries or earnings")
		get_tree().quit(1)
		return
	if GameState.prosperity_rank <= 0:
		push_error("SIM_SMOKE: early city prosperity loop never advanced")
		get_tree().quit(1)
		return
	print("=== FINAL country=%d/%d cities=%d drones=%d credits=%s ===" % [
		GameState.current_country + 1, Economy.num_countries(), GameState.cities_unlocked,
		GameState.drones, Fmt.short(GameState.credits)])
	print("SIM_SMOKE: PASS")
	SaveSystem.wipe(); get_tree().quit(0)

func _state_is_valid() -> bool:
	if not is_finite(GameState.credits) or GameState.credits < 0.0:
		return false
	if not is_finite(GameState.total_earned) or GameState.total_earned < 0.0:
		return false
	if GameState.drones < 1 or GameState.total_deliveries < 0:
		return false
	if GameState.prosperity_rank < 0 or GameState.prosperity_rank > GameState.PROSPERITY_THRESHOLDS.size():
		return false
	if GameState.current_country < 0 or GameState.current_country >= Economy.num_countries():
		return false
	if GameState.cities_unlocked < 1 or GameState.cities_unlocked > GameState.max_cities():
		return false
	for key: String in Economy.UPGRADE_ORDER:
		if int(GameState.levels.get(key, -1)) < 0:
			return false
	return true

func _auto_buy() -> void:
	if GameState.can_expand():
		GameState.expand_country(); return
	if GameState.can_unlock_city():
		GameState.unlock_city(); return
	var best := ""; var best_cost := INF
	var dcost := GameState.drone_cost()
	if dcost < best_cost: best = "drone"; best_cost = dcost
	for k in Economy.UPGRADE_ORDER:
		var c := Economy.upgrade_cost(k, int(GameState.levels[k]))
		if c < best_cost: best = k; best_cost = c
	if best != "" and GameState.credits >= best_cost:
		if best == "drone": GameState.buy_drones()
		else: GameState.buy_upgrade_multi(best)

func _report(t: float) -> void:
	print("t=%4ds  country=%2d (%s)  cities=%d/%d  drones=%3d  credits=%9s  income~%9s/s" % [
		int(t), GameState.current_country + 1, Economy.country_name(GameState.current_country),
		GameState.cities_unlocked, GameState.max_cities(), GameState.drones,
		Fmt.short(GameState.credits), Fmt.short(GameState.income_per_sec())])
