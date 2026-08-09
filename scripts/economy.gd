extends Node
## Economy data & formulas (autoload: Economy). The source file supplies only
## progression counts and tiers; names, silhouettes and settlements are rebuilt
## as an original fantasy world at runtime.

var WORLD: Array = []

const FANTASY_REALMS := [
	"Goldhain", "Dämmermark", "Runenküste", "Silberwald", "Emberfels",
	"Mondtal", "Kristallweide", "Nebelmoor", "Sonnenwacht", "Frostkrone",
	"Smaragdlande", "Dornenreich", "Sternenfall", "Aschensteppe", "Greifenmark",
	"Perlenküste", "Drachengrat", "Azurhain", "Eisenbund", "Himmelsaue",
	"Orakelreich", "Glutwüste", "Titanenpfad", "Jadekaiserreich", "Lotusmark",
	"Gewitterinseln", "Korallenthron", "Schattenhain", "Lichtbastion", "Arkanum",
	"Wolkenmeer", "Phönixreich", "Nordlicht", "Weltenrand", "Königslande",
	"Freihafen", "Sonnenimperium", "Ewige Wildnis", "Hochreich", "Aetheria"
]
const GOLDHAIN_CITIES := ["Königsbasar", "Runenhafen", "Dämmerfels", "Goldfurt", "Mondbrück", "Greifenwacht", "Smaragdhain"]
const FANTASY_CITY_ROOTS := [
	"Auren", "Brann", "Cael", "Dämmer", "Eldra", "Falken", "Glimmer", "Helia",
	"Isen", "Jade", "Keld", "Lun", "Morgen", "Nebel", "Onyx", "Pyra",
	"Quarz", "Raben", "Saphir", "Thorn", "Umbra", "Valen", "Wind", "Xanth",
	"Ylva", "Zora", "Arken", "Briar", "Cyr", "Draken", "Erynd", "Fiora",
	"Greifen", "Hohen", "Ilyr", "Kron", "Lyra", "Myr", "Nyx", "Orin",
]
const FANTASY_CITY_SUFFIXES := ["krone", "hafen", "wacht", "furt", "hain", "tor", "markt"]
const FANTASY_CITY_SLOTS := [
	Vector2(0.50, 0.50), Vector2(0.30, 0.29), Vector2(0.70, 0.31),
	Vector2(0.24, 0.56), Vector2(0.76, 0.57), Vector2(0.36, 0.76),
	Vector2(0.65, 0.75),
]

const UPGRADES := {
	# Deliberately WEAK gains (player asked: upgrades less powerful), steep cost.
	"speed":  {"name": "Reisetempo",       "base": 80.0,  "rate": 1.26, "icon": "ic_speed"},
	"cargo":  {"name": "Warenkapazität",   "base": 110.0, "rate": 1.28, "icon": "ic_cargo"},
	"value":  {"name": "Handelswert",       "base": 150.0, "rate": 1.30, "icon": "ic_value"},
	"routes": {"name": "Handelsrouten",     "base": 200.0, "rate": 1.32, "icon": "ic_range"},
}
const UPGRADE_ORDER := ["speed", "cargo", "value", "routes"]

const TALENTS := {
	# Maxes + cost curve tuned so a fully-committed single prestige cycle can
	# realistically max at least one talent (talents reset on prestige, unlike
	# the Prestige Shop). Previous 1.7^level with maxes 100/60/60/25 was
	# mathematically unreachable given typical influence income.
	"global":  {"name": "Große Handelsgilde", "desc": "+6% Gesamtertrag", "max": 25, "icon": "ic_prestige"},
	"speed":   {"name": "Windrunen", "desc": "+4% Reisetempo", "max": 20, "icon": "ic_speed"},
	"value":   {"name": "Königliche Verträge", "desc": "+4% Handelswert", "max": 20, "icon": "ic_value"},
	"hangar":  {"name": "Karawanserei", "desc": "-2% Kurierkosten", "max": 10, "icon": "ic_drone"},
}
const TALENT_ORDER := ["global", "speed", "value", "hangar"]

const GEM_SHOP_ORDER := ["boost", "cash", "warp", "warp24", "drone_pack", "combo_time"]
const GEM_SHOP := {
	"boost":      {"name": "Núcleo de Lucro", "desc": "+25% lucros GLOBAIS, para sempre.", "icon": "ic_prestige"},
	"cash":       {"name": "Injeção de Créditos", "desc": "Ganha já 1 hora de lucros.", "cost": 30, "icon": "ic_credits"},
	"warp":       {"name": "Salto Temporal 8h", "desc": "Ganha já 8 horas de lucros.", "cost": 80, "icon": "ic_boost"},
	"warp24":     {"name": "Salto Temporal 24h", "desc": "Ganha já 24 horas de lucros.", "cost": 180, "icon": "ic_boost"},
	"drone_pack": {"name": "Esquadrão Instantâneo", "desc": "+10 drones imediatamente, sem custo em créditos.", "cost": 90, "icon": "ic_drone"},
	"combo_time": {"name": "Combo Duradouro", "desc": "O combo demora o DOBRO do tempo a expirar. Permanente.", "cost": 150, "icon": "ic_speed"},
}

