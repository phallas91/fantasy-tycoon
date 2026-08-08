extends Control
class_name BonusDrone
## Golden bonus drone that periodically crosses the map band. Tapping it opens
## a compact, fully gameplay-earned reward in main.gd.

signal caught(reward: Dictionary)

const FLIGHT_TIME := 9.0
# More frequent than before (was 180–360s) so the golden drone — the main
# active-play surprise — comes around often enough to feel alive without spam.
const FIRST_WAIT_MIN := 60.0
const FIRST_WAIT_MAX := 110.0
const WAIT_MIN := 120.0
const WAIT_MAX := 240.0
const TRAIL_LEN := 8
const GRIFFIN_FLIGHT := preload("res://scripts/griffin_flight.gd")

const REWARDS := [
	{"kind": "boost", "label": "Ertrag ×2 für 3 Minuten"},
	{"kind": "cash",  "label": "+3 Minuten Handelsertrag"},
	{"kind": "gems",  "label": "+8 Edelsteine"},
]

# set by main.gd every frame (same band as the map)
var band_top := 150.0
var band_bottom := 760.0

var _btn: Button
var _shadow: TextureRect
var _glow: TextureRect
var _icon: TextureRect
var _wait := 0.0
var _flying := false
var _t := 0.0            # flight progress 0..1
var _clock := 0.0        # bob/pulse clock
var _from_left := true
var _fly_y := 0.5        # normalized y within the band
var _reward: Dictionary = {}
var _trail_hist: Array = []
var _is_jackpot := false
var _glow_base_a := 0.55
const JACKPOT_CHANCE := 0.05
const JACKPOT_REWARD := {"kind": "jackpot", "label": "JACKPOT! +30 Edelsteine + 5 Min."}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wait = randf_range(FIRST_WAIT_MIN, FIRST_WAIT_MAX)

	_btn = Button.new()
	_btn.flat = true
	_btn.custom_minimum_size = Vector2(96, 96)
	_btn.size = Vector2(96, 96)
	_btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	_btn.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
	_btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	_btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	_btn.visible = false
	_btn.pressed.connect(_on_tapped)
	add_child(_btn)

	# soft offset ground shadow — depth cue anchoring the drone to a ground
	# plane, matching how every fleet drone in map_view.gd gets one
	_shadow = TextureRect.new()
	_shadow.texture = _load_tex("sun_glow")
	_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shadow.stretch_mode = TextureRect.STRETCH_SCALE
	_shadow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shadow.modulate = Color(0.0, 0.0, 0.0, 0.28)
	_shadow.position += Vector2(0, 14)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_shadow)

	_glow = TextureRect.new()
	_glow.texture = _load_tex("sun_glow")
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.modulate = Color(1.0, 0.82, 0.25, 0.55)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_glow)
	_glow.pivot_offset = _glow.size * 0.5   # constant for the node's lifetime — was recomputed every frame

	_icon = GRIFFIN_FLIGHT.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 8; _icon.offset_right = -8
	_icon.offset_top = 8; _icon.offset_bottom = -8
	# Untinted: the generated griffin art already carries its golden palette; a warm tint on top of
	# it flattened the native artwork's own highlights/shading
	_icon.modulate = Color(1, 1, 1)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn.add_child(_icon)
	# The rare courier can be absent for minutes; pause its own frame clock too,
	# preserving the component's zero-work idle behaviour.
	_icon.set_process(false)

	# idle between flights (up to WAIT_MAX=360s) needs no per-frame work at
	# all — was ticking _process()/decrementing a counter at 60fps the whole
	# time. A one-shot timer replaces that; _process only runs during flight.
	set_process(false)
	_arm_next_spawn()

func _load_tex(n: String) -> Texture2D:
	var path := "res://assets/art/" + n + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _arm_next_spawn() -> void:
	get_tree().create_timer(_wait).timeout.connect(_spawn)

