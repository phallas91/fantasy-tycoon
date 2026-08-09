extends SceneTree
## Headless release smoke test executed by GitHub Actions.
## It never writes player data; it validates the live autoload graph and the
## exact save/checksum pipeline used by local and cloud persistence.

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("SAVE_SMOKE: " + message)
	quit(1)

func _run() -> void:
	await process_frame
	var required := [
		"Fmt", "Economy", "AntiCheat", "Fx", "Events", "Prestige",
		"Achievements", "Daily", "GameState", "Audio", "SaveSystem", "Contracts",
		"Billing", "Ads", "Notifications", "CloudSave",
	]
	for singleton: String in required:
		if not root.has_node(singleton):
			_fail("missing autoload /root/%s" % singleton)
			return
	var save_system := root.get_node("SaveSystem")
	var game_state := root.get_node("GameState")

	var envelope: String = save_system.build_envelope()
	if envelope.is_empty():
		_fail("empty save envelope")
		return
	var decoded: Dictionary = save_system.decode_envelope(envelope)
	if decoded.is_empty() or not decoded.has("game") or not decoded.has("ts"):
		_fail("valid envelope did not round-trip")
		return
	var progress: float = save_system.cloud_progress(envelope)
	if progress < 0.0 or not is_equal_approx(progress, game_state.total_earned):
		_fail("cloud merge score differs from live progress")
		return

	var outer: Variant = JSON.parse_string(envelope)
	if typeof(outer) != TYPE_DICTIONARY:
		_fail("envelope is not valid JSON")
		return
	var tampered := outer as Dictionary
	tampered["cs"] = "invalid-checksum"
	if not save_system.decode_envelope(JSON.stringify(tampered)).is_empty():
		_fail("tampered envelope passed checksum validation")
		return
	if not save_system.decode_envelope("{broken-json").is_empty():
		_fail("malformed JSON was accepted")
		return

	# A killed process may leave a complete newer temporary checkpoint beside an
	# older valid primary. Recovery must compare valid progress, not filenames.
	var primary_path := "user://save-smoke-primary.json"
	var temp_path := "user://save-smoke-temp.json"
	var old_game := (decoded["game"] as Dictionary).duplicate(true)
	old_game["total_earned"] = 10.0
	var old_data := decoded.duplicate(true)
	old_data["game"] = old_game
	old_data["ts"] = 200
	var new_game := (decoded["game"] as Dictionary).duplicate(true)
	new_game["total_earned"] = 20.0
	var new_data := decoded.duplicate(true)
	new_data["game"] = new_game
	new_data["ts"] = 100 # Older clock reading must not defeat richer progress.
	_write_test_envelope(primary_path, old_data)
	_write_test_envelope(temp_path, new_data)
	var candidate_paths: Array[String] = [primary_path, temp_path]
	var selected: Dictionary = save_system._select_best_candidate(candidate_paths)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(primary_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
	if selected.is_empty() or str(selected.get("path", "")) != temp_path:
		_fail("newer interrupted checkpoint was not selected")
		return

	print("SAVE_SMOKE: PASS")
	quit(0)

func _write_test_envelope(path: String, data: Dictionary) -> void:
	var payload := JSON.stringify(data)
	var envelope := JSON.stringify({
		"cs": root.get_node("AntiCheat").checksum(payload),
		"d": root.get_node("AntiCheat").encode(payload),
	})
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("could not create recovery fixture")
		return
	file.store_string(envelope)
	file.close()
