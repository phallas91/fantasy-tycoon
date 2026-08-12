extends Node
## Core state & simulation (autoload: GameState). World-map country progression.
## Credits are earned ONLY per delivery (no time-based trickle).

const BASE_SPEED := 0.5
const BASE_DELIV := 4.0
const OFFLINE_CAP_BASE := 7200.0
const OFFLINE_EFF := 0.5
const AUTOSAVE_INTERVAL := 15.0
const EARN_BOOST_DURATION := 300.0
const MAX_VISUAL_DRONES := 7
const COMBO_DECAY := 10.0
## Drawn drones travel on a SEPARATE, slower visual clock (v["vt"]). It STILL
## scales with speed_factor() — so buying speed upgrades visibly speeds the fleet
## up — but is 20x slower than the logical delivery cadence so they're followable
## rather than a blur. Income/combo/deliveries are unchanged (still driven by the
## fast logical v["t"]); this only affects where drones are DRAWN.
const VISUAL_SPEED_FACTOR := 0.05

## `count` is how many arrivals this emission represents. At high speed_factor a
## drone completes several round trips in one frame, and they are banked in one
## emission rather than spamming the signal — so anything COUNTING deliveries must
## add `count`, not 1. `amount` is the summed credits for all of them.
signal delivered(amount: float, city_index: int, count: int)
signal city_unlocked(index: int)
signal country_changed(index: int)
signal fleet_changed()
signal region_completed(region_index: int)
signal prosperity_advanced(rank: int, cash_reward: float, gem_reward: int)

const PROSPERITY_THRESHOLDS := [4, 10, 20, 40]
const PROSPERITY_CASH_SECONDS := [30.0, 60.0, 120.0, 300.0]
const PROSPERITY_GEMS := [0, 1, 2, 5]
const UPGRADE_UNLOCK_RANK := {"cargo": 0, "speed": 1, "value": 1, "routes": 2}

# --- persisted ---
var credits := 0.0
var gems := 0
var influence := 0
var influence_total := 0
var current_country := 0
var regions_done: Array = []   # region indices whose one-time completion bonus is earned (permanent)
var cities_unlocked := 1          # active delivery cities (capital is always home)
var last_city_income_gain := 0.0  # exact measured gain for unified unlock feedback
var drones := 1
var levels := {"speed": 0, "cargo": 0, "value": 0, "routes": 0}
var talents := {"global": 0, "speed": 0, "value": 0, "hangar": 0}
var gem_boost := 0
var skins_owned: Array = ["classic"]
var skin_active := "classic"
var earn_boost_timer := 0.0
var total_earned := 0.0
var total_deliveries := 0
var combo_window_bonus := 0.0   # +seconds on combo decay (gem shop, permanent)
var guild_blessing_until := 0  # earned through the Vermächtnis shop
var auto_manager := false      # gameplay feature, available to every player
var prosperity_rank := 0

# --- transient ---
var earn_boost_mult := 2.0
var buy_mode := 1   # calm first session; bulk modes unlock through city growth
var pending_offline := 0.0
var pending_offline_seconds := 0.0
var vdrones: Array = []
var _autosave_t := 0.0
var combo: int = 0
var _combo_decay_t: float = 0.0
var _auto_manager_t := 0.0
const AUTO_MANAGER_INTERVAL := 2.5

signal auto_bought(kind: String)

func _ready() -> void:
	_rebuild_drones()

# ---------------------------------------------------------------- derived
func max_cities() -> int:
	return Economy.country_cities(current_country).size() - 1   # excludes capital

func speed_factor() -> float:
	var base := (1.0 + 0.03 * float(levels["speed"]) * Economy.milestone_mult(int(levels["speed"]))) \
		+ 0.04 * float(talents["speed"])
	return base * Events.current_spd_mult

func is_guild_blessing_active() -> bool:
	return guild_blessing_until > int(Time.get_unix_time_from_system())

func guild_blessing_mult() -> float:
	return 2.0 if is_guild_blessing_active() else 1.0

func skin_collection_mult() -> float:
	return 1.0 + 0.02 * float(max(0, skins_owned.size() - 1))

func global_mult() -> float:
	# Earned influence is permanent trading reputation; the current balance is
	# only its spendable talent currency. Using the balance here made every
	# talent purchase remove 5% per spent point and could leave the player weaker
	# after buying an advertised bonus. Lifetime influence preserves progression.
	return (1.0 + 0.05 * float(influence_total)) * (1.0 + 0.06 * float(talents["global"])) \
		* (1.0 + 0.25 * float(gem_boost)) * guild_blessing_mult() \
		* Events.current_mult * Prestige.effective_mult() * skin_collection_mult() \
		* region_bonus_mult() * Billing.premium_income_mult()

