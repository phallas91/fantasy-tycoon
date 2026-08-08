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
		if iter % 10 == 0:
			_auto_buy()
		t += dt; iter += 1
		if iter % 1500 == 0:
			_report(t)
	_report(t)
	print("=== FINAL country=%d/%d cities=%d drones=%d credits=%s ===" % [
		GameState.current_country + 1, Economy.num_countries(), GameState.cities_unlocked,
		GameState.drones, Fmt.short(GameState.credits)])
	SaveSystem.wipe(); get_tree().quit()

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
