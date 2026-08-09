extends Node
## Prestige system (autoload: Prestige). Soft reset with permanent compounding bonuses.
## Requires country >= 4 (5th country). Each prestige earns Prestige Gems (pgems).

signal prestiged(count: int)

const MIN_COUNTRY := 4
const TIER_NAMES := ["Bronze", "Silber", "Gold", "Platin", "Diamant", "Legendär"]

# Persisted
var count := 0
var pgems := 0
var total_pgems := 0
var permanent_mult := 1.0
var shop_owned: Array = []   # list of owned shop item ids
var ascendant_level := 0     # repeatable pgems sink (see ascendant_cost/effective_mult)
var run_start_earned := 0.0  # GameState.total_earned at the last prestige — how far THIS run went drives the pgem gain

const SHOP := {
    "speed_5":     {"name": "Windrunen-Start",       "cost": 5,  "desc": "Beginne immer mit Reisetempo Stufe 5."},
    "cargo_5":     {"name": "Erweiterte Satteltaschen","cost": 5, "desc": "Beginne immer mit Warenkapazität Stufe 5."},
    "value_5":     {"name": "Königlicher Vertrag",   "cost": 5,  "desc": "Beginne immer mit Handelswert Stufe 5."},
    "offline_10":  {"name": "Nachtverwalter",        "cost": 8,  "desc": "+10% dauerhafte Offline-Effizienz."},
    "offline_20":  {"name": "Mondschicht",           "cost": 15, "desc": "+20% dauerhafte Offline-Effizienz."},
    "drones_10":   {"name": "Geerbte Greifenschar",  "cost": 10, "desc": "Beginne immer mit 10 zusätzlichen Kurieren."},
    "drones_25":   {"name": "Königliche Greifengarde","cost": 20,"desc": "Beginne immer mit 25 zusätzlichen Kurieren."},
    "guild_24h":   {"name": "Gildensegen",           "cost": 35, "desc": "Aktiviert 24 Stunden Gildensegen nach jedem Vermächtnis."},
    "start_c2":    {"name": "Fernhandelsrecht",      "cost": 55, "desc": "Beginne nach einem Vermächtnis im zweiten Reich."},
}
const SHOP_ORDER := ["speed_5", "cargo_5", "value_5", "offline_10", "offline_20", "drones_10", "drones_25", "guild_24h", "start_c2"]

## pgem gain now scales with how far THIS run pushed (log of credits earned since
## the last prestige), not just country index — so grinding several more
## countries before resetting is genuinely worth it (the "one more country"
## pull), instead of the old optimum of always prestiging at MIN_COUNTRY.
## Pure pgem faucet (never touches credit costs → cannot inflate the economy).
func run_bonus() -> int:
    if not has_node("/root/GameState"): return 0
    var run: float = GameState.total_earned - run_start_earned
    if run < 1.0: return 0
    return int(floor(log(run) / log(28.0)))   # ~+4 at 1M, ~+6 at 1B, ~+8 at 1T

func pgems_on_next_prestige() -> int:
    var country: int = GameState.current_country if has_node("/root/GameState") else 0
    return max(3, 5 + count * 3 + country + run_bonus())

func can_prestige() -> bool:
    if not has_node("/root/GameState"): return false
    return GameState.current_country >= MIN_COUNTRY

func tier_name() -> String:
    # tr() here (not at each call site) since TIER_NAMES words get embedded
    # via %s into other format strings, where Godot's autotranslate-on-.text
    # assignment never sees them individually.
    return tr(TIER_NAMES[mini(count, TIER_NAMES.size() - 1)])

func extra_offline_pct() -> float:
    var bonus := 0.0
    if "offline_10" in shop_owned: bonus += 0.10
    if "offline_20" in shop_owned: bonus += 0.20
    return bonus

func starting_drones() -> int:
    var base := 1 + count * 2
    if "drones_10" in shop_owned: base += 10
    if "drones_25" in shop_owned: base += 25
    return mini(base, 50)

func starting_country() -> int:
    return 1 if "start_c2" in shop_owned else 0

func starting_levels() -> Dictionary:
    return {
        "speed": 5 if "speed_5" in shop_owned else 0,
        "cargo": 5 if "cargo_5" in shop_owned else 0,
        "value": 5 if "value_5" in shop_owned else 0,
        "routes": 0,
    }

