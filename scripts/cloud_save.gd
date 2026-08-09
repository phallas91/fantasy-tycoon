extends Node
## Cloud save via Google Play Games Snapshots (autoload: CloudSave).
##
## SAFETY FIRST — this touches save integrity, where a bug wipes progress:
##   • The LOCAL save is untouched and authoritative. Cloud is a backup/sync
##     layer on top; if anything about the cloud path is absent or fails, the
##     game behaves EXACTLY as before (local-only).
##   • Cloud data is only ever restored when it decodes, passes its checksum,
##     AND has strictly MORE lifetime earnings than the current local state. A
##     corrupt or emptier cloud blob can never overwrite good local progress.
##
## Only active on Android with the GodotPlayGameServices plugin present. In the
## editor / on desktop / in a build without the plugin, every method no-ops.
##
## REQUIRES Play Console setup to actually sync (see docs/CLOUD_SAVE_SETUP.md):
## configure Play Games Services, an OAuth client with the app's signing SHA-1,
## enable Saved Games, and set the numeric project id in the export option
## `godot_play_game_services/game_id`. Until then this stays dormant and harmless.

signal cloud_restored()   # emitted when a better cloud save replaced local (UI toast)

const FILE_NAME := "dronetycoon_save"
const PUSH_INTERVAL := 90.0   # seconds between background pushes when signed in

var _active := false          # plugin present on this build/platform
var _authed := false
var _sign_in: PlayGamesSignInClient
var _snapshots: PlayGamesSnapshotsClient
var _push_t := 0.0
var _dirty := false           # a local save happened since the last push

func _ready() -> void:
	# Guard: only wire up on Android with the native plugin actually present.
	if OS.get_name() != "Android" or not has_node("/root/GodotPlayGameServices"):
		return
	# Resolve the optional autoload dynamically so editor/desktop/CI parsing
	# remains valid while Play Games export stays disabled until a real game ID.
	var play_games := get_node("/root/GodotPlayGameServices")
	if play_games.get("android_plugin") == null:
		play_games.call("initialize")
	if play_games.get("android_plugin") == null:
		return   # plugin not baked into this build — stay local-only
	_active = true
	_sign_in = PlayGamesSignInClient.new(); add_child(_sign_in)
	_snapshots = PlayGamesSnapshotsClient.new(); add_child(_snapshots)
	_sign_in.user_authenticated.connect(_on_authenticated)
	_snapshots.game_loaded.connect(_on_game_loaded)
	_snapshots.conflict_emitted.connect(_on_conflict)
	# The plugin auto-checks sign-in at startup; ask for the result.
	_sign_in.is_authenticated()

func _on_authenticated(is_authenticated: bool) -> void:
	_authed = is_authenticated
	if _authed:
		# Pull the cloud save once; the merge decides whether it wins (see below).
		_snapshots.load_game(FILE_NAME, true)

## Cloud snapshot arrived. Restore it ONLY if it's valid and strictly ahead of
## local; otherwise push local up so the cloud catches up. Never destroys the
## better of the two.
func _on_game_loaded(snapshot: PlayGamesSnapshot) -> void:
	if snapshot == null or snapshot.content == null:
		_push()   # nothing usable in the cloud yet — seed it with local
		return
	var text := snapshot.content.get_string_from_utf8()
	var cloud := SaveSystem.cloud_progress(text)          # -1 if invalid
	var local := GameState.total_earned
	if cloud > local * 1.0000001:                          # cloud strictly ahead
		if SaveSystem.apply_cloud(text):
			cloud_restored.emit()
	else:
		_push()   # local is as-good-or-better — sync it up to the cloud

## No clean resolve API is exposed by the plugin, so pick the higher-progress of
## the two conflicting versions, apply it if it beats local, then re-push. Rare
## for a single-player idle (needs the same account live on two devices at once).
func _on_conflict(conflict: PlayGamesSnapshotConflict) -> void:
	var best := ""
	var best_score := -1.0
	var candidates: Array[PlayGamesSnapshot] = [conflict.server_snapshot, conflict.conflicting_snapshot]
	for snap in candidates:
		if snap != null and snap.content != null:
			var t: String = snap.content.get_string_from_utf8()
			var s: float = SaveSystem.cloud_progress(t)
			if s > best_score:
				best_score = s; best = t
	if best_score > GameState.total_earned * 1.0000001 and SaveSystem.apply_cloud(best):
		cloud_restored.emit()
	_push()

## Called by SaveSystem-adjacent code / on a timer: flag that local moved on.
func mark_dirty() -> void:
	_dirty = true

func _process(delta: float) -> void:
	if not _active or not _authed:
		return
	_push_t += delta
	if _push_t >= PUSH_INTERVAL:
		_push_t = 0.0
		if _dirty:
			_push()

func _push() -> void:
	if not _active or not _authed:
		return
	_dirty = false
	var blob := SaveSystem.build_envelope().to_utf8_buffer()
	var played := int(GameState.total_deliveries)   # coarse "played" proxy for metadata
	var progress := int(clampf(log(maxf(GameState.total_earned, 1.0)) / log(10.0), 0.0, 2.1e9))
	_snapshots.save_game(FILE_NAME, "Arcane Trade Empire", blob, played, progress)

## Push on app background/exit so the latest state reaches the cloud even if the
## player never idles long enough for the timer.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _active and _authed:
			_push()