## Permanent multiplier from completed world regions (see Economy.REGIONS). Earned
## once each and kept forever (survives prestige), so it's a long-horizon meta
## reward, not a per-run inflator. Max ~2.1x when all 7 regions are done — which
## requires reaching country 40, i.e. many prestiges deep.
func region_bonus_mult() -> float:
	var m := 1.0
	for r in regions_done:
		var ri := int(r)
		if ri >= 0 and ri < Economy.REGIONS.size():
			m += float(Economy.REGIONS[ri]["bonus"])
	return m

## Award any newly-completed region's one-time bonus. A region is complete once
## you've expanded past its last country, or you're ON its last country with every
## city unlocked (covers the final region, the USA). Called after each expand/unlock.
func _check_regions() -> void:
	for r in range(Economy.REGIONS.size()):
		if regions_done.has(r):
			continue
		var last: int = int(Economy.REGIONS[r]["to"])
		var complete := current_country > last or (current_country == last and all_cities_unlocked())
		if complete:
			regions_done.append(r)
			region_completed.emit(r)

## [label, factor] rows for the income-breakdown popup — every multiplier that
## feeds income, so players can see WHY their rate is what it is. Order roughly
## by typical impact.
func mult_breakdown() -> Array:
	return [
		["Prestige", Prestige.effective_mult()],
		["Bênção da Guilda", guild_blessing_mult()],
		["Evento", Events.current_mult],
		["Influência", 1.0 + 0.05 * float(influence_total)],
		["Talento Global", 1.0 + 0.06 * float(talents["global"])],
		["Núcleo de Lucro", 1.0 + 0.25 * float(gem_boost)],
		["Hangar de Skins", skin_collection_mult()],
		["Regiões", region_bonus_mult()],
		["Rede de cidades", city_network_mult()],
		["Capacidade de Carga", cargo_mult()],
		["Valor da Encomenda", value_mult()],
		["Rede de Rotas", route_mult()],
		["Velocidade dos Drones", speed_factor()],
		["Bónus Premium", Billing.premium_income_mult()],
	]

func route_mult() -> float:
	var rl := int(levels.get("routes", 0))
	return 1.0 + 0.025 * float(rl) * Economy.milestone_mult(rl)

func cargo_mult(level := -1) -> float:
	var cargo_level: int = int(levels.get("cargo", 0)) if level < 0 else int(level)
	return 1.0 + 0.25 * float(cargo_level) * Economy.milestone_mult(cargo_level)

func value_mult(level := -1) -> float:
	var value_level: int = int(levels.get("value", 0)) if level < 0 else int(level)
	return pow(1.04, float(value_level)) * Economy.milestone_mult(value_level)

## Picks the construction path with the strongest immediate income gain per
## credit. This keeps the advisor useful instead of merely pointing at the
## cheapest row, and naturally values milestone levels when their multiplier
## makes a landmark purchase unusually strong.
func recommended_upgrade_key() -> String:
	var best_key := "cargo"
	var best_value := -INF
	for key: String in ["speed", "cargo", "value", "routes"]:
		if not is_upgrade_unlocked(key):
			continue
		var value := upgrade_value_per_credit(key)
		if value > best_value:
			best_value = value
			best_key = key
	return best_key

func upgrade_value_per_credit(key: String) -> float:
	var level := int(levels.get(key, 0))
	var current_factor := _upgrade_income_factor(key, level)
	var next_factor := _upgrade_income_factor(key, level + 1)
	var relative_gain := maxf(0.0, next_factor / maxf(current_factor, 0.0001) - 1.0)
	return relative_gain / maxf(upgrade_cost_multi(key, 1), 0.0001)

## Exact permanent realm-income increase for the selected bulk purchase. The
## optional current income lets the HUD reuse its already calculated value
## instead of walking every active route four more times per frame.
func projected_upgrade_income_gain(key: String, count: int, current_income := -1.0) -> float:
	if not levels.has(key) or count <= 0:
		return 0.0
	var level := int(levels[key])
	var before_factor := _upgrade_income_factor(key, level)
	var after_factor := _upgrade_income_factor(key, level + count)
	var income := income_per_sec() if current_income < 0.0 else current_income
	return income * maxf(0.0, after_factor / maxf(before_factor, 0.0001) - 1.0)