## Upgrade milestones: every MILESTONE_STEP levels an upgrade's effect DOUBLES.
## Gives every upgrade a visible next goal (idle-genre staple).
const MILESTONE_STEP := 25

## `level / MILESTONE_STEP` is integer division, so this is always 2^(small int).
## The shift is bit-identical to pow() here (IEEE-754 represents 2^n exactly for
## integer n) and skips a libm call made ~4x per _delivery_const_mult() pass.
func milestone_mult(level: int) -> float:
	return float(1 << (level / MILESTONE_STEP))

## Drone skins — permanent cosmetics bought with gems, visible on the map.
## Each owned premium skin also adds +2% global profits (collection bonus).
const SKIN_ORDER := ["classic", "solar", "neon", "stealth", "aurora"]
const SKINS := {
	"classic": {"name": "Frota Clássica", "desc": "O visual original da frota.", "cost": 0,
		"body": Color(1.0, 1.0, 1.0), "trail": Color(0.227, 0.839, 0.941)},
	"solar":   {"name": "Frota Solar", "desc": "Dourado radiante com rasto âmbar.", "cost": 150,
		"body": Color(1.0, 0.84, 0.45), "trail": Color(1.0, 0.784, 0.220)},
	"neon":    {"name": "Frota Néon", "desc": "Rosa elétrico com rasto magenta.", "cost": 250,
		"body": Color(1.0, 0.55, 0.85), "trail": Color(1.0, 0.35, 0.75)},
	"stealth": {"name": "Frota Sombra", "desc": "Fuselagem escura com rasto vermelho.", "cost": 400,
		"body": Color(0.45, 0.50, 0.62), "trail": Color(1.0, 0.30, 0.28)},
	"aurora":  {"name": "Frota Aurora", "desc": "Verde-ciano boreal. A elite do céu.", "cost": 600,
		"body": Color(0.55, 1.0, 0.85), "trail": Color(0.25, 0.95, 0.60)},
}

