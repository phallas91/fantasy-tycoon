extends Node
## Achievement system (autoload: Achievements). 40+ milestones with gem rewards.

signal unlocked(id: String)

const DEFS := {
    # Deliveries
    "first_delivery":  {"name": "Primeira Entrega",      "desc": "Completa a primeira entrega.",              "icon": "🚁", "cat": "frota"},
    "deliveries_100":  {"name": "Cem Entregas",           "desc": "Completa 100 entregas.",                    "icon": "📦", "cat": "frota"},
    "deliveries_1k":   {"name": "Mil Entregas",           "desc": "Completa 1 000 entregas.",                  "icon": "📦", "cat": "frota"},
    "deliveries_10k":  {"name": "Dez Mil Entregas",       "desc": "Completa 10 000 entregas.",                 "icon": "🏆", "cat": "frota"},
    # Fleet
    "drones_5":        {"name": "Pequena Frota",          "desc": "Tem 5 drones activos.",                     "icon": "🚁", "cat": "frota"},
    "drones_25":       {"name": "Frota Sólida",           "desc": "Tem 25 drones activos.",                    "icon": "💪", "cat": "frota"},
    "drones_100":      {"name": "Exército de Drones",     "desc": "Tem 100 drones activos.",                   "icon": "⚡", "cat": "frota"},
    "drones_500":      {"name": "Força Aérea",            "desc": "Tem 500 drones activos.",                   "icon": "🌟", "cat": "frota"},
    "buy_100_once":    {"name": "Atacado",                "desc": "Compra 100 drones de uma vez.",             "icon": "🛒", "cat": "frota", "secret": true},
    # Credits
    "credits_1m":      {"name": "Milionário",             "desc": "Acumula 1 M de créditos.",                  "icon": "💰", "cat": "riqueza"},
    "credits_1b":      {"name": "Bilionário",             "desc": "Acumula 1 B de créditos.",                  "icon": "💎", "cat": "riqueza"},
    "credits_1t":      {"name": "Trilionário",            "desc": "Acumula 1 T de créditos.",                  "icon": "🌟", "cat": "riqueza"},
    "earned_10b":      {"name": "Fluxo de Caixa",         "desc": "Ganha 10 B no total.",                      "icon": "📈", "cat": "riqueza"},
    "earned_1t":       {"name": "Magnata",                "desc": "Ganha 1 T no total.",                       "icon": "🏆", "cat": "riqueza"},
    "income_1k":       {"name": "Rendimento Sólido",      "desc": "Atinge 1 000/s de receita.",                "icon": "📈", "cat": "riqueza"},
    "income_1m":       {"name": "Máquina de Dinheiro",    "desc": "Atinge 1 M/s de receita.",                  "icon": "💹", "cat": "riqueza"},
    # Countries / Cities
    "country_2":       {"name": "Expansão Global",        "desc": "Expande para o 2.º país.",                  "icon": "🌍", "cat": "mundo"},
    "country_5":       {"name": "Continente",             "desc": "Expande para 5 países.",                    "icon": "🌍", "cat": "mundo"},
    "country_10":      {"name": "Dominação Mundial",      "desc": "Expande para 10 países.",                   "icon": "🌐", "cat": "mundo"},
    "cities_10":       {"name": "Urbanista",              "desc": "Desbloqueia 10 cidades no total.",          "icon": "🏙", "cat": "mundo"},
    "cities_50":       {"name": "Megalópole",             "desc": "Desbloqueia 50 cidades no total.",          "icon": "🌆", "cat": "mundo"},
    # Upgrades / Talents
    "upgrade_25":      {"name": "Engenheiro",             "desc": "Chega ao nível 25 num upgrade.",            "icon": "⚙", "cat": "melhorias"},
    "upgrade_100":     {"name": "Mestre Técnico",         "desc": "Chega ao nível 100 num upgrade.",           "icon": "🔧", "cat": "melhorias"},
    "all_25":          {"name": "Frota Optimizada",       "desc": "Todos os upgrades ao nível 25+.",           "icon": "✨", "cat": "melhorias"},
    "talent_10":       {"name": "Talentoso",              "desc": "Chega ao nível 10 num talento.",            "icon": "⭐", "cat": "melhorias"},
    "influence_50":    {"name": "Influente",              "desc": "Acumula 50 de influência total.",           "icon": "🎯", "cat": "melhorias"},
    "gem_boost_5":     {"name": "Obsessivo",              "desc": "Compra o Núcleo de Lucro 5 vezes.",         "icon": "💠", "cat": "melhorias", "secret": true},
    # Prestige
    "prestige_1":      {"name": "Novo Começo",            "desc": "Faz prestige pela primeira vez.",           "icon": "🔄", "cat": "legado"},
    "prestige_3":      {"name": "Veterano",               "desc": "Faz prestige 3 vezes.",                     "icon": "💎", "cat": "legado", "secret": true},
    "prestige_5":      {"name": "Piloto Lendário",        "desc": "Faz prestige 5 vezes.",                     "icon": "🌟", "cat": "legado", "secret": true},
    # Daily / Streak
    "streak_7":        {"name": "Semana de Trabalho",     "desc": "Joga 7 dias consecutivos.",                 "icon": "📅", "cat": "legado"},
    "streak_30":       {"name": "Mês Dedicado",           "desc": "Joga 30 dias consecutivos.",                "icon": "🗓", "cat": "legado"},
    "total_30":        {"name": "Piloto Fiel",            "desc": "Joga 30 dias no total.",                    "icon": "🎖", "cat": "legado"},
    # Events
    "event_first":     {"name": "Hora de Ponta",          "desc": "Participa no primeiro evento.",             "icon": "⚡", "cat": "eventos"},
    "event_5":         {"name": "Caçador de Eventos",     "desc": "Participa em 5 eventos.",                   "icon": "🎉", "cat": "eventos"},
    "event_25":        {"name": "Mestre dos Eventos",     "desc": "Participa em 25 eventos.",                  "icon": "🎯", "cat": "eventos"},
    # Offline
    "offline_big":     {"name": "Gestor Ausente",         "desc": "Recolhe mais de 1 M offline.",             "icon": "💤", "cat": "riqueza"},
    # Session
    "session_30m":     {"name": "Dedicado",               "desc": "Joga 30 minutos numa sessão.",              "icon": "⏱", "cat": "legado"},
    # Gems
    "gems_100":        {"name": "Coleccionador",          "desc": "Tens 100 gemas em simultâneo.",             "icon": "💎", "cat": "riqueza"},
    "gems_spent_500":  {"name": "Investidor",             "desc": "Gasta 500 gemas no total.",                 "icon": "💠", "cat": "riqueza"},
    # Coleção / dedicação (previously-missing tracks)
    "golden_10":       {"name": "Caçador Dourado",        "desc": "Apanha 10 drones dourados.",                "icon": "🥇", "cat": "coleção"},
    "combo_100":       {"name": "Em Chamas",              "desc": "Atinge um combo de 100.",                   "icon": "🔥", "cat": "frota"},
    "ascendant_5":     {"name": "Ascensão",               "desc": "Sobe o Núcleo Ascendente 5 vezes.",         "icon": "🔺", "cat": "legado", "secret": true},
    "skins_all":       {"name": "Estilista",              "desc": "Coleciona todas as skins.",                 "icon": "🎨", "cat": "coleção", "secret": true},
}