func is_upgrade_unlocked(key: String) -> bool:
	return UPGRADE_UNLOCK_RANK.has(key) \
		and prosperity_rank >= int(UPGRADE_UNLOCK_RANK[key])

func upgrade_keys_unlocked_at(rank: int) -> Array[String]:
	var unlocked: Array[String] = []
	for key: String in Economy.UPGRADE_ORDER:
		if int(UPGRADE_UNLOCK_RANK.get(key, 99)) == rank:
			unlocked.append(key)
	return unlocked

## Best affordable automatic purchase, including another courier. Kept public
## for transparent UI/tests: automation follows the same value-per-credit rule
## as the player-facing advisor and never gets a hidden economic advantage.
func recommended_affordable_purchase() -> Dictionary:
	var best_kind := ""
	var best_cost := INF
	var best_value := -INF
	var courier_cost := drone_cost()
	if credits >= courier_cost:
		best_kind = "drone"
		best_cost = courier_cost
		best_value = (1.0 / float(maxi(drones, 1))) / maxf(courier_cost, 0.0001)
	for key: String in ["speed", "cargo", "value", "routes"]:
		if not is_upgrade_unlocked(key):
			continue
		var cost := upgrade_cost_multi(key, 1)
		var value := upgrade_value_per_credit(key)
		if credits >= cost and value > best_value:
			best_kind = key
			best_cost = cost
			best_value = value
	return {"kind": best_kind, "cost": best_cost, "value": best_value}

func _upgrade_income_factor(key: String, level: int) -> float:
	match key:
		"speed":
			return 1.0 + 0.03 * float(level) * Economy.milestone_mult(level) \
				+ 0.04 * float(talents.get("speed", 0))
		"cargo":
			return cargo_mult(level)
		"value":
			return value_mult(level)
		"routes":
			return 1.0 + 0.025 * float(level) * Economy.milestone_mult(level)
	return 1.0

func combo_mult() -> float:
	# High tiers (150+) are a pure ACTIVE-PLAY skill reward: combo decays in ~10s,
	# so sustaining a 150/250/500 chain demands constant attention — it never
	# affects idle/offline income, so it can't inflate the tuned economy.
	if combo >= 500: return 3.0
	if combo >= 250: return 2.5
	if combo >= 150: return 2.25
	if combo >= 100: return 2.0
	if combo >= 50:  return 1.5
	if combo >= 25:  return 1.25
	if combo >= 10:  return 1.1
	return 1.0

## Upgrades & drones scale with the country's pay tier so they stay meaningfully
## priced after each expansion (fixes "trivial after the first country").
func cost_scale() -> float:
	return Economy.pay_tier(current_country)

func offline_cap() -> float:
	var prestige_extra: float = OFFLINE_CAP_BASE * Prestige.extra_offline_pct()
	# +30 min of offline cap per prestige (up to +4h at count 8) — a structural
	# reward for prestiging that veterans feel, beyond the flat multiplier.
	var count_extra: float = float(mini(Prestige.count, 8)) * 1800.0
	var earned_cap := OFFLINE_CAP_BASE + prestige_extra + count_extra \
		+ (79200.0 if is_guild_blessing_active() else 0.0)
	return maxf(earned_cap, Billing.premium_offline_cap())

## `cities` optional: pass the already-fetched array to avoid re-reading
## Economy.country_cities() (a fresh Dictionary lookup) for every route/drone
## in a loop where it's identical every iteration.
func _route_dist(r: int, cities: Array = []) -> float:
	var c: Array = cities if not cities.is_empty() else Economy.country_cities(current_country)
	var cap := Vector2(c[0]["x"], c[0]["y"])
	var idx: int = clampi(1 + r, 1, c.size() - 1)
	var cc := Vector2(c[idx]["x"], c[idx]["y"])
	return max(0.06, cap.distance_to(cc))

## Per-delivery multiplier that does NOT depend on route distance — only
## (1.0 + dist) does, applied by the caller. Hoisted out of per_delivery()
## so callers looping over many routes/drones (income_per_sec(), _process()
## below) can compute this ONCE per frame instead of recomputing 2 pow()
## calls + 4 multiplier lookups for every single one.
func city_network_mult(route_count := -1) -> float:
	var active_routes: int = cities_unlocked if route_count < 0 else int(route_count)
	return 1.0 + 0.12 * float(maxi(active_routes, 1) - 1)

