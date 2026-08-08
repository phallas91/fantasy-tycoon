extends Node
## Timed random events (autoload: Events). Bonuses that appear during play.

signal started(id: String)
signal ended(id: String)

const DEFS := {
    "rush":     {"name": "Marktandrang",       "desc": "Handelsertrag ×2 für 5 Minuten!",       "icon": "⚡", "dur": 300.0, "mult": 2.0,  "col": 0, "w": 10},
    "golden":   {"name": "Goldener Auftrag",   "desc": "Nächster Handel ×10!",                   "icon": "⭐", "dur": 90.0,  "mult": 10.0, "col": 1, "one_shot": true, "w": 10},
    "storm":    {"name": "Runensturm",         "desc": "Reisetempo halbiert, Ertrag ×3!",        "icon": "⛈", "dur": 240.0, "mult": 3.0,  "col": 2, "spd": 0.5, "w": 10},
    "festival": {"name": "Basarfest",          "desc": "Handelsertrag ×2,5 für 8 Minuten!",      "icon": "🎉", "dur": 480.0, "mult": 2.5,  "col": 3, "w": 10},
    "royal_cargo":{"name": "Königliche Fracht", "desc": "Nächster Handel ×25!",                   "icon": "💼", "dur": 60.0,  "mult": 25.0, "col": 1, "one_shot": true, "w": 10},
    "windfall": {"name": "Drachenschatz",      "desc": "Handelsertrag ×8 für 3 Minuten! SELTEN!","icon": "🌟", "dur": 180.0, "mult": 8.0,  "col": 1, "w": 2},
    "drone_tech":{"name": "Greifenwind",       "desc": "Reisetempo ×1,5 und Ertrag ×1,5!",       "icon": "🦅", "dur": 180.0, "mult": 1.5,  "col": 0, "spd": 1.5, "w": 7},
    "black_friday":{"name": "Nachtmarkt",      "desc": "Handelsertrag ×6 für 5 Minuten!",        "icon": "🌙", "dur": 300.0, "mult": 6.0,  "col": 1, "w": 3},
    "blitz":    {"name": "Eilauftrag",         "desc": "Nächster Handel ×20!",                   "icon": "🎯", "dur": 40.0,  "mult": 20.0, "col": 1, "one_shot": true, "w": 5},
}

const COLORS := [
    Color(0.28, 0.52, 1.00),
    Color(1.00, 0.78, 0.22),
    Color(0.45, 0.65, 1.00),
    Color(0.13, 0.82, 0.48),
]

const MIN_WAIT := 240.0
const MAX_WAIT := 720.0

var active := ""
var timer := 0.0
var next_wait := 0.0
var total_participated := 0

# Multipliers applied in GameState
var current_mult := 1.0
var current_spd_mult := 1.0
var _one_shot_fired := false
var _active_one_shot := false   # cached copy of DEFS[active]["one_shot"] — see _trigger()

func _ready() -> void:
    next_wait = randf_range(60.0, 180.0)  # first event 1-3 min

func _process(delta: float) -> void:
    if active != "":
        timer -= delta
        # DEFS[active] used to be re-fetched every single frame for the
        # entire event duration (up to 480s for "festival") just to read a
        # constant flag — cached once in _trigger() instead
        if _active_one_shot and _one_shot_fired:
            _end()
        elif timer <= 0.0:
            _end()
    else:
        next_wait -= delta
        if next_wait <= 0.0:
            _trigger()

func _trigger() -> void:
    var pool: Array = []
    for k: String in DEFS.keys():
        var w: int = int(DEFS[k].get("w", 10))
        for _i in range(w):
            pool.append(k)
    var id: String = pool[randi() % pool.size()]
    active = id; _one_shot_fired = false
    var def: Dictionary = DEFS[id]
    timer = float(def.get("dur", 120.0))
    current_mult = float(def.get("mult", 1.0))
    current_spd_mult = float(def.get("spd", 1.0))
    _active_one_shot = bool(def.get("one_shot", false))
    total_participated += 1
    if has_node("/root/Achievements"): Achievements.note_event(total_participated)
    if has_node("/root/Audio"): Audio.play("unlock")
    started.emit(id)

func _end() -> void:
    var id := active
    active = ""; current_mult = 1.0; current_spd_mult = 1.0
    next_wait = randf_range(MIN_WAIT, MAX_WAIT)
    ended.emit(id)

func is_one_shot_active() -> bool:
    return active != "" and _active_one_shot and not _one_shot_fired

## Consumes a "next delivery" event immediately. Returning true lets the
## simulation recompute its cached multiplier before processing another courier
## in the same frame, so exactly one delivery receives the advertised bonus.
func consume_one_shot() -> bool:
    if not is_one_shot_active():
        return false
    _one_shot_fired = true
    _end()
    return true

func is_active() -> bool:
    return active != ""

func def() -> Dictionary:
    return DEFS.get(active, {}) if active != "" else {}

func time_pct() -> float:
    if not is_active(): return 0.0
    var d: Dictionary = DEFS.get(active, {})
    return clampf(timer / maxf(float(d.get("dur", 1.0)), 0.001), 0.0, 1.0)

func time_left() -> float:
    return timer if is_active() else 0.0

func color() -> Color:
    if not is_active(): return Color.WHITE
    var ci: int = int(def().get("col", 0))
    return COLORS[mini(ci, COLORS.size() - 1)]