# Persisted
var unlocked_ids: Array = []
var counters := {
    "deliveries": 0,
    "cities_total": 0,
    "events_total": 0,
    "gems_spent": 0,
    "golden_total": 0,
}

# Transient
var _session_start_ms: int = 0
# latches for the two _process conditions that stay true forever once met, so we
# stop re-scanning unlocked_ids every frame to rediscover them
var _session_30m_done := false
var _skins_all_done := false

func _ready() -> void:
    _session_start_ms = Time.get_ticks_msec()
    if has_node("/root/GameState"):
        GameState.delivered.connect(_on_delivered)
        GameState.city_unlocked.connect(_on_city_unlocked)
        GameState.country_changed.connect(_on_country)

func _process(_delta: float) -> void:
    # Once past 30 min this condition is permanently true, so it re-entered check()
    # every frame forever — and check()'s `id in unlocked_ids` guard is a linear
    # string scan over up to 45 entries. Latch it instead.
    if not _session_30m_done:
        if Time.get_ticks_msec() - _session_start_ms >= 30 * 60 * 1000:
            _session_30m_done = true
            check("session_30m", true)
    if has_node("/root/GameState"):
        check("combo_100", GameState.combo >= 100)
        # same permanently-true-once-earned scan as above
        if not _skins_all_done and GameState.skins_owned.size() >= Economy.SKINS.size():
            _skins_all_done = true
            check("skins_all", true)

