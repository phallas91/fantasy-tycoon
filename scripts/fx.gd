extends Node
## Fx — autoload visual-juice layer (Aurora Logistics premium feel).
##
## Reusable, pooled, self-freeing UI effects driven by the VISUAL_SPEC's
## animation_tokens. Every effect takes a `parent` Node so the caller controls
## layering; transient children animate via create_tween() and queue_free()
## themselves on completion. Degrades gracefully when particle textures are
## absent (falls back to draw / ColorRect) so it never crashes.
##
## NOTE: register as autoload "Fx" in project.godot (before GameState) — the
## integrator does this; this file does NOT self-register.

# ── Palette (mirrors UITheme so callers can pass either) ───────────────────────
const INK     := Color(0.95, 0.97, 1.00)
const MINT    := Color(0.13, 0.82, 0.48)
const GOLD    := Color(1.00, 0.78, 0.22)
const CYAN    := Color(0.22, 0.82, 0.95)
const VIOLET  := Color(0.62, 0.42, 1.00)
const AMBER   := Color(0.96, 0.65, 0.14)
const CORAL   := Color(1.00, 0.35, 0.37)
const WHITE   := Color(1, 1, 1)

# ── Token timings (animation_tokens) ──────────────────────────────────────────
const DUR_MICRO        := 0.10   # tap press-down / digit tick
const DUR_STANDARD     := 0.22   # panels / toasts / nav
const DUR_CELEBRATE    := 0.55   # city unlock / achievement / daily
const DUR_PRESTIGE     := 0.70   # full-screen ceremony
const PRESS_DOWN       := 0.06
const PRESS_RELEASE    := 0.13
const RING_EXPAND      := 0.48
const SHIMMER_SWEEP     := 0.30
const SPRING_OVERSHOOT := 1.06

# ── Concurrency caps (mobile-safe) ────────────────────────────────────────────
const MAX_LABELS    := 16
const MAX_PARTICLES := 8     # live CPUParticles2D emitters
const MAX_LIGHT_FX  := 60    # lightweight tweened Sprite2D/rect nodes (coin_fountain/confetti)

var reduce_motion := false
var haptics := true
var locale := ""   # "" = not explicitly chosen → device language (see apply_locale)
var _t := 0.0                # shared pulse_clock rhythm
var _live_labels := 0
var _live_particles := 0
var _live_light_fx := 0
var _tex_cache := {}         # filename -> Texture2D (or null if missing)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Runs before any save loads, so a fresh install still gets a sensible
	# locale immediately; from_dict() (once the save loads) applies the
	# player's explicit saved choice, if any — safe to call twice since
	# Godot live-retranslates every already-built Control on locale change.
	apply_locale()

func _process(delta: float) -> void:
	_t += delta

## Shared rhythm so coastline glow / beacon pulse / CTA breathing can align.
func pulse_clock() -> float:
	return _t

# ── Texture loading (graceful) ────────────────────────────────────────────────

func _tex(filename: String) -> Texture2D:
	if _tex_cache.has(filename):
		var cached = _tex_cache[filename]
		return cached as Texture2D
	var path := "res://assets/art/%s" % filename
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			tex = res
	_tex_cache[filename] = tex
	return tex

# ════════════════════════════════════════════════════════════════════════════
#  floating_label
# ════════════════════════════════════════════════════════════════════════════
## Pooled "+N" / reward label: springs up, drifts +y, fades. Capped to avoid spam.
func floating_label(parent: Node, text: String, color: Color, at_pos: Vector2, size := 24) -> void:
	if parent == null or _live_labels >= MAX_LABELS:
		return
	_live_labels += 1
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0.04, 0.06, 0.12, 0.7))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.position = at_pos
	lbl.z_index = 80
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(lbl)
	# center pivot on the REAL measured width (Poppins is proportional — the old
	# monospace guess size*len*0.25 made "+1.2M" spring in off-centre)
	var mw: float = UITheme.font("SemiBold").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	lbl.pivot_offset = Vector2(mw * 0.5, float(size) * 0.5)

	var rise: float = 56.0 if not reduce_motion else 32.0
	var dur: float = _scaled(0.9)
	lbl.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2.ONE, PRESS_RELEASE) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position:y", at_pos.y - rise, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN).set_delay(dur * 0.35)
	tw.chain().tween_callback(func() -> void:
		_live_labels -= 1
		if is_instance_valid(lbl):
			lbl.queue_free()
	)