func _ready() -> void:
	var f := FileAccess.open("res://data/world.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if typeof(d) == TYPE_DICTIONARY and d.has("countries"):
			WORLD = d["countries"]
		f.close()
	if WORLD.is_empty():
		WORLD = [{"name": "Goldhain", "tier": 0, "outline": [], "cities": [{"name":"Königsbasar","x":0.5,"y":0.5,"capital":true},{"name":"Runenhafen","x":0.65,"y":0.4,"capital":false}]}]
	_apply_fantasy_world_names()

func _apply_fantasy_world_names() -> void:
	for i in range(mini(WORLD.size(), FANTASY_REALMS.size())):
		var realm_name: String = FANTASY_REALMS[i]
		WORLD[i]["name"] = realm_name
		WORLD[i]["outline"] = _fantasy_outline(i)
		var cities: Array = WORLD[i]["cities"]
		for city_idx in range(cities.size()):
			if i == 0 and city_idx < GOLDHAIN_CITIES.size():
				cities[city_idx]["name"] = GOLDHAIN_CITIES[city_idx]
			else:
				var suffix: String = FANTASY_CITY_SUFFIXES[city_idx % FANTASY_CITY_SUFFIXES.size()]
				# Pair a rotating root with the role suffix. Every realm gets a
				# recognisable set of proper place names instead of seven repetitive
				# "Realm-Hafen / Realm-Hain" debug-style labels.
				var root_idx := (i * 7 + city_idx * 11) % FANTASY_CITY_ROOTS.size()
				cities[city_idx]["name"] = FANTASY_CITY_ROOTS[root_idx] + suffix
			# Wide, authored slots keep hubs readable on a phone instead of piling
			# every name and building on top of the capital.
			var slot: Vector2 = FANTASY_CITY_SLOTS[city_idx % FANTASY_CITY_SLOTS.size()]
			if i % 2 == 1:
				slot.x = 1.0 - slot.x
			cities[city_idx]["x"] = slot.x
			cities[city_idx]["y"] = slot.y

## Generates a distinct heraldic/island silhouette for each realm. The warped
## radial construction is intentionally non-geographic: no real country border
## survives loading, while the stable formula keeps saves and screenshots exact.
func _fantasy_outline(realm_index: int) -> Array:
	var outline: Array = []
	var points := 18
	var phase := float(realm_index) * 1.618033
	var x_scale := 0.39 + 0.025 * sin(phase * 1.7)
	var y_scale := 0.37 + 0.025 * cos(phase * 1.3)
	for point_index in range(points):
		var angle := TAU * float(point_index) / float(points)
		var rune_wave := sin(angle * 3.0 + phase) * 0.14
		var ridge_wave := cos(angle * 5.0 - phase * 0.7) * 0.08
		var radius := 1.0 + rune_wave + ridge_wave
		outline.append([
			clampf(0.5 + cos(angle) * x_scale * radius, 0.08, 0.92),
			clampf(0.5 + sin(angle) * y_scale * radius, 0.08, 0.92),
		])
	return outline

func num_countries() -> int:
	return WORLD.size()

## The 40 realms form seven fantasy chapters. Completing every realm in a
## chapter grants a ONE-TIME permanent global bonus (see
## GameState.region_bonus_mult) — turns the 40-realm climb into 7 meaningful
## milestones and the final realm into a real campaign-finale payoff
## instead of a dead-end "Parabéns!" wall. `to` is the last country index of the
## region; `from` is the previous region's `to`+1. Bonuses are additive and
## back-loaded (deep regions require many prestiges to reach), so the tuned
## early-run economy is barely touched — validated with tests/sim.gd.
const REGIONS := [
	{"name_key": "Die Goldenen Marken", "to": 9,  "bonus": 0.04},
	{"name_key": "Die Nebelkronen",      "to": 19, "bonus": 0.06},
	{"name_key": "Die Runenpfade",       "to": 22, "bonus": 0.08},
	{"name_key": "Die Glutlande",        "to": 26, "bonus": 0.12},
	{"name_key": "Die Sternentore",      "to": 28, "bonus": 0.16},
	{"name_key": "Das Wolkenmeer",       "to": 33, "bonus": 0.24},
	{"name_key": "Der Aetherthron",      "to": 39, "bonus": 0.40},
]

## Region index that country `ci` belongs to (0..REGIONS.size()-1).
func region_of(ci: int) -> int:
	for r in range(REGIONS.size()):
		if ci <= int(REGIONS[r]["to"]):
			return r
	return REGIONS.size() - 1

func region_from(r: int) -> int:
	return 0 if r <= 0 else int(REGIONS[r - 1]["to"]) + 1

func country(i: int) -> Dictionary:
	return WORLD[clampi(i, 0, WORLD.size() - 1)]

func country_name(i: int) -> String:
	return country(i)["name"]

func country_cities(i: int) -> Array:
	return country(i)["cities"]

func country_outline(i: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	for p in country(i)["outline"]:
		arr.append(Vector2(p[0], p[1]))
	return arr

const DRONE_RATE := 1.175

## Per-country payout scale (delivery value grows ~2.2x per country).
func pay_tier(i: int) -> float:
	return pow(2.2, float(i))

## Per-country COST scale — grows MUCH faster than payouts (pay_tier 2.2^i) so
## every country needs a substantially bigger fleet than the last (escalating,
## long progression; you cannot rush to the Aetherthron — it takes many hours).
## v1.17.0: steepened 4.6→6.5 because leaving Goldhain carried a huge
## fleet + higher pay_tier that made the next country's cities trivially cheap.
## Goldhain (i=0 → 6.5^0 = 1) is UNAFFECTED; only later-realm costs rise,
## widening the gap versus income so active upgrades remain meaningful.
func cost_tier(i: int) -> float:
	return pow(6.5, float(i))

func upgrade_cost(key: String, level: int) -> float:
	var u: Dictionary = UPGRADES[key]
	return u["base"] * pow(u["rate"], float(level))

func drone_cost(count: int) -> float:
	return 20.0 * pow(DRONE_RATE, float(max(0, count - 1)))

## Cost to unlock the n-th delivery city in a country (n = number already active).
## v1.17.0: per-city growth 2.8→3.15 and base 1500→2600 so cities keep pace with
## the carried-over fleet; combined with the steeper cost_tier, opening cities in
## a new realm is a real gold sink and a meaningful progression milestone
## instead of being auto-affordable the moment you arrive.
func city_unlock_cost(country_idx: int, n: int) -> float:
	return 2600.0 * pow(3.15, float(n)) * cost_tier(country_idx)

## Cost to expand to the next country (available once all cities are unlocked).
## Always 5x the priciest city of this country so jumping country is a real
## milestone you must save up for — NOT the giveaway it was when it was a flat
## 80k * cost_tier that undercut the last city's cost. Scales per country for
## free because city_unlock_cost already folds in cost_tier(country_idx).
func expand_cost(country_idx: int) -> float:
	var count := country_cities(country_idx).size()
	var last_n := maxi(1, count - 2)   # n of the last (most expensive) city unlock
	return 5.0 * city_unlock_cost(country_idx, last_n)

func talent_cost(level: int) -> int:
	return int(ceil(4.0 * pow(1.12, float(level))))

func gem_boost_cost(level: int) -> int:
	return 60 * int(pow(2.0, float(level)))