func _on_delivered(_amount: float, _city: int, count: int) -> void:
    # `count`, not 1: one emission can bank several arrivals (see GameState.delivered)
    counters["deliveries"] = int(counters.get("deliveries", 0)) + count
    var d: int = int(counters["deliveries"])
    check("first_delivery", d >= 1)
    check("deliveries_100",  d >= 100)
    check("deliveries_1k",   d >= 1000)
    check("deliveries_10k",  d >= 10000)

func _on_city_unlocked(_idx: int) -> void:
    counters["cities_total"] = int(counters.get("cities_total", 0)) + 1
    var ct: int = int(counters["cities_total"])
    check("cities_10", ct >= 10)
    check("cities_50", ct >= 50)

func _on_country(idx: int) -> void:
    check("country_2",  idx >= 1)
    check("country_5",  idx >= 4)
    check("country_10", idx >= 9)

## Highest/lowest of the 4 upgrade levels — was independently recomputed as
## an identical nested maxi()/mini() chain here AND (twice) in progress();
## now a single shared helper.
func _max_upgrade_level(gs: Node) -> int:
    return maxi(int(gs.levels.get("speed", 0)), maxi(int(gs.levels.get("cargo", 0)), maxi(int(gs.levels.get("value", 0)), int(gs.levels.get("routes", 0)))))

func _min_upgrade_level(gs: Node) -> int:
    return mini(int(gs.levels.get("speed", 0)), mini(int(gs.levels.get("cargo", 0)), mini(int(gs.levels.get("value", 0)), int(gs.levels.get("routes", 0)))))

## Call after loading save to re-evaluate state-based achievements
func check_all_state() -> void:
    if not has_node("/root/GameState"): return
    var gs := GameState
    check("drones_5",    gs.drones >= 5)
    check("drones_25",   gs.drones >= 25)
    check("drones_100",  gs.drones >= 100)
    check("drones_500",  gs.drones >= 500)
    check("credits_1m",  gs.credits >= 1_000_000.0)
    check("credits_1b",  gs.credits >= 1_000_000_000.0)
    check("credits_1t",  gs.credits >= 1_000_000_000_000.0)
    check("earned_10b",  gs.total_earned >= 10_000_000_000.0)
    check("earned_1t",   gs.total_earned >= 1_000_000_000_000.0)
    var max_lv: int = _max_upgrade_level(gs)
    check("upgrade_25",  max_lv >= 25)
    check("upgrade_100", max_lv >= 100)
    check("all_25",      _min_upgrade_level(gs) >= 25)
    var max_tal: int = maxi(int(gs.talents.get("global", 0)), maxi(int(gs.talents.get("speed", 0)), maxi(int(gs.talents.get("value", 0)), int(gs.talents.get("hangar", 0)))))
    check("talent_10",   max_tal >= 10)
    check("influence_50", gs.influence_total >= 50)
    check("gems_100",    gs.gems >= 100)
    check("income_1k",   gs.income_per_sec() >= 1000.0)
    check("income_1m",   gs.income_per_sec() >= 1_000_000.0)
    check("skins_all", gs.skins_owned.size() >= Economy.SKINS.size())
    check("golden_10", int(counters.get("golden_total", 0)) >= 10)
    if has_node("/root/Prestige"):
        check("ascendant_5", Prestige.ascendant_level >= 5)
    check("country_2",   gs.current_country >= 1)
    check("country_5",   gs.current_country >= 4)
    check("country_10",  gs.current_country >= 9)
    # Deliveries — prefer saved counter; fall back to GameState.total_deliveries for old saves
    var d: int = maxi(int(counters.get("deliveries", 0)), gs.total_deliveries)
    check("first_delivery", d >= 1)
    check("deliveries_100",  d >= 100)
    check("deliveries_1k",   d >= 1000)
    check("deliveries_10k",  d >= 10000)
    # Cities — re-check from saved counter
    var ct: int = int(counters.get("cities_total", 0))
    check("cities_10", ct >= 10)
    check("cities_50", ct >= 50)