# ════════════════════════════════════════════════════════════════════════════
#  burst
# ════════════════════════════════════════════════════════════════════════════
## Small hue-matched particle burst (spark/star/dot/coin/gem) rising + fading.
func burst(parent: Node, pos: Vector2, color: Color, count := 6, kind := "spark") -> void:
	if parent == null:
		return
	var n: int = count
	if reduce_motion:
		n = int(max(2, count / 2))
	if _live_particles >= MAX_PARTICLES:
		# fall back to a couple of cheap tweened dots rather than refusing entirely
		_dot_fallback(parent, pos, color, int(min(4, n)))
		return
	var tex := _tex(_kind_to_file(kind))
	if tex == null:
		_dot_fallback(parent, pos, color, n)
		return
	_live_particles += 1
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 70
	p.texture = tex
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = n
	p.lifetime = _scaled(0.7)
	p.direction = Vector2(0, -1)
	p.spread = 55.0
	p.gravity = Vector2(0, 380)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 220.0
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.color = color
	parent.add_child(p)
	_free_emitter_after(p, p.lifetime + 0.2)

func _dot_fallback(parent: Node, pos: Vector2, color: Color, n: int) -> void:
	for i in range(n):
		var ang: float = randf() * TAU
		var dist: float = randf_range(20.0, 60.0)
		var target := pos + Vector2(cos(ang), sin(ang)) * dist + Vector2(0, -30)
		var d := _make_dot(color, randf_range(4.0, 8.0))
		d.position = pos
		parent.add_child(d)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(d, "position", target, _scaled(0.55)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "modulate:a", 0.0, _scaled(0.55)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(d):
				d.queue_free()
		)

# ════════════════════════════════════════════════════════════════════════════
#  coin_fountain
# ════════════════════════════════════════════════════════════════════════════
## Erupt coins from `from` and arc them toward `to` (the credits chip).
func coin_fountain(parent: Node, from: Vector2, to: Vector2, count := 8) -> void:
	if parent == null:
		return
	# a coin fountain represents a bigger reward moment than a routine tap
	_vibrate(45)
	var n: int = count
	if reduce_motion:
		n = int(max(3, count / 2))
	var tex := _tex("coin.png")
	for i in range(n):
		if _live_light_fx >= MAX_LIGHT_FX:
			break
		_live_light_fx += 1
		var node: Node2D
		if tex != null:
			var s := Sprite2D.new()
			s.texture = tex
			node = s
		else:
			node = _make_dot(GOLD, 7.0)
		node.position = from
		node.z_index = 75
		parent.add_child(node)
		# arc: pop up then home to the chip, staggered
		var apex := from.lerp(to, 0.35) + Vector2(randf_range(-40, 40), -randf_range(60, 120))
		var delay: float = i * 0.035
		var up: float = _scaled(0.22)
		var home: float = _scaled(0.38)
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(node, "position", apex, up) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "position", to, home) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(node, "scale", Vector2(0.4, 0.4), home) \
			.set_delay(up * 0.3)
		tw.tween_callback(func() -> void:
			_live_light_fx -= 1
			if is_instance_valid(node):
				node.queue_free()
		)

# ════════════════════════════════════════════════════════════════════════════
#  confetti
# ════════════════════════════════════════════════════════════════════════════
## Celebratory confetti burst (rects + star/dot sprites) for city unlock etc.
func confetti(parent: Node, center: Vector2, count := 24, colors := []) -> void:
	if parent == null:
		return
	var cols: Array = colors
	if cols.is_empty():
		cols = [GOLD, CYAN, MINT, VIOLET, Color(1.0, 0.44, 0.71)]
	var n: int = count
	if reduce_motion:
		n = int(max(6, count / 3))
	var star := _tex("star.png")
	var dot := _tex("dot.png")
	for i in range(n):
		if _live_light_fx >= MAX_LIGHT_FX:
			break
		_live_light_fx += 1
		var col: Color = cols[i % cols.size()]
		var node: Node2D
		var pick := randi() % 3
		if pick == 0 and star != null:
			var s := Sprite2D.new(); s.texture = star; s.modulate = col; node = s
		elif pick == 1 and dot != null:
			var s2 := Sprite2D.new(); s2.texture = dot; s2.modulate = col; node = s2
		else:
			node = _make_rect(col, Vector2(randf_range(6, 12), randf_range(8, 16)))
		node.position = center
		node.z_index = 78
		node.rotation = randf() * TAU
		parent.add_child(node)
		var ang: float = -PI * 0.5 + randf_range(-1.2, 1.2)
		var speed: float = randf_range(160, 360)
		var apex := center + Vector2(cos(ang), sin(ang)) * speed
		var fall := apex + Vector2(randf_range(-60, 60), randf_range(220, 420))
		var t_up: float = _scaled(0.4)
		var t_down: float = _scaled(0.9)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(node, "position", apex, t_up) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "rotation", node.rotation + randf_range(-8, 8), t_up + t_down)
		tw.chain().tween_property(node, "position", fall, t_down) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(node, "modulate:a", 0.0, t_down) \
			.set_ease(Tween.EASE_IN).set_delay(t_down * 0.3)
		tw.chain().tween_callback(func() -> void:
			_live_light_fx -= 1
			if is_instance_valid(node):
				node.queue_free()
		)