func _delivery_const_mult(route_count := -1) -> float:
	var vf := cargo_mult() \
		* value_mult() \
		* (1.0 + 0.04 * float(talents["value"]))
	return BASE_DELIV * vf * Economy.pay_tier(current_country) * global_mult() * route_mult() \
		* city_network_mult(route_count)

## Credits for one delivery to a route (weak upgrade gains; scales with country tier).
func per_delivery(dist: float) -> float:
	return _delivery_const_mult() * (1.0 + dist)

func fleet_scale() -> float:
	return float(drones) / float(max(1, vdrones.size()))

## Estimated credits/sec (for display & offline) — derived from delivery throughput.
func income_per_sec() -> float:
	return _income_for_route_count(cities_unlocked)

func _income_for_route_count(n: int) -> float:
	if n < 1:
		return 0.0
	# hoisted out of the loop: identical for every route, was previously
	# recomputed (2 pow() calls + a fresh country_cities() lookup) per route
	var sf := speed_factor()
	var cities := Economy.country_cities(current_country)
	var const_mult := _delivery_const_mult(n)
	var s := 0.0
	for r in range(n):
		var d := _route_dist(r, cities)
		var tt := 2.0 * d / (BASE_SPEED * sf)
		s += const_mult * (1.0 + d) / tt
	return float(drones) * (s / float(n))

func projected_city_income_gain(current_income := -1.0) -> float:
	if cities_unlocked >= max_cities():
		return 0.0
	var income := income_per_sec() if current_income < 0.0 else current_income
	return maxf(0.0, _income_for_route_count(cities_unlocked + 1) - income)

## Exact contribution of one active trade route to the displayed realm income.
## The fleet is distributed evenly across all routes, matching income_per_sec().
## Exposed for the map city inspector so it never presents the realm total as if
## every individual city generated that full amount.
func route_income_per_sec(route: int) -> float:
	var n := cities_unlocked
	if n < 1 or route < 0 or route >= n:
		return 0.0
	var cities := Economy.country_cities(current_country)
	var d := _route_dist(route, cities)
	var tt := 2.0 * d / (BASE_SPEED * speed_factor())
	var route_rate := _delivery_const_mult() * (1.0 + d) / tt
	return (float(drones) / float(n)) * route_rate

func drone_cost() -> float:
	return Economy.drone_cost(drones) * cost_scale() * max(0.5, 1.0 - 0.02 * float(talents["hangar"]))

# ---------------------------------------------------------------- visuals
func _rebuild_drones() -> void:
	vdrones.clear()
	var n: int = min(drones, MAX_VISUAL_DRONES)
	var routes: int = max(1, cities_unlocked)
	for i in range(n):
		vdrones.append({"route": i % routes, "t": randf(), "dir": 1, "vt": randf(), "vdir": 1})
	fleet_changed.emit()

