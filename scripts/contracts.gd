extends Node
## Contracts — Missões: time-limited delivery goals that reward credits and gems.
## Autoload: Contracts. Registered after SaveSystem in project.godot.

signal completed(slot: int)
signal refreshed(slot: int)

const SLOT_COUNT := 4
const EXPIRE_DELAY := 20.0  # seconds before a new contract spawns after claiming

var slots: Array = []
var _refresh_timers: Array = [0.0, 0.0, 0.0, 0.0]
var _frame := 0
var _now_cache := 0   # unix seconds, refreshed ~4x/sec in _process (not per frame)
var claim_streak := 0   # consecutive claims (resets if a contract expires unclaimed) → credit chain bonus

func _ready() -> void:
	_ensure_slots()
	GameState.delivered.connect(_on_delivered)

func _process(delta: float) -> void:
	_frame += 1
	# Wall-clock syscall every frame for a value only compared against
	# second-granularity deadlines. Refresh it ~4x/sec; a deadline can't be missed
	# by a quarter-second window it's already checked against in whole seconds.
	if _frame % 15 == 0 or _now_cache == 0:
		_now_cache = int(Time.get_unix_time_from_system())
	var now := _now_cache
	for i in range(SLOT_COUNT):
		if i >= slots.size():
			break
		var s: Dictionary = slots[i]
		if s.get("claimed", false):
			_refresh_timers[i] -= delta
			if _refresh_timers[i] <= 0.0:
				_replace(i)
		elif now >= int(s.get("deadline", 0)):
			claim_streak = 0   # letting a contract expire breaks the claim chain
			_replace(i)
		elif str(s.get("type", "")) == "combo":
			# only write when combo actually grew — was writing to the slot
			# Dictionary + comparing floats every single frame (60/sec) for
			# the mission's full lifetime (up to 1800s), even while combo sits
			# at 0 between delivery bursts, unlike the throttled "drones" case
			if GameState.combo > int(s.get("progress", 0.0)):
				slots[i]["progress"] = float(GameState.combo)
				if float(slots[i]["progress"]) >= float(s.get("target", 1.0)):
					slots[i]["ready"] = true
		elif _frame % 60 == 0 and str(s.get("type", "")) == "drones":
			slots[i]["progress"] = float(GameState.drones)
			if float(slots[i]["progress"]) >= float(s.get("target", 1.0)):
				slots[i]["ready"] = true

func _on_delivered(_amount: float, _city: int, count: int) -> void:
	var now := int(Time.get_unix_time_from_system())
	for i in range(slots.size()):
		var s: Dictionary = slots[i]
		if s.get("claimed", false) or s.get("ready", false):
			continue
		if now >= int(s.get("deadline", 0)):
			continue
		match str(s.get("type", "")):
			"deliveries":
				# `count`, not 1 — one emission can bank several arrivals
				slots[i]["progress"] = float(s.get("progress", 0.0)) + float(count)
				if slots[i]["progress"] >= float(s.get("target", 1.0)):
					slots[i]["ready"] = true
			"earn":
				var base: float = float(s.get("earn_base", 0.0))
				slots[i]["progress"] = maxf(0.0, GameState.total_earned - base)
				if slots[i]["progress"] >= float(s.get("target", 1.0)):
					slots[i]["ready"] = true

func claim(i: int, mult := 1.0) -> bool:
	if i < 0 or i >= slots.size():
		return false
	var s: Dictionary = slots[i]
	if not s.get("ready", false) or s.get("claimed", false):
		return false
	slots[i]["claimed"] = true
	_refresh_timers[i] = EXPIRE_DELAY
	claim_streak += 1
	# credit chain bonus for claiming consecutively without letting one expire
	# (credits only, capped +50% — rewards sustained active play, no gem faucet)
	var chain: float = 1.0 + 0.05 * float(mini(claim_streak, 10))
	var rc: float = float(s.get("reward_credits", 0.0)) * mult * chain
	GameState.credits += rc
	GameState.total_earned += rc
	var rg: int = int(float(s.get("reward_gems", 0)) * mult)
	if rg > 0:
		GameState.gems += rg
	completed.emit(i)
	return true

## Replace a non-weekly contract with a fresh one (one free reroll).
func reroll(i: int) -> bool:
	if i < 0 or i >= 3 or i >= slots.size():
		return false
	_replace(i)
	return true

func progress_pct(i: int) -> float:
	if i >= slots.size():
		return 0.0
	var s: Dictionary = slots[i]
	return clampf(float(s.get("progress", 0.0)) / maxf(1.0, float(s.get("target", 1.0))), 0.0, 1.0)

