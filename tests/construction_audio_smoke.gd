extends SceneTree
## Validates the real synthesized PCM resources, not only their source wiring.

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("CONSTRUCTION_AUDIO_RUNTIME: " + message)
	quit(1)

func _run() -> void:
	await process_frame
	var audio := root.get_node("Audio")
	var streams: Dictionary = audio.get("_streams")
	var hashes: Dictionary = {}
	for raw_kind in ["speed", "cargo", "value", "routes"]:
		var kind: String = str(raw_kind)
		var short_key: String = "upgrade_" + kind
		var landmark_key: String = "landmark_" + kind
		if not streams.has(short_key) or not streams.has(landmark_key):
			_fail("missing synthesized pair for " + kind)
			return
		var short_stream := streams[short_key] as AudioStreamWAV
		var landmark_stream := streams[landmark_key] as AudioStreamWAV
		if short_stream == null or landmark_stream == null or short_stream.data.is_empty():
			_fail("empty PCM stream for " + kind)
			return
		if landmark_stream.data.size() <= short_stream.data.size():
			_fail("landmark sound is not fuller than investment sound for " + kind)
			return
		for stream in [short_stream, landmark_stream]:
			var fingerprint: int = hash(stream.data)
			if hashes.has(fingerprint):
				_fail("duplicate construction waveform: %s and %s" % [hashes[fingerprint], kind])
				return
			hashes[fingerprint] = kind
	print("CONSTRUCTION_AUDIO_RUNTIME: PASS (8 distinct non-empty PCM signatures)")
	quit(0)