# ---------------------------------------------------------------- loop
func _process(delta: float) -> void:
	if earn_boost_timer > 0.0:
		earn_boost_timer = max(0.0, earn_boost_timer - delta)
	var boost: float = earn_boost_mult if earn_boost_timer > 0.0 else 1.0
	if _combo_decay_t > 0.0:
		_combo_decay_t -= delta
		if _combo_decay_t <= 0.0:
			combo = 0
			_combo_decay_t = 0.0
	var fs := fleet_scale()
	# hoisted out of the per-drone loop: identical for every drone this frame
	# (was recomputed up to MAX_VISUAL_DRONES=16 times/frame otherwise)
	var sf := speed_factor()
	# Same hoist, and the one _delivery_const_mult()'s own docstring asks for:
	# income_per_sec() already does this, _process() didn't and still paid ~7 pow()
	# + a Time syscall per delivery. Late game every drone delivers every frame, so
	# that was up to 16x/frame. Bit-exact: nothing this reads (levels, talents,
	# influence, gem_boost, country, event/prestige mults) is mutated in the loop.
	# combo_mult() stays INSIDE — combo increments per delivery and each must see
	# its own value, so hoisting THAT would move the tuned economy.
	var const_mult := _delivery_const_mult()
	var cities := Economy.country_cities(current_country)
	for v in vdrones:
		var d := _route_dist(int(v["route"]), cities)
		var rate := BASE_SPEED * sf / d
		# A drone is a triangle wave: phase p in [0,2), outbound while p < 1 (t = p),
		# inbound after (t = 2 - p). One delivery per crossing of an odd integer.
		#
		# This used to be `t += rate*dir*delta` + `t = 1.0` on overshoot, which THREW
		# THE OVERSHOOT AWAY: once rate*delta > 1 a drone could only ever bank one
		# delivery per frame no matter how fast it flew. That silently capped active
		# income (speed upgrades stopped paying past ~level 90) and — worse — made
		# earnings depend on FRAME RATE: the 30-min sim reaches country 13 with 7.96aa
		# at 10fps and country 17 with 2.17ab at 60fps, same decisions.
		#
		# income_per_sec() is the game's canonical model — it already pays the
		# uncapped rate for offline earnings, Time Warps and Credit Injection (bought
		# with gems), and it's what the HUD shows. Only active play under-delivered,
		# so playing earned LESS than being idle. Counting arrivals in closed form
		# fixes all of it and stays O(1) at any speed.
		var travel := rate * delta
		var p: float = v["t"] if int(v["dir"]) == 1 else 2.0 - v["t"]
		var p2 := p + travel
		var arrivals := int(floor((p2 - 1.0) / 2.0) - floor((p - 1.0) / 2.0))
		var np := fposmod(p2, 2.0)
		if np < 1.0:
			v["t"] = np; v["dir"] = 1
		else:
			v["t"] = 2.0 - np; v["dir"] = -1
		if arrivals > 0:
			# For the overwhelmingly common arrivals == 1 this is bit-identical to the
			# old line. For n > 1 all n share the post-increment combo instead of each
			# seeing its own — combo saturates (x3.0 at 500) in well under a second at
			# those rates, so the difference is confined to a negligible ramp.
			combo += arrivals
			_combo_decay_t = COMBO_DECAY + combo_window_bonus
			var delivery_factor := (1.0 + d) * fs * boost * combo_mult()
			var amt := const_mult * delivery_factor * float(arrivals)
			if Events.is_one_shot_active():
				# The boosted cached multiplier applies to exactly the first arrival.
				# Any additional arrivals banked in this same frame use the normal
				# multiplier after the event is consumed.
				Events.consume_one_shot()
				const_mult = _delivery_const_mult()
				if arrivals > 1:
					amt = (amt / float(arrivals)) + const_mult * delivery_factor * float(arrivals - 1)
			credits += amt; total_earned += amt; total_deliveries += arrivals
			delivered.emit(amt, 1 + int(v["route"]), arrivals)
		# cosmetic slow visual travel (see VISUAL_SPEED_FACTOR) — scales with sf
		# (speed upgrades still visibly speed drones up) but 20x slower than the
		# income logic above, so the fleet is followable instead of a blur
		var vrate := BASE_SPEED * sf * VISUAL_SPEED_FACTOR / d
		v["vt"] += vrate * float(v["vdir"]) * delta
		if v["vt"] >= 1.0:
			v["vt"] = 1.0; v["vdir"] = -1
		elif v["vt"] <= 0.0:
			v["vt"] = 0.0; v["vdir"] = 1
	_autosave_t += delta
	if _autosave_t >= AUTOSAVE_INTERVAL:
		_autosave_t = 0.0
		SaveSystem.save_game()

	# The manager may stay enabled as a player preference between realms, but it
	# only starts building after the local automation chapter has been earned.
	# Otherwise a veteran setting silently completes a fresh city's tutorial.
	if auto_manager_available():
		_auto_manager_t += delta
		if _auto_manager_t >= AUTO_MANAGER_INTERVAL:
			_auto_manager_t = 0.0
			_try_auto_buy()

## Every AUTO_MANAGER_INTERVAL, buy ONE unit (never bulk — stays incremental)
## of the affordable courier/upgrade with the best immediate income gain per
## credit. Silently does nothing while the manager is switched off.
func _try_auto_buy() -> void:
	var purchase := recommended_affordable_purchase()
	var best_kind := str(purchase.get("kind", ""))
	var best_cost := float(purchase.get("cost", INF))
	if best_kind == "":
		return
	if best_kind == "drone":
		credits -= best_cost; drones += 1
		_rebuild_drones()
		Achievements.note_drone_buy(1, drones)
	else:
		credits -= best_cost; levels[best_kind] = int(levels[best_kind]) + 1
	auto_bought.emit(best_kind)

# ---------------------------------------------------------------- drones
func drone_cost_multi(count: int) -> float:
	var rate := Economy.DRONE_RATE
	var first := Economy.drone_cost(drones) * cost_scale()
	return first * (pow(rate, float(count)) - 1.0) / (rate - 1.0) * max(0.5, 1.0 - 0.02 * float(talents["hangar"]))

