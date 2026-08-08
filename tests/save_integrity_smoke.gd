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
	]
	for singleton: String in required:
		if not root.has_node(singleton):
			_fail("missing autoload /root/%s" % singleton)
			return

	var envelope: String = SaveSystem.build_envelope()
	if envelope.is_empty():
		_fail("empty save envelope")
		return
	var decoded: Dictionary = SaveSystem.decode_envelope(envelope)
	if decoded.is_empty() or not decoded.has("game") or not decoded.has("ts"):
		_fail("valid envelope did not round-trip")
		return
	var progress := SaveSystem.cloud_progress(envelope)
	if progress < 0.0 or not is_equal_approx(progress, GameState.total_earned):
		_fail("cloud merge score differs from live progress")
		return

	var outer: Variant = JSON.parse_string(envelope)
	if typeof(outer) != TYPE_DICTIONARY:
		_fail("envelope is not valid JSON")
		return
	var tampered := outer as Dictionary
	tampered["cs"] = "invalid-checksum"
	if not SaveSystem.decode_envelope(JSON.stringify(tampered)).is_empty():
		_fail("tampered envelope passed checksum validation")
		return
	if not SaveSystem.decode_envelope("{broken-json").is_empty():
		_fail("malformed JSON was accepted")
		return

	print("SAVE_SMOKE: PASS")
	quit(0)