func note_drone_buy(count: int, total: int) -> void:
    check("buy_100_once", count >= 100)
    check("drones_5",    total >= 5)
    check("drones_25",   total >= 25)
    check("drones_100",  total >= 100)
    check("drones_500",  total >= 500)

func note_gem_boost(level: int) -> void:
    check("gem_boost_5", level >= 5)

func note_offline(amount: float) -> void:
    check("offline_big", amount >= 1_000_000.0)

func note_streak(days: int, total: int) -> void:
    check("streak_7",  days >= 7)
    check("streak_30", days >= 30)
    check("total_30",  total >= 30)

func note_event(total: int) -> void:
    check("event_first", total >= 1)
    check("event_5",     total >= 5)
    check("event_25",    total >= 25)

func note_gems_spent(amount: int) -> void:
    counters["gems_spent"] = int(counters.get("gems_spent", 0)) + amount
    check("gems_spent_500", int(counters["gems_spent"]) >= 500)

func note_prestige(count: int) -> void:
    check("prestige_1", count >= 1)
    check("prestige_3", count >= 3)
    check("prestige_5", count >= 5)

func note_golden() -> void:
    counters["golden_total"] = int(counters.get("golden_total", 0)) + 1
    check("golden_10", int(counters["golden_total"]) >= 10)

func note_ascendant(level: int) -> void:
    check("ascendant_5", level >= 5)

func check(id: String, condition: bool) -> void:
    if not condition: return
    if id in unlocked_ids: return
    if not DEFS.has(id): return
    unlocked_ids.append(id)
    # Achievements are pure collection goals. Gems come from daily rewards,
    # contracts, progression and golden griffin treasures.
    if has_node("/root/Audio"):
        Audio.play("achieve")
    unlocked.emit(id)

func is_done(id: String) -> bool:
    return id in unlocked_ids

func done_count() -> int:
    return unlocked_ids.size()

func total_count() -> int:
    return DEFS.size()