# ════════════════════════════════════════════════════════════════════════════
#  ring_pulse
# ════════════════════════════════════════════════════════════════════════════
## One-shot expanding ring (ring_expand token) for unlock / confirm / beacon.
func ring_pulse(parent: Node, pos: Vector2, color: Color, max_scale := 2.0) -> void:
	if parent == null:
		return
	var tex := _tex("ring.png")
	var node: Node2D
	if tex != null:
		var s := Sprite2D.new()
		s.texture = tex
		s.modulate = color
		node = s
	else:
		node = _RingDraw.new()
		(node as _RingDraw).color = color
	node.position = pos
	node.z_index = 65
	node.scale = Vector2(0.3, 0.3)
	parent.add_child(node)
	var dur: float = _scaled(RING_EXPAND)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "scale", Vector2(max_scale, max_scale), dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "modulate:a", 0.0, dur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)

# ════════════════════════════════════════════════════════════════════════════
#  shimmer
# ════════════════════════════════════════════════════════════════════════════
## Slide a clipped white light-sweep across a Control (shimmer_sweep token).
## `looped` keeps it cadencing (~every 4s) for affordable or prestige-ready actions.
func shimmer(control: Control, color := Color.WHITE, looped := false) -> void:
	if control == null or not is_instance_valid(control):
		return
	if reduce_motion and looped:
		return
	var clip := Control.new()
	clip.name = "_FxShimmer"
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(clip)

	var sweep := ColorRect.new()
	sweep.color = Color(color.r, color.g, color.b, 0.16)
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(sweep)
	sweep.rotation_degrees = 18.0

	var run := func() -> void:
		var w: float = control.size.x
		var h: float = control.size.y
		sweep.size = Vector2(maxf(20.0, w * 0.35), h * 2.0)
		sweep.position = Vector2(-sweep.size.x, -h * 0.5)
		var to_x: float = w + sweep.size.x
		var tw := control.create_tween()
		tw.tween_property(sweep, "position:x", to_x, _scaled(SHIMMER_SWEEP)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if not looped:
		run.call()
		var life := control.create_tween()
		life.tween_interval(_scaled(SHIMMER_SWEEP) + 0.05)
		life.tween_callback(func() -> void:
			if is_instance_valid(clip):
				clip.queue_free()
		)
		return

	# looped: cadence every ~4s, until `control` itself is freed. The loop
	# callback used to call `run` unconditionally forever — if the caller's
	# button was later freed (popup closed, tab rebuilt, upgrade completed) the
	# next tick still tried to read control.size on a dead object, logging
	# "Lambda capture ... was freed" every ~4s for the rest of the run. Guard
	# each tick and kill the loop the first time it finds its target gone.
	var loop_tw := control.create_tween().set_loops()
	loop_tw.tween_callback(func() -> void:
		if not is_instance_valid(control) or not is_instance_valid(clip):
			loop_tw.kill()
			return
		# skip (not kill) while hidden — a rebuilt card may stay in the tree with
		# visible=false, so the loop would otherwise keep animating it
		# still ticking a sweep animation on an invisible control forever
		if not control.is_visible_in_tree():
			return
		run.call()
	)
	loop_tw.tween_interval(4.0)

# ════════════════════════════════════════════════════════════════════════════
#  screen_flash
# ════════════════════════════════════════════════════════════════════════════
## One-frame full-screen color flash (unlock / prestige / milestone).
func screen_flash(parent: Node, color: Color, peak_alpha := 0.12, dur := 0.08) -> void:
	if parent == null or reduce_motion:
		return
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 200
	if parent is Control:
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		rect.size = _viewport_size()
	parent.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", peak_alpha, dur * 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(rect, "color:a", 0.0, dur * 0.6) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(rect.queue_free)

# ════════════════════════════════════════════════════════════════════════════
#  screen_shake
# ════════════════════════════════════════════════════════════════════════════
## Decaying offset shake on a CanvasItem (country expand / prestige).
func screen_shake(target: CanvasItem, intensity := 6.0, dur := 0.22) -> void:
	if target == null or reduce_motion or not is_instance_valid(target):
		return
	var base_offset := Vector2.ZERO
	if target is Node2D:
		base_offset = (target as Node2D).position
	elif target is Control:
		base_offset = (target as Control).position
	var steps: int = 10
	var tw := create_tween()
	for i in range(steps):
		var decay: float = 1.0 - float(i) / float(steps)
		var off := base_offset + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * intensity * decay
		tw.tween_property(target, "position", off, dur / float(steps)) \
			.set_trans(Tween.TRANS_SINE)
	tw.tween_property(target, "position", base_offset, dur / float(steps))

# ════════════════════════════════════════════════════════════════════════════
#  chip_pop
# ════════════════════════════════════════════════════════════════════════════
## Squash-scale pop (1.0->1.18->1.0 ease_spring) when a HUD chip's value rises.
func chip_pop(chip: Control, color := Color.WHITE) -> void:
	if chip == null or not is_instance_valid(chip):
		return
	chip.pivot_offset = chip.size * 0.5
	var up: float = 1.18 if not reduce_motion else 1.08
	var tw := chip.create_tween()
	tw.tween_property(chip, "scale", Vector2(up, up), _scaled(0.09)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(chip, "scale", Vector2.ONE, _scaled(0.16)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not reduce_motion and color.a > 0.0:
		ring_pulse(chip, chip.size * 0.5, color, 1.6)

# ════════════════════════════════════════════════════════════════════════════
#  press
# ════════════════════════════════════════════════════════════════════════════
## Universal tactile press: scale-down + spring-back + brightness lift.
## Replaces the old _pulse(); used by every button.
func press(node: Control, affordable := true) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.pivot_offset = node.size * 0.5
	var down: float = 0.92 if affordable else 0.96
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2(down, down), PRESS_DOWN) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, PRESS_RELEASE) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if affordable and not reduce_motion:
		var lift := node.create_tween()
		lift.tween_property(node, "modulate", Color(1.06, 1.06, 1.06, 1.0), PRESS_DOWN)
		lift.tween_property(node, "modulate", Color.WHITE, PRESS_RELEASE)
	_vibrate(12)

# ════════════════════════════════════════════════════════════════════════════
#  error_shake
# ════════════════════════════════════════════════════════════════════════════
## Horizontal shake + brief Coral flash + error sfx for can't-afford taps.
func error_shake(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	if has_node("/root/Audio"):
		get_node("/root/Audio").play("error", 1.0, -4.0)
	var base_x: float = node.position.x
	if not reduce_motion:
		var amp := 6.0
		var tw := node.create_tween()
		for i in range(3):
			tw.tween_property(node, "position:x", base_x + amp, 0.04)
			tw.tween_property(node, "position:x", base_x - amp, 0.04)
		tw.tween_property(node, "position:x", base_x, 0.04) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# coral brightness flash
	var fl := node.create_tween()
	fl.tween_property(node, "modulate", CORAL, 0.06)
	fl.tween_property(node, "modulate", Color.WHITE, 0.18)
	_vibrate(60)   # error deserves a clear "nope" buzz

# ════════════════════════════════════════════════════════════════════════════
#  breathe
# ════════════════════════════════════════════════════════════════════════════
## Looping sine glow (glow_breathe token) on a CTA, tied to pulse rhythm.
## Stores the tween on the node so a later breathe(node, false) stops it.
func breathe(node: Control, on := true) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.has_meta("_fx_breathe"):
		var existing: Variant = node.get_meta("_fx_breathe")
		if existing is Tween and (existing as Tween).is_valid():
			(existing as Tween).kill()
		node.remove_meta("_fx_breathe")
	node.scale = Vector2.ONE
	if not on or reduce_motion:
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "scale", Vector2(1.03, 1.03), 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	node.set_meta("_fx_breathe", tw)

# ════════════════════════════════════════════════════════════════════════════
#  prestige_ceremony
# ════════════════════════════════════════════════════════════════════════════
## Full-screen dur_prestige sequence: violet dim -> radial bloom -> shockwave ->
## white-violet flash -> on_midpoint (swap state) -> staggered boot-in.
## Heavier FX gated by reduce_motion.
func prestige_ceremony(root: CanvasItem, on_midpoint: Callable) -> void:
	# dim overlay sits on a fresh CanvasLayer so it covers everything
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(VIOLET.r, VIOLET.g, VIOLET.b, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.size = _viewport_size()
	layer.add_child(dim)

	var center := _viewport_size() * 0.5
	var dur: float = _scaled(DUR_PRESTIGE)

	var tw := create_tween()
	# 1. violet dim in
	tw.tween_property(dim, "color:a", 0.55, dur * 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# 2. radial bloom + shockwave at midpoint
	tw.tween_callback(func() -> void:
		ring_pulse(dim, center, VIOLET, 3.0)
		if not reduce_motion:
			burst(dim, center, Color(1.0, 0.44, 0.71), 12, "star")
		screen_flash(layer, WHITE.lerp(VIOLET, 0.4), 0.22, 0.16)
		_vibrate(100)   # prestige is the biggest moment — long celebratory buzz
		if on_midpoint.is_valid():
			on_midpoint.call()
	)
	# 3. hold for the boot-in beat
	tw.tween_interval(dur * 0.25)
	# 4. dim out (UI cascades back underneath)
	tw.tween_property(dim, "color:a", 0.0, dur * 0.4) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(layer.queue_free)

# ════════════════════════════════════════════════════════════════════════════
#  set_reduce_motion
# ════════════════════════════════════════════════════════════════════════════
## Global accessibility toggle: damps loops, halves durations, kills heavy FX.
func set_reduce_motion(enabled: bool) -> void:
	reduce_motion = enabled

func to_dict() -> Dictionary:
	return {"reduce_motion": reduce_motion, "haptics": haptics, "locale": locale}

func from_dict(d: Dictionary) -> void:
	reduce_motion = bool(d.get("reduce_motion", false))
	haptics = bool(d.get("haptics", true))
	locale = str(d.get("locale", ""))
	apply_locale()

## Applies `locale`, auto-detecting from the device language on first launch.
## Unsupported languages fall back to English; an explicit settings choice is
## always preserved. This prevents German systems from being forced back to EN
## immediately after main.gd built its already-German interface.
func apply_locale() -> void:
	var eff := locale
	if eff == "":
		eff = OS.get_locale_language().substr(0, 2)
		if eff not in ["pt", "en", "es", "fr", "de", "it", "ru", "ja", "zh"]:
			eff = "en"
	TranslationServer.set_locale(eff)

func set_locale(l: String) -> void:
	locale = l
	apply_locale()

# ── Internal helpers ───────────────────────────────────────────────────────────

func _scaled(dur: float) -> float:
	return dur * 0.5 if reduce_motion else dur

func _vibrate(ms: int) -> void:
	if not haptics:
		return
	if OS.has_feature("mobile"):
		# Floor at 25ms and request FULL amplitude. The old sub-20ms pulses
		# (12ms taps, 20ms) are imperceptible on most phones — the vibrator
		# barely spins up — which is why haptics felt like "it never vibrates"
		# even though the API was firing and the VIBRATE permission is present.
		Input.vibrate_handheld(maxi(ms, 25), 1.0)

## Public one-shot haptic pulse for callers outside Fx (e.g. main.gd's country
## expansion celebration) — same guard/behavior as the internal helper above.
func vibrate(ms: int) -> void:
	_vibrate(ms)

func _kind_to_file(kind: String) -> String:
	match kind:
		"star":  return "star.png"
		"dot":   return "dot.png"
		"coin":  return "coin.png"
		"gem":   return "gem_particle.png"
		_:       return "spark.png"

func _viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp:
		return vp.get_visible_rect().size
	return Vector2(720, 1280)

func _free_emitter_after(p: CPUParticles2D, secs: float) -> void:
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(func() -> void:
		_live_particles -= 1
		if is_instance_valid(p):
			p.queue_free()
	)

func _make_dot(color: Color, radius: float) -> Node2D:
	var d := _Dot.new()
	d.color = color
	d.radius = radius
	return d

func _make_rect(color: Color, sz: Vector2) -> Node2D:
	var r := _Rect.new()
	r.color = color
	r.rect_size = sz
	return r

# ── Tiny self-drawing fallback primitives (used when textures missing) ─────────

class _Dot extends Node2D:
	var color := Color.WHITE
	var radius := 6.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)

class _Rect extends Node2D:
	var color := Color.WHITE
	var rect_size := Vector2(8, 12)
	func _draw() -> void:
		draw_rect(Rect2(-rect_size * 0.5, rect_size), color)

class _RingDraw extends Node2D:
	var color := Color.WHITE
	func _draw() -> void:
		# base radius 30 at scale 1.0; engine scales the node 0.3 -> max
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 48, color, 4.0, true)