func drone_max_affordable() -> int:
	var rate := Economy.DRONE_RATE
	var first := drone_cost()
	if credits < first:
		return 0
	return max(0, int(floor(log(1.0 + credits * (rate - 1.0) / first) / log(rate))))

func drone_planned() -> int:
	return max(1, drone_max_affordable()) if buy_mode == -1 else buy_mode

func buy_drones() -> int:
	var count := drone_planned()
	var cost := drone_cost_multi(count)
	if count < 1 or credits < cost:
		return 0
	credits -= cost; drones += count
	_rebuild_drones()
	Achievements.note_drone_buy(count, drones)
	return count

# ---------------------------------------------------------------- cities / country
func next_city_cost() -> float:
	if cities_unlocked >= max_cities():
		return -1.0
	return Economy.city_unlock_cost(current_country, cities_unlocked)

## Seconds until `cost` is affordable at the current income rate. -1.0 if
## already affordable (nothing to wait for) or if income is ~0 (would divide
## by ~zero / never happen) — callers should treat -1.0 as "no ETA to show".
func eta_seconds(cost: float) -> float:
	if cost <= credits:
		return -1.0
	var ips := income_per_sec()
	if ips <= 0.01:
		return -1.0
	return (cost - credits) / ips

func can_unlock_city() -> bool:
	var c := next_city_cost()
	return c >= 0.0 and credits >= c

func unlock_city() -> bool:
	if not can_unlock_city():
		return false
	var income_before := income_per_sec()
	credits -= next_city_cost()
	cities_unlocked += 1
	_rebuild_drones()
	last_city_income_gain = maxf(0.0, income_per_sec() - income_before)
	city_unlocked.emit(cities_unlocked)
	_check_regions()   # unlocking the final country's last city completes the last region
	return true

func all_cities_unlocked() -> bool:
	return cities_unlocked >= max_cities()

func expand_cost() -> float:
	if current_country >= Economy.num_countries() - 1:
		return -1.0
	return Economy.expand_cost(current_country)

func can_expand() -> bool:
	var c := expand_cost()
	return c >= 0.0 and all_cities_unlocked() and credits >= c

func expansion_influence_reward() -> int:
	return 4 + int((current_country + 1) / 3)

func expand_country() -> bool:
	if not can_expand():
		return false
	var influence_reward := expansion_influence_reward()
	# A realm is a complete local tycoon chapter. Starting the next one rebuilds
	# its city and fleet from the ground up while meta progress remains: influence,
	# talents, collection, prestige and permanent shop upgrades. Carrying the full
	# local economy forward let automated play skip half the world in 30 minutes
	# and made every newly revealed city look finished on arrival.
	credits = 0.0
	current_country += 1
	cities_unlocked = 1
	drones = Prestige.starting_drones()
	levels = Prestige.starting_levels()
	prosperity_rank = prosperity_rank_for_investment()
	buy_mode = 1
	combo = 0
	_combo_decay_t = 0.0
	# Bumped alongside the softer talent cost curve so a talent is actually
	# fundable within a normal run (talents reset on prestige).
	influence += influence_reward
	influence_total += influence_reward
	_rebuild_drones()
	country_changed.emit(current_country)
	_check_regions()   # expanding past a region's last country completes it
	SaveSystem.save_game()
	return true

func auto_manager_available() -> bool:
	return auto_manager and prosperity_rank >= 2

# ---------------------------------------------------------------- upgrades
func upgrade_cost_multi(key: String, count: int) -> float:
	if count <= 0:
		return 0.0
	var u: Dictionary = Economy.UPGRADES[key]
	var rate: float = u["rate"]
	var first: float = u["base"] * pow(rate, float(levels[key])) * cost_scale()
	return first * (pow(rate, float(count)) - 1.0) / (rate - 1.0)

func max_affordable(key: String) -> int:
	var u: Dictionary = Economy.UPGRADES[key]
	var rate: float = u["rate"]
	var first: float = u["base"] * pow(rate, float(levels[key])) * cost_scale()
	if credits < first:
		return 0
	return max(0, int(floor(log(1.0 + credits * (rate - 1.0) / first) / log(rate))))

func planned_count(key: String) -> int:
	return max(1, max_affordable(key)) if buy_mode == -1 else buy_mode

func buy_upgrade_multi(key: String) -> int:
	if not is_upgrade_unlocked(key):
		return 0
	var count := planned_count(key)
	if count < 1:
		return 0
	var cost := upgrade_cost_multi(key, count)
	if credits < cost:
		return 0
	credits -= cost; levels[key] = int(levels[key]) + count
	_check_prosperity()
	return count

