extends SceneTree
## End-to-end persistence lifecycle smoke test.
## Exercises the real autoloads and save files while preserving any pre-existing
## local player data so this is safe to run from a developer checkout too.

const SAVE_PATHS := [
	"user://dts_save.json",
	"user://dts_save.json.tmp",
	"user://dts_save.json.previous",
	"user://dts_save_bak.json",
	"user://dts_save_bak.json.tmp",
	"user://dts_save_bak.json.previous",
]

var _original_files: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	_restore_original_files()
	push_error("PLAYER_LIFECYCLE_SMOKE: " + message)
	quit(1)

func _run() -> void:
	await process_frame
	for singleton: String in ["GameState", "SaveSystem", "Billing", "AntiCheat"]:
		if not root.has_node(singleton):
			_fail("missing autoload /root/%s" % singleton)
			return

	var game_state := root.get_node("GameState")
	var save_system := root.get_node("SaveSystem")
	var billing := root.get_node("Billing")
	_original_files = _snapshot_save_files()
	save_system.wipe()

	# 1) Cold checkpoint -> mutate live state -> reload exact persisted state.
	var baseline_gems: int = int(game_state.gems)
	var baseline_earned: float = float(game_state.total_earned)
	save_system.save_game()
	if not save_system.has_save():
		_fail("initial checkpoint was not written")
		return
	game_state.gems = baseline_gems + 777
	game_state.total_earned = baseline_earned + 1234.0
	if not save_system.load_game():
		_fail("checkpoint could not be loaded")
		return
	if int(game_state.gems) != baseline_gems:
		_fail("gems did not survive save/reload round-trip")
		return
	if not is_equal_approx(float(game_state.total_earned), baseline_earned):
		_fail("economic progress did not survive save/reload round-trip")
		return

	# 2) A cold start two minutes later must credit validated offline duration.
	var offline_data: Dictionary = save_system.decode_envelope(save_system.build_envelope())
	offline_data["ts"] = int(Time.get_unix_time_from_system()) - 120
	if not save_system._apply(offline_data):
		_fail("offline checkpoint could not be applied")
		return
	var offline_seconds: float = float(game_state.pending_offline_seconds)
	if offline_seconds < 115.0 or offline_seconds > 125.0:
		_fail("offline duration outside expected two-minute window: %.1f" % offline_seconds)
		return

	# 3) Desktop/editor billing fallback must grant once and persist through reload.
	if not billing._purchase_simulator_allowed():
		_fail("desktop billing simulator unexpectedly disabled in headless CI")
		return
	var gems_before_purchase: int = int(game_state.gems)
	billing.buy("gems_xs")
	if int(game_state.gems) != gems_before_purchase + 50:
		_fail("simulated purchase did not grant the expected 50 gems")
		return
	var purchased_gems: int = int(game_state.gems)
	game_state.gems = purchased_gems + 99
	if not save_system.load_game():
		_fail("purchase checkpoint could not be reloaded")
		return
	if int(game_state.gems) != purchased_gems:
		_fail("purchased currency was not persisted across reload")
		return

	# 4) Unknown products must fail closed and never mutate currency.
	var gems_before_invalid: int = int(game_state.gems)
	billing.buy("not_a_real_product")
	if int(game_state.gems) != gems_before_invalid:
		_fail("unknown product mutated player currency")
		return

	_restore_original_files()
	print("PLAYER_LIFECYCLE_SMOKE: PASS (save/load, offline, billing fallback, restart persistence)")
	quit(0)

func _snapshot_save_files() -> Dictionary:
	var snapshot: Dictionary = {}
	for path: String in SAVE_PATHS:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_fail("could not back up existing local save: %s" % path)
			return {}
		snapshot[path] = file.get_as_text()
		file.close()
	return snapshot

func _restore_original_files() -> void:
	for path: String in SAVE_PATHS:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	for path: String in _original_files.keys():
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("PLAYER_LIFECYCLE_SMOKE: could not restore %s" % path)
			continue
		file.store_string(str(_original_files[path]))
		file.close()