func _process(delta: float) -> void:
	_clock += delta
	_t += delta / FLIGHT_TIME
	if _t >= 1.0:
		_end_flight()
		return
	var rm: bool = Fx.reduce_motion
	var w := size.x
	var x := lerpf(-110.0, w + 110.0, _t) if _from_left else lerpf(w + 110.0, -110.0, _t)
	var bh := band_bottom - band_top
	var bob := (sin(_clock * 2.2) * 18.0) if not rm else 0.0
	var y := band_top + _fly_y * bh + bob
	_btn.position = Vector2(x - 48.0, y - 48.0)
	if not rm:
		var pulse := 1.0 + 0.10 * sin(_clock * 5.0)
		_glow.scale = Vector2(pulse, pulse)
		_icon.rotation = 0.10 * sin(_clock * 3.0) * (1.0 if _from_left else -1.0)
		# ground shadow fades as the drone bobs "up" — depth cue
		var lift := sin(_clock * 2.2) * 0.5 + 0.5
		_shadow.modulate.a = 0.28 * (1.0 - 0.45 * lift)
	# exit telegraph: blink the glow in the last ~1.5s so a distracted player
	# sees the reward is about to leave (steady fade if reduce_motion)
	if _t > 0.82:
		var blink: float = 1.0 if rm else (0.45 + 0.55 * abs(sin(_clock * 12.0)))
		_glow.modulate.a = _glow_base_a * blink
	else:
		_glow.modulate.a = _glow_base_a
	# squash/stretch takeoff/landing ease, matching map_view.gd's fleet-drone
	# dsc envelope — was an instant visible/full-scale pop with no ease at all
	var edge := minf(_t, 1.0 - _t)
	var dsc := clampf(edge / 0.15, 0.0, 1.0)
	_btn.pivot_offset = _btn.size * 0.5
	_btn.scale = Vector2(dsc, dsc)
	# fading motion trail, same pattern as map_view.gd's fleet-drone trails —
	# the bonus drone previously left no trail at all despite a 9s flight
	_trail_hist.append(_btn.position + _btn.size * 0.5)
	while _trail_hist.size() > TRAIL_LEN:
		_trail_hist.remove_at(0)
	queue_redraw()

func _draw() -> void:
	if _trail_hist.size() < 2:
		return
	for i in range(_trail_hist.size() - 1):
		var f := float(i) / float(_trail_hist.size())
		draw_line(_trail_hist[i], _trail_hist[i + 1], Color(1.0, 0.82, 0.25, 0.35 * f), 1.5 + 3.0 * f)

func _spawn() -> void:
	_flying = true
	_t = 0.0
	_clock = 0.0
	_trail_hist.clear()
	_from_left = randf() < 0.5
	# The painted sheet faces right; mirror it when the courier enters from the
	# opposite side instead of letting it fly backwards across the map.
	_icon.flip_h = not _from_left
	_fly_y = randf_range(0.18, 0.72)
	# rare JACKPOT variant — distinct violet-gold tint + bigger reward, the
	# surprise-and-delight spike that a flat 3-reward table never delivered
	_is_jackpot = randf() < JACKPOT_CHANCE
	if _is_jackpot:
		_reward = JACKPOT_REWARD
		_glow.modulate = Color(0.72, 0.5, 1.0, 0.85); _glow_base_a = 0.85
		_icon.modulate = Color(1.0, 0.95, 0.7)
	else:
		_reward = REWARDS[randi() % REWARDS.size()]
		_glow.modulate = Color(1.0, 0.82, 0.25, 0.55); _glow_base_a = 0.55
		_icon.modulate = Color(1, 1, 1)
	_btn.visible = true
	_icon.set_process(true)
	Fx.chip_pop(_btn, Color(0.8, 0.6, 1.0) if _is_jackpot else Color(1.0, 0.85, 0.3))
	# Audible and haptic cue so the rare courier isn't missed peripherally.
	Audio.play("daily", 1.35 if _is_jackpot else 1.15, -2.0)
	Fx.vibrate(45 if _is_jackpot else 30)
	set_process(true)

func _end_flight() -> void:
	_flying = false
	_btn.visible = false
	_icon.set_process(false)
	_trail_hist.clear()
	queue_redraw()
	set_process(false)
	_wait = randf_range(WAIT_MIN, WAIT_MAX)
	_arm_next_spawn()

func _on_tapped() -> void:
	if not _flying:
		return
	var reward := _reward
	_end_flight()
	caught.emit(reward)