func investment_total() -> int:
	var total := 0
	for level: int in levels.values():
		total += level
	return total

func prosperity_rank_for_investment() -> int:
	var rank := 0
	var invested := investment_total()
	for threshold: int in PROSPERITY_THRESHOLDS:
		if invested < threshold:
			break
		rank += 1
	return rank

func next_prosperity_threshold() -> int:
	if prosperity_rank >= PROSPERITY_THRESHOLDS.size():
		return -1
	return int(PROSPERITY_THRESHOLDS[prosperity_rank])

func prosperity_chapter_progress() -> float:
	var target := next_prosperity_threshold()
	if target < 0:
		return 1.0
	var chapter_start := 0 if prosperity_rank == 0 else int(PROSPERITY_THRESHOLDS[prosperity_rank - 1])
	return clampf(float(investment_total() - chapter_start) / float(target - chapter_start), 0.0, 1.0)

func next_prosperity_reward() -> Dictionary:
	if prosperity_rank >= PROSPERITY_THRESHOLDS.size():
		return {}
	return {
		"cash": income_per_sec() * float(PROSPERITY_CASH_SECONDS[prosperity_rank]),
		"gems": int(PROSPERITY_GEMS[prosperity_rank]),
	}

## Early upgrades now form four short city-growth chapters. Rewards are based
## on current income, so they accelerate the next decision without breaking the
## long economy or becoming worthless after a few minutes.
func _check_prosperity() -> void:
	var target := prosperity_rank_for_investment()
	while prosperity_rank < target:
		var reward_index := prosperity_rank
		prosperity_rank += 1
		var cash_reward := income_per_sec() * float(PROSPERITY_CASH_SECONDS[reward_index])
		var gem_reward := int(PROSPERITY_GEMS[reward_index])
		credits += cash_reward
		gems += gem_reward
		prosperity_advanced.emit(prosperity_rank, cash_reward, gem_reward)

# ---------------------------------------------------------------- talents
func talent_cost(key: String) -> int:
	return Economy.talent_cost(int(talents[key]))

func can_buy_talent(key: String) -> bool:
	return int(talents[key]) < int(Economy.TALENTS[key]["max"]) and influence >= talent_cost(key)

func buy_talent(key: String) -> bool:
	if not can_buy_talent(key):
		return false
	influence -= talent_cost(key); talents[key] = int(talents[key]) + 1
	return true

# ---------------------------------------------------------------- gem shop
func gem_boost_cost() -> int:
	return Economy.gem_boost_cost(gem_boost)

func buy_gem_boost() -> bool:
	var c := gem_boost_cost()
	if gems < c:
		return false
	gems -= c; gem_boost += 1
	Achievements.note_gem_boost(gem_boost)
	Achievements.note_gems_spent(c)
	return true

func buy_gem_cash(cost: int, seconds: float) -> bool:
	if gems < cost:
		return false
	gems -= cost
	Achievements.note_gems_spent(cost)
	credits += income_per_sec() * seconds
	return true

func buy_gem_drones(cost: int, n: int) -> bool:
	if gems < cost:
		return false
	gems -= cost; drones += n
	_rebuild_drones()
	Achievements.note_drone_buy(n, drones)
	Achievements.note_gems_spent(cost)
	return true

func buy_gem_combo_time(cost: int) -> bool:
	if combo_window_bonus > 0.0:
		return false
	if gems < cost:
		return false
	gems -= cost; combo_window_bonus = COMBO_DECAY
	Achievements.note_gems_spent(cost)
	return true

# ---------------------------------------------------------------- skins
func has_skin(id: String) -> bool:
	return id in skins_owned

func buy_skin(id: String) -> bool:
	if not Economy.SKINS.has(id) or has_skin(id):
		return false
	var c := int(Economy.SKINS[id]["cost"])
	if gems < c:
		return false
	gems -= c
	skins_owned.append(id)
	skin_active = id
	Achievements.note_gems_spent(c)
	SaveSystem.save_game()
	return true

func set_skin(id: String) -> bool:
	if not has_skin(id):
		return false
	skin_active = id
	return true

# ---------------------------------------------------------------- boosts/offline
func boost_earn_2x(duration := EARN_BOOST_DURATION) -> void:
	earn_boost_timer = maxf(earn_boost_timer, maxf(0.0, duration))