func do_prestige() -> bool:
    if not can_prestige(): return false
    var pg := pgems_on_next_prestige()
    pgems += pg; total_pgems += pg
    count += 1
    permanent_mult = pow(1.15, float(count))
    run_start_earned = GameState.total_earned   # next run's depth is measured from here
    _soft_reset()
    if has_node("/root/Achievements"): Achievements.note_prestige(count)
    if has_node("/root/Audio"): Audio.play("prestige")
    prestiged.emit(count)
    SaveSystem.save_game()
    return true

func _soft_reset() -> void:
    if not has_node("/root/GameState"): return
    var gs := GameState
    gs.credits = 0.0
    # Collection gems carry over unchanged and are earned entirely through play.
    gs.influence = 0
    gs.current_country = starting_country()
    gs.cities_unlocked = 1
    gs.drones = starting_drones()
    gs.levels = starting_levels()
    gs.talents = {"global": 0, "speed": 0, "value": 0, "hangar": 0}
    gs.gem_boost = 0
    gs.earn_boost_timer = 0.0
    # Apply time-limited shop starting bonuses
    if "guild_24h" in shop_owned:
        gs.guild_blessing_until = int(Time.get_unix_time_from_system()) + 86400
    gs._rebuild_drones()

func buy_shop(id: String) -> bool:
    if not SHOP.has(id): return false
    if id in shop_owned: return false
    var cost: int = int(SHOP[id]["cost"])
    if pgems < cost: return false
    pgems -= cost
    shop_owned.append(id)
    SaveSystem.save_game()
    return true

func has_shop(id: String) -> bool:
    return id in shop_owned

## Repeatable pgems sink (the fixed 9-item shop above is all one-time
## unlocks, so a long-lived player eventually has nothing left to spend
## pgems on). Each level is +1% stacking on top of the prestige-count
## multiplier — see effective_mult(), which GameState.global_mult() reads
## instead of `permanent_mult` directly.
func ascendant_cost() -> int:
    return 10 + ascendant_level * 6

func buy_ascendant() -> bool:
    var cost := ascendant_cost()
    if pgems < cost: return false
    pgems -= cost
    ascendant_level += 1
    if has_node("/root/Achievements"): Achievements.note_ascendant(ascendant_level)
    SaveSystem.save_game()
    return true

func effective_mult() -> float:
    return permanent_mult * (1.0 + 0.01 * float(ascendant_level))

## Full reset ("Reset Progress" in Settings) — Prestige tier/shop wiped.
func reset() -> void:
    count = 0
    pgems = 0
    total_pgems = 0
    permanent_mult = 1.0
    shop_owned = []
    ascendant_level = 0
    run_start_earned = 0.0

func to_dict() -> Dictionary:
    return {
        "count": count, "pgems": pgems, "total": total_pgems,
        "mult": permanent_mult, "shop": shop_owned.duplicate(),
        "ascendant": ascendant_level, "run_start": run_start_earned,
    }

func from_dict(d: Dictionary) -> void:
    # Legacy v1 dictionaries had no authenticated envelope. Treat every field as
    # hostile input so extreme values cannot create INF multipliers or invalid UI.
    count = clampi(int(d.get("count", 0)), 0, 1000)
    pgems = clampi(int(d.get("pgems", 0)), 0, 1_000_000_000)
    total_pgems = clampi(int(d.get("total", 0)), pgems, 1_000_000_000)
    permanent_mult = pow(1.15, float(count))
    shop_owned = []
    for raw_id in Array(d.get("shop", [])):
        var item_id := str(raw_id)
        if (SHOP.has(item_id) or item_id == "vip_24h") and item_id not in shop_owned:
            shop_owned.append(item_id)
    # v2 migration from the former monetization-themed identifier.
    if "vip_24h" in shop_owned:
        shop_owned.erase("vip_24h")
        if "guild_24h" not in shop_owned:
            shop_owned.append("guild_24h")
    ascendant_level = clampi(int(d.get("ascendant", 0)), 0, 100_000)
    run_start_earned = maxf(0.0, float(d.get("run_start", 0.0)))
    if not is_finite(run_start_earned): run_start_earned = 0.0