func time_remaining(i: int) -> float:
	if i >= slots.size():
		return 0.0
	var s: Dictionary = slots[i]
	if s.get("claimed", false):
		return maxf(0.0, _refresh_timers[i])
	return maxf(0.0, float(s.get("deadline", 0)) - float(Time.get_unix_time_from_system()))

func _replace(i: int) -> void:
	slots[i] = _gen(i)
	_refresh_timers[i] = 0.0
	refreshed.emit(i)

func _ensure_slots() -> void:
	while slots.size() < SLOT_COUNT:
		slots.append(_gen(slots.size()))

## Rebuilds a slot's display label from its stored type/target/weekly data at
## DISPLAY TIME rather than generation time. _gen() used to bake a translated
## string once when the contract was rolled, so a mission generated in
## Portuguese stayed in Portuguese even after switching the language toggle —
## unlike every other piece of UI text, which Godot's engine auto-retranslates.
func format_label(s: Dictionary) -> String:
	var target: float = float(s.get("target", 0.0))
	if bool(s.get("weekly", false)):
		return "Wochenauftrag: %d Waren liefern" % int(target)
	match str(s.get("type", "")):
		"deliveries": return "%d Warenlieferungen abschließen" % int(target)
		"earn":       return "%s Gold verdienen" % Fmt.short(target)
		"drones":     return "%d Greifenkuriere befehligen" % int(target)
		"combo":      return "Handelsserie von %d erreichen" % int(target)
	return ""

func _gen(slot_idx: int) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var ips := maxf(GameState.income_per_sec(), 0.5)
	var d_count := maxi(GameState.drones, 1)

	if slot_idx == 3:
		var wk_target := maxf(500.0, float(d_count) * 200.0)
		return {
			"type": "deliveries", "weekly": true,
			"target": wk_target, "progress": 0.0, "earn_base": 0.0,
			"deadline": now + 604800, "duration": 604800,
			"reward_credits": ips * 7200.0,
			"reward_gems": maxi(5, 5 + Prestige.count * 2),
			"claimed": false, "ready": false,
		}

	var diff := 1.0 + float(slot_idx) * 1.8

	var types := ["deliveries", "earn", "earn", "deliveries"]
	if d_count > 10:
		types.append("drones")
	if d_count > 5:
		types.append("combo")
	var t: String = types[randi() % types.size()]

	var target := 1.0
	var dur := 600.0
	var reward_credits := 0.0
	var reward_gems := 0
	var earn_base := 0.0

	match t:
		"deliveries":
			target = maxf(30.0, float(d_count) * 8.0 * diff)
			dur = maxf(300.0, target * 3.0)
			reward_credits = ips * minf(dur, 600.0) * 0.4 * diff
			reward_gems = 1 if slot_idx >= 2 else 0
		"earn":
			target = ips * 120.0 * diff
			dur = maxf(600.0, 240.0 * diff)
			reward_credits = target * 0.35 * diff
			reward_gems = 1 if slot_idx >= 2 else 0
			earn_base = GameState.total_earned
		"drones":
			var need := int(float(d_count) * (1.3 + 0.2 * float(slot_idx)))
			target = float(maxi(need, d_count + 5))
			dur = 3600.0
			reward_credits = ips * 180.0 * diff
			reward_gems = 1
		"combo":
			target = float(15 + slot_idx * 15)
			dur = 1800.0
			reward_credits = ips * 240.0 * diff
			reward_gems = 1 if slot_idx >= 2 else 0
		_:
			t = "earn"
			target = 1000.0
			dur = 300.0
			reward_credits = 400.0

	dur = minf(dur, 5400.0)
	return {
		"type": t, "target": target, "progress": 0.0,
		"earn_base": earn_base, "deadline": now + int(dur), "duration": int(dur),
		"reward_credits": reward_credits, "reward_gems": reward_gems,
		"claimed": false, "ready": false,
	}

func to_dict() -> Dictionary:
	return {"slots": slots.duplicate(true), "timers": _refresh_timers.duplicate()}

func from_dict(d: Dictionary) -> void:
	var sv: Variant = d.get("slots", [])
	slots.clear()
	if sv is Array:
		for item in sv:
			if item is Dictionary:
				slots.append(item)
	var tv: Variant = d.get("timers", [])
	if tv is Array:
		for i in range(mini(SLOT_COUNT, tv.size())):
			_refresh_timers[i] = float(tv[i])
	_ensure_slots()