func grant_gems(n: int) -> void:
	gems += n

func grant_cash_minutes(minutes: float) -> void:
	credits += income_per_sec() * minutes * 60.0

func collect_offline(multiplier: float) -> float:
	var amount := pending_offline * multiplier
	credits += amount
	pending_offline = 0.0; pending_offline_seconds = 0.0
	Achievements.note_offline(amount)
	return amount

## Full reset ("Reset Progress" in Settings). from_dict({}) already resolves
## every field to its declared default via d.get(key, default) — reuse it
## instead of duplicating the defaults a second time.
func reset() -> void:
	from_dict({})

# ---------------------------------------------------------------- persistence
func to_dict() -> Dictionary:
	return {
		"credits": credits, "gems": gems, "influence": influence, "influence_total": influence_total,
		"current_country": current_country, "cities_unlocked": cities_unlocked, "drones": drones,
		"levels": levels.duplicate(), "talents": talents.duplicate(), "gem_boost": gem_boost,
		"earn_boost_timer": earn_boost_timer, "total_earned": total_earned, "total_deliveries": total_deliveries,
		"combo_window_bonus": combo_window_bonus,
		"skins_owned": skins_owned.duplicate(), "skin_active": skin_active,
		"guild_blessing_until": guild_blessing_until, "auto_manager": auto_manager,
		"prosperity_rank": prosperity_rank,
		"regions_done": regions_done.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	credits = maxf(0.0, float(d.get("credits", 0.0)))
	if not is_finite(credits): credits = 0.0
	gems = clampi(int(d.get("gems", 0)), 0, 999_999_999)
	influence = maxi(0, int(d.get("influence", 0)))
	influence_total = maxi(influence, int(d.get("influence_total", influence)))
	current_country = clampi(int(d.get("current_country", 0)), 0, Economy.num_countries() - 1)
	cities_unlocked = clampi(int(d.get("cities_unlocked", 1)), 1, max_cities())
	last_city_income_gain = 0.0
	drones = clampi(int(d.get("drones", 1)), 1, 1_000_000_000)
	var lv := {"speed": 0, "cargo": 0, "value": 0, "routes": 0}
	var slv: Dictionary = d.get("levels", {})
	for k in lv:
		# 1000 is far beyond reachable play but still numerically safe for the
		# milestone bit shift and exponential cost curves. The former 1,000,000
		# cap could turn a legacy/plain save into INF or an invalid huge shift.
		if slv.has(k): lv[k] = clampi(int(slv[k]), 0, 1000)
	levels = lv
	var derived_prosperity := prosperity_rank_for_investment()
	prosperity_rank = clampi(int(d.get("prosperity_rank", derived_prosperity)), derived_prosperity, PROSPERITY_THRESHOLDS.size())
	var tl := {"global": 0, "speed": 0, "value": 0, "hangar": 0}
	var stl: Dictionary = d.get("talents", {})
	for k in tl:
		if stl.has(k): tl[k] = clampi(int(stl[k]), 0, int(Economy.TALENTS[k]["max"]))
	talents = tl
	gem_boost = clampi(int(d.get("gem_boost", 0)), 0, 30)
	earn_boost_timer = maxf(0.0, float(d.get("earn_boost_timer", 0.0)))
	if not is_finite(earn_boost_timer): earn_boost_timer = 0.0
	total_earned = maxf(0.0, float(d.get("total_earned", 0.0)))
	if not is_finite(total_earned): total_earned = 0.0
	total_deliveries = maxi(0, int(d.get("total_deliveries", 0)))
	combo_window_bonus = clampf(float(d.get("combo_window_bonus", 0.0)), 0.0, 10.0)
	# v2 compatibility: old saves called the earned blessing a temporary VIP.
	guild_blessing_until = maxi(0, int(d.get("guild_blessing_until", d.get("vip_temp_until", 0))))
	auto_manager = bool(d.get("auto_manager", false))
	regions_done = []
	for r in Array(d.get("regions_done", [])):
		var ri := int(r)
		if ri >= 0 and ri < Economy.REGIONS.size() and ri not in regions_done:
			regions_done.append(ri)
	skins_owned = ["classic"]
	for s in Array(d.get("skins_owned", [])):
		var sid: String = str(s)
		if Economy.SKINS.has(sid) and sid not in skins_owned:
			skins_owned.append(sid)
	skin_active = str(d.get("skin_active", "classic"))
	if not has_skin(skin_active):
		skin_active = "classic"
	_rebuild_drones()
