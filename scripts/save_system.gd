extends Node
## Persistence (autoload: SaveSystem). JSON with XOR obfuscation + checksum.
## v3 keeps the game fully local and validates primary plus backup saves.

const SAVE_PATH   := "user://dts_save.json"
const BACKUP_PATH := "user://dts_save_bak.json"
const SAVE_VERSION := 3

var _save_n := 0   # counts saves; the backup is written every 4th (see save_game)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)

## Builds the obfuscated and checksummed local save envelope.
func build_envelope() -> String:
	var payload := {
		"v": SAVE_VERSION,
		"ts": int(Time.get_unix_time_from_system()),
		"game":    GameState.to_dict(),
		"audio":   Audio.to_dict(),
		"prestige":     Prestige.to_dict(),
		"achievements": Achievements.to_dict(),
		"daily":        Daily.to_dict(),
		"contracts":    Contracts.to_dict(),
		"fx":           Fx.to_dict(),
	}
	var raw := JSON.stringify(payload)
	var cs  := AntiCheat.checksum(raw)
	return JSON.stringify({"cs": cs, "d": AntiCheat.encode(raw)})

func save_game() -> void:
	var envelope := build_envelope()
	_write(SAVE_PATH, envelope)
	# The backup used to be written on every save, doubling the main-thread I/O of
	# a 15s autosave for no extra safety — writing both back-to-back means a crash
	# mid-save can take out both copies. A ~60s-stale backup is a better fallback
	# and costs half the writes.
	_save_n += 1
	if _save_n % 4 == 0:
		_write(BACKUP_PATH, envelope)

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()

## Returns true if a save was loaded. Computes pending offline earnings.
func load_game() -> bool:
	var raw := _try_load(SAVE_PATH)
	if raw.is_empty():
		raw = _try_load(BACKUP_PATH)
	if raw.is_empty():
		return false
	var data: Variant = JSON.parse_string(raw)
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("SaveSystem: corrupt save.")
		return false

	# Migrate v1 saves (plain JSON, no envelope)
	if not data.has("d"):
		return _apply(data)

	# Verify checksum
	var encoded: String = str(data.get("d", ""))
	var stored_cs: String = str(data.get("cs", ""))
	var decoded := AntiCheat.decode(encoded)
	if AntiCheat.checksum(decoded) != stored_cs:
		push_warning("SaveSystem: checksum mismatch — restoring from backup.")
		raw = _try_load(BACKUP_PATH)
		if raw.is_empty(): return false
		data = JSON.parse_string(raw)
		if typeof(data) != TYPE_DICTIONARY: return false
		if not data.has("d"): return _apply(data)
		encoded = str(data.get("d", ""))
		decoded = AntiCheat.decode(encoded)
		if AntiCheat.checksum(decoded) != str(data.get("cs", "")):
			push_warning("SaveSystem: backup checksum mismatch.")
			return false

	var inner: Variant = JSON.parse_string(decoded)
	if typeof(inner) != TYPE_DICTIONARY:
		return false
	return _apply(inner)

func _try_load(path: String) -> String:
	if not FileAccess.file_exists(path): return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return ""
	var txt := f.get_as_text()
	f.close()
	return txt

func _apply(data: Dictionary) -> bool:
	Audio.from_dict(data.get("audio", {}))
	Prestige.from_dict(data.get("prestige", {}))
	Achievements.from_dict(data.get("achievements", {}))
	Daily.from_dict(data.get("daily", {}))
	GameState.from_dict(data.get("game", {}))
	Contracts.from_dict(data.get("contracts", {}))
	Fx.from_dict(data.get("fx", {}))

	# Offline earnings (validated by AntiCheat)
	var ts: int = int(data.get("ts", 0))
	var elapsed: float = AntiCheat.validate_elapsed(ts)
	GameState.pending_offline_seconds = minf(elapsed, GameState.offline_cap())
	var offline_eff: float = GameState.OFFLINE_EFF + Prestige.extra_offline_pct()
	GameState.pending_offline = GameState.income_per_sec() * GameState.pending_offline_seconds * offline_eff

	Achievements.check_all_state()
	return true

func wipe() -> void:
	for p in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
