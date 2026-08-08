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
	# CloudSave is deliberately optional until Play Games is configured. When it
	# is enabled, every successful local checkpoint becomes eligible for the next
	# throttled cloud push without coupling the local save path to the plugin.
	if has_node("/root/CloudSave"):
		get_node("/root/CloudSave").call("mark_dirty")

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot write %s" % path)
		return
	f.store_string(text)
	f.close()

## Returns true if a save was loaded. Computes pending offline earnings.
func load_game() -> bool:
	for path: String in [SAVE_PATH, BACKUP_PATH]:
		var raw := _try_load(path)
		if raw.is_empty():
			continue
		var data := decode_envelope(raw)
		if not data.is_empty():
			return _apply(data)
		push_warning("SaveSystem: invalid save at %s; trying fallback." % path)
	return false

## Decode and authenticate one local/cloud save blob without mutating the game.
## Legacy v1 plain dictionaries remain readable so updates never strand an old
## player. Enveloped saves must pass the checksum before their payload is parsed.
func decode_envelope(text: String) -> Dictionary:
	if text.is_empty():
		return {}
	var outer: Variant = JSON.parse_string(text)
	if typeof(outer) != TYPE_DICTIONARY:
		return {}
	var envelope := outer as Dictionary
	if not envelope.has("d"):
		return envelope
	var encoded := str(envelope.get("d", ""))
	var decoded := AntiCheat.decode(encoded)
	if decoded.is_empty() or AntiCheat.checksum(decoded) != str(envelope.get("cs", "")):
		return {}
	var inner: Variant = JSON.parse_string(decoded)
	if typeof(inner) != TYPE_DICTIONARY:
		return {}
	return inner as Dictionary

## Read the monotonic merge score used by CloudSave. Invalid, non-finite or
## malformed blobs return -1 and can therefore never beat healthy local data.
func cloud_progress(text: String) -> float:
	var data := decode_envelope(text)
	if data.is_empty() or typeof(data.get("game", null)) != TYPE_DICTIONARY:
		return -1.0
	var earned := float((data["game"] as Dictionary).get("total_earned", -1.0))
	if not is_finite(earned) or earned < 0.0:
		return -1.0
	return earned

## Restore only a valid cloud snapshot that is genuinely ahead. The guard is
## repeated here (rather than trusting the caller) so no future UI path can
## accidentally replace richer local progress with an older snapshot.
func apply_cloud(text: String) -> bool:
	var progress := cloud_progress(text)
	if progress < 0.0 or progress <= GameState.total_earned * 1.0000001:
		return false
	var data := decode_envelope(text)
	if data.is_empty() or not _apply(data):
		return false
	save_game()
	return true

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

## Mobile operating systems can terminate a backgrounded process without a
## second callback. Checkpoint immediately when the app leaves the foreground;
## the regular autosave remains responsible during uninterrupted play.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
