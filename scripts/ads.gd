extends Node
## Ads layer (autoload: Ads).
##
## Real AdMob rewarded ads on Android when the AdmobPlugin native singleton is
## present (release/debug device or emulator builds with the plugin baked in).
## Falls back to a simulated on-screen countdown in the editor/desktop only, so
## gameplay flows remain testable. Android without the plugin reports unavailable
## instead of granting free currency. See docs/ADMOB_INTEGRATION.md.
##
## Uses Google's public TEST ad unit IDs (Admob.ANDROID_REWARDED_DEMO_AD_UNIT_ID)
## until real ones are configured — see docs/ADMOB_INTEGRATION.md for the
## one-line switch to production ads once an AdMob account/app exists.

signal reward_granted(kind: String)
signal reward_failed(kind: String, reason: String)

var _busy := false

# --- real AdMob path ---
var _admob: Admob = null
var _ad_ready := false
var _pending_kind := ""
var _pending_cb: Callable
var _watch_token := 0   # invalidates a stale watchdog when a newer ad is shown
var _retry_scheduled := false

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("AdmobPlugin"):
		return   # editor / desktop / plugin not baked into this build: fake path only
	_admob = Admob.new()
	_admob.is_real = true   # real AdMob account configured (App/unit IDs below)
	_admob.android_real_rewarded_id = "ca-app-pub-6257070310596477/2848051384"
	add_child(_admob)
	# GDPR/UMP consent — request info at startup and show the form when Google
	# says one is required (EEA/UK/CH). Ads still init in parallel; they serve
	# non-personalized until consent is granted. Never soft-locks gameplay.
	_admob.consent_info_updated.connect(_on_consent_updated)
	_admob.consent_form_loaded.connect(func(): _admob.show_consent_form())
	_admob.initialization_completed.connect(func(_status): _load_next_ad())
	_admob.rewarded_ad_loaded.connect(func(_info, _resp): _ad_ready = true)
	_admob.rewarded_ad_failed_to_load.connect(func(_info, _err): _ad_ready = false; _retry_load_later())
	_admob.rewarded_ad_user_earned_reward.connect(func(_info, _reward): _grant_pending())
	# Only Google's earned-reward callback may grant currency. Dismiss/failure
	# callbacks are terminal but unrewarded; treating either as success creates a
	# trivial airplane-mode/back-button exploit in a production economy.
	_admob.rewarded_ad_dismissed_full_screen_content.connect(func(_info):
		if _busy: _cancel_pending("dismissed")
		_load_next_ad())
	_admob.rewarded_ad_failed_to_show_full_screen_content.connect(func(_info, _err):
		_cancel_pending("show_failed")
		_load_next_ad())
	_admob.initialize()
	_admob.update_consent_info()   # kicks off the UMP flow (no-op outside EEA/UK/CH)

func _on_consent_updated() -> void:
	# A form is only available/required in consent regions; load it (which then
	# auto-shows via the consent_form_loaded handler). Elsewhere this is a no-op.
	if _admob != null and _admob.is_consent_form_available():
		_admob.load_consent_form()

func _load_next_ad() -> void:
	_ad_ready = false
	if _admob != null:
		_admob.load_rewarded_ad()

func _retry_load_later() -> void:
	if _retry_scheduled:
		return
	_retry_scheduled = true
	await get_tree().create_timer(30.0).timeout
	_retry_scheduled = false
	if not _busy and not _ad_ready:
		_load_next_ad()

func is_rewarded_ready() -> bool:
	if _busy:
		return false
	# The simulator is a desktop/editor aid only. An Android build missing the
	# native plugin must never become an unlimited free-reward generator.
	return OS.get_name() != "Android" if _admob == null else _ad_ready

## Show a rewarded ad. On completion, `on_reward` is called and the signal fires.
## `kind` is a free-form tag identifying the placement (e.g. "refuel", "x2", "offline").
func show_rewarded(kind: String, on_reward: Callable = Callable()) -> void:
	if _busy:
		return
	_busy = true
	if _admob == null and OS.get_name() != "Android":
		# Editor/desktop preview keeps the placement testable without an SDK.
		_play_overlay(kind, on_reward)
		return
	if _admob == null or not _ad_ready:
		_busy = false
		reward_failed.emit(kind, "not_ready")
		return
	_pending_kind = kind
	_pending_cb = on_reward
	_watch_token += 1
	_admob.show_rewarded_ad()
	_watchdog(_watch_token)

## Safety net for a native ad that produces no terminal callback. Release the UI
## lock, but never mint a reward without Google's earned-reward callback.
func _watchdog(token: int) -> void:
	await get_tree().create_timer(20.0).timeout
	if _busy and token == _watch_token:
		_cancel_pending("timeout")
		_load_next_ad()

func _grant_pending() -> void:
	if not _busy:
		return   # rewarded_ad_user_earned_reward AND the show-failure path can
	_busy = false  # both fire in some SDK edge cases — only grant once
	if _pending_cb.is_valid():
		_pending_cb.call()
	reward_granted.emit(_pending_kind)
	_pending_kind = ""
	_pending_cb = Callable()

func _cancel_pending(reason: String) -> void:
	if not _busy:
		return
	_busy = false
	var kind := _pending_kind
	_pending_kind = ""
	_pending_cb = Callable()
	reward_failed.emit(kind, reason)

## Interstitials are gated by the "remove ads" purchase. No-op in this game
## by design — see docs/ADMOB_INTEGRATION.md if that ever changes.
func show_interstitial() -> void:
	if Billing.ads_removed:
		return
	pass

# ── Fake/editor fallback (unchanged from the pre-AdMob build) ────────────────

func _play_overlay(kind: String, on_reward: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	layer.add_child(box)

	var title := Label.new()
	title.text = "Anúncio (demonstração)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	box.add_child(title)

	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 64)
	count.add_theme_color_override("font_color", Color(0.23, 0.94, 0.63))
	box.add_child(count)

	var note := Label.new()
	note.text = "(substituível por AdMob real — ver docs)"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(note)

	for i in range(3, 0, -1):
		count.text = str(i)
		await get_tree().create_timer(0.7).timeout

	count.text = "✓ Recompensa!"
	await get_tree().create_timer(0.5).timeout

	layer.queue_free()
	_busy = false
	if on_reward.is_valid():
		on_reward.call()
	reward_granted.emit(kind)
