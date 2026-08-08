extends Node
## Persistence (autoload: SaveSystem). JSON with XOR obfuscation + checksum.
## v3 keeps the game fully local and validates primary plus backup saves.

signal session_offline_ready(amount: float, seconds: float)
signal save_recovered()

const SAVE_PATH   := "user://dts_save.json"
const BACKUP_PATH := "user://dts_save_bak.json"
const SAVE_VERSION := 3
const TEMP_SUFFIX := ".tmp"
const PREVIOUS_SUFFIX := ".previous"

var _save_n := 0   # counts saves; the backup is written every 4th (see save_game)
var _backgrounded_at := 0

func has_save() -> bool:
	for path in [
		SAVE_PATH, SAVE_PATH + TEMP_SUFFIX, SAVE_PATH + PREVIOUS_SUFFIX,
		BACKUP_PATH, BACKUP_PATH + TEMP_SUFFIX, BACKUP_PATH + PREVIOUS_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			return true
	return false

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
	if not _write(SAVE_PATH, envelope):
		return
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

func _write(path: String, text: String) -> bool:
	var temp_path := path + TEMP_SUFFIX
	var previous_path := path + PREVIOUS_SUFFIX
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot write temporary save %s" % temp_path)
		return false
	f.store_string(text)
	f.flush()
	f.close()

	# Rotate the last known-good target out of the way only after the complete
	# replacement has reached disk. If the second rename fails, restore it.
	if FileAccess.file_exists(previous_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(previous_path))
	if FileAccess.file_exists(path):
		var rotate_error := DirAccess.rename_absolute(
			ProjectSettings.globalize_path(path),
			ProjectSettings.globalize_path(previous_path))
		if rotate_error != OK:
			push_warning("SaveSystem: cannot rotate previous save (%s)." % rotate_error)
			return false
	var commit_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(path))
	if commit_error != OK:
		push_warning("SaveSystem: cannot commit save (%s); restoring previous." % commit_error)
		if FileAccess.file_exists(previous_path):
			DirAccess.rename_absolute(
				ProjectSettings.globalize_path(previous_path),
				ProjectSettings.globalize_path(path))
		return false
	if FileAccess.file_exists(previous_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(previous_path))
	return true

## Returns true if a save was loaded. Computes pending offline earnings.
func load_game() -> bool:
	var candidates: Array[String] = [
		SAVE_PATH,
		SAVE_PATH + TEMP_SUFFIX,
		SAVE_PATH + PREVIOUS_SUFFIX,
		BACKUP_PATH,
		BACKUP_PATH + TEMP_SUFFIX,
		BACKUP_PATH + PREVIOUS_SUFFIX,
	]
	for path: String in candidates:
		var raw := _try_load(path)
		if raw.is_empty():
			continue
		var data := decode_envelope(raw)
		if not data.is_empty():
			if path != SAVE_PATH:
				push_warning("SaveSystem: recovered progress from %s." % path)
				_write(SAVE_PATH, raw)
				save_recovered.emit()
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
	for p in [
		SAVE_PATH, SAVE_PATH + TEMP_SUFFIX, SAVE_PATH + PREVIOUS_SUFFIX,
		BACKUP_PATH, BACKUP_PATH + TEMP_SUFFIX, BACKUP_PATH + PREVIOUS_SUFFIX,
	]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Mobile operating systems can terminate a backgrounded process without a
## second callback. Checkpoint immediately when the app leaves the foreground;
## the regular autosave remains responsible during uninterrupted play.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _backgrounded_at == 0:
			_backgrounded_at = int(Time.get_unix_time_from_system())
		save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_apply_session_offline()

## A suspended mobile process usually survives, so load_game() never runs again.
## Credit that background interval here using the same cap/efficiency rules as a
## cold start. Existing uncollected earnings are preserved and fill the remaining
## warehouse capacity instead of being replaced or counted twice.
func _apply_session_offline() -> void:
	if _backgrounded_at <= 0:
		return
	var paused_at := _backgrounded_at
	_backgrounded_at = 0
	var elapsed := AntiCheat.validate_elapsed(paused_at)
	if elapsed < 2.0:
		return
	var cap := GameState.offline_cap()
	var existing_seconds := clampf(GameState.pending_offline_seconds, 0.0, cap)
	var credited_seconds := minf(elapsed, maxf(0.0, cap - existing_seconds))
	if credited_seconds <= 0.0:
		return
	var offline_eff := GameState.OFFLINE_EFF + Prestige.extra_offline_pct()
	GameState.pending_offline_seconds = existing_seconds + credited_seconds
	GameState.pending_offline += GameState.income_per_sec() * credited_seconds * offline_eff
	save_game()
	session_offline_ready.emit(GameState.pending_offline, GameState.pending_offline_seconds)