## Returns Vector2(current, target) for progress display; Vector2.ZERO if unknown.
func progress(id: String) -> Vector2:
    if is_done(id): return Vector2(1.0, 1.0)
    if not has_node("/root/GameState"): return Vector2.ZERO
    var gs := GameState
    match id:
        "first_delivery":  return Vector2(float(counters.get("deliveries", 0)), 1.0)
        "deliveries_100":  return Vector2(float(counters.get("deliveries", 0)), 100.0)
        "deliveries_1k":   return Vector2(float(counters.get("deliveries", 0)), 1000.0)
        "deliveries_10k":  return Vector2(float(counters.get("deliveries", 0)), 10000.0)
        "drones_5":        return Vector2(float(gs.drones), 5.0)
        "drones_25":       return Vector2(float(gs.drones), 25.0)
        "drones_100":      return Vector2(float(gs.drones), 100.0)
        "drones_500":      return Vector2(float(gs.drones), 500.0)
        "credits_1m":      return Vector2(gs.credits, 1_000_000.0)
        "credits_1b":      return Vector2(gs.credits, 1_000_000_000.0)
        "credits_1t":      return Vector2(gs.credits, 1_000_000_000_000.0)
        "earned_10b":      return Vector2(gs.total_earned, 10_000_000_000.0)
        "earned_1t":       return Vector2(gs.total_earned, 1_000_000_000_000.0)
        "income_1k":       return Vector2(gs.income_per_sec(), 1000.0)
        "income_1m":       return Vector2(gs.income_per_sec(), 1_000_000.0)
        "cities_10":       return Vector2(float(counters.get("cities_total", 0)), 10.0)
        "cities_50":       return Vector2(float(counters.get("cities_total", 0)), 50.0)
        "country_2":       return Vector2(float(gs.current_country + 1), 2.0)
        "country_5":       return Vector2(float(gs.current_country + 1), 5.0)
        "country_10":      return Vector2(float(gs.current_country + 1), 10.0)
        "event_first":     return Vector2(float(counters.get("events_total", 0)), 1.0)
        "event_5":         return Vector2(float(counters.get("events_total", 0)), 5.0)
        "event_25":        return Vector2(float(counters.get("events_total", 0)), 25.0)
        "gems_100":        return Vector2(float(gs.gems), 100.0)
        "gems_spent_500":  return Vector2(float(counters.get("gems_spent", 0)), 500.0)
        "golden_10":       return Vector2(float(counters.get("golden_total", 0)), 10.0)
        "combo_100":       return Vector2(float(gs.combo), 100.0)
        "skins_all":       return Vector2(float(gs.skins_owned.size()), float(Economy.SKINS.size()))
        "ascendant_5":     return Vector2(float(Prestige.ascendant_level if has_node("/root/Prestige") else 0), 5.0)
        "influence_50":    return Vector2(float(gs.influence_total), 50.0)
        "prestige_1":      return Vector2(float(Prestige.count), 1.0)
        "prestige_3":      return Vector2(float(Prestige.count), 3.0)
        "prestige_5":      return Vector2(float(Prestige.count), 5.0)
        "upgrade_25":      return Vector2(float(_max_upgrade_level(gs)), 25.0)
        "upgrade_100":     return Vector2(float(_max_upgrade_level(gs)), 100.0)
        "all_25":          return Vector2(float(_min_upgrade_level(gs)), 25.0)
        "talent_10":
            var mt := maxi(int(gs.talents.get("global", 0)), maxi(int(gs.talents.get("speed", 0)), maxi(int(gs.talents.get("value", 0)), int(gs.talents.get("hangar", 0)))))
            return Vector2(float(mt), 10.0)
        "streak_7":
            return Vector2(float(Daily.streak if has_node("/root/Daily") else 0), 7.0)
        "streak_30":
            return Vector2(float(Daily.streak if has_node("/root/Daily") else 0), 30.0)
        "total_30":
            # was missing entirely — "Piloto Fiel" silently showed no progress
            # bar at all, unlike its sibling streak_7/streak_30 above
            return Vector2(float(Daily.total_days if has_node("/root/Daily") else 0), 30.0)
    return Vector2.ZERO

## Full reset ("Reset Progress" in Settings) — all unlocks/counters wiped.
func reset() -> void:
    unlocked_ids = []
    counters = {"deliveries": 0, "cities_total": 0, "events_total": 0, "gems_spent": 0}

func to_dict() -> Dictionary:
    return {"ids": unlocked_ids.duplicate(), "counters": counters.duplicate()}

func from_dict(d: Dictionary) -> void:
    unlocked_ids = Array(d.get("ids", []))
    var cd: Dictionary = d.get("counters", {})
    for k in counters:
        if cd.has(k):
            counters[k] = cd[k]
