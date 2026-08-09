extends Control
class_name ArcaneMapView
## Premium arcane trade map. Draws each realm with routes, couriers and hubs.
## original realm silhouettes, authored city layouts (capital / active / locked),
## flowing route lanes and delivery drones with trails. Reads GameState/Economy.
## mouse_filter IGNORE, draws via _draw()/queue_redraw(). Performant for mobile.

signal city_selected(index: int)

# --- public API (set every frame by main.gd) ---
var band_top := 150.0
var band_bottom := 760.0

# --- zoom / pan (pinch + drag) ---
var zoom := 1.0
var pan := Vector2.ZERO
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
var _touches: Dictionary = {}      # touch index -> position
var _last_pinch := 0.0

# --- shared pulse clock ---
var _t := 0.0

# --- resources ---
var _font: Font
var _drone_tex: Array = []
var _griffin_flight_sheet: Texture2D
var _package: Texture2D
var _cloud: Texture2D
var _hub_home: Texture2D
var _hub_city: Texture2D
var _hub_city2: Texture2D
var _sea_tex: GradientTexture2D
var _realm_bg: Texture2D
var _vig_top: GradientTexture2D
var _vig_bottom: GradientTexture2D
var _vig_left: GradientTexture2D
var _vig_right: GradientTexture2D
var _land_grad: GradientTexture2D
var _grid_tile: Texture2D
var _coin: Texture2D
var _lock: Texture2D
var _sun: Texture2D
var _aurora: Texture2D

# --- projection fit + cinematic camera ---
var _bbox := Rect2(0, 0, 1, 1)
var _outline_cache: PackedVector2Array = PackedVector2Array()
var _bbox_ci := -1   # country the bbox/outline was last computed for (self-heals on load)
var _deliver_seen := 0   # throttles beacon flashes to perceived drone-arrival rate
var _tap_start_pos := Vector2.ZERO
var _tap_start_ms := 0
var _cam_tween: Tween

# --- landmass geometry cache (rebuilt only when zoom/pan actually change) ---
var _lm_zoom := -1.0
var _lm_pan := Vector2(INF, INF)
var _lm_pts: PackedVector2Array
var _lm_sh: PackedVector2Array
var _lm_closed: PackedVector2Array
var _lm_inner: PackedVector2Array
var _lm_grid_uvs: PackedVector2Array
var _lm_land_uvs: PackedVector2Array
# draw_colored_polygon() re-runs Geometry2D.triangulate_polygon() on EVERY call —
# ear-clipping an ~98-140pt concave outline, 3x per frame, purely to re-derive an
# identical result. Triangulate once here and feed the indices straight to
# RenderingServer instead.
var _lm_idx: PackedInt32Array
var _lm_land_cols: PackedColorArray
var _lm_grid_cols: PackedColorArray
var _lm_sh_cols: PackedColorArray
# One draw call for all the vertex ticks instead of one per vertex: draw_circle
# emits a non-batchable CommandPolygon each, so 140 verts = 140 draw calls/frame.
var _tick_pts: PackedVector2Array
var _tick_uvs: PackedVector2Array
var _tick_idx: PackedInt32Array
var _tick_cols: PackedColorArray
var _dot: ImageTexture
# Rounded frosted backing for the map's text chips. draw_rect() can't round
# corners, so the city-name and cost chips were the only hard-90° rectangles in
# an otherwise fully rounded, glassmorphic UI — they read as debug boxes. One
# shared StyleBoxFlat drawn via draw_style_box() joins them to the R_CHIP system;
# border_color is mutated per call (gold for cost/capital, tinted for cities).
var _chip_sb: StyleBoxFlat

# --- misc caches ---
var _next_cost_str := ""
var _text_width_cache: Dictionary = {}

# --- transient state ---
var _pops: Array = []                 # floating "+credits" labels
var _trails: Dictionary = {}          # drone index -> Array[Vector2] (recent positions)
var _clouds: Array = []               # decorative drifting clouds (parallax)
var _stars: Array = []                # faint ambient star/dust field
var _caustics: Array = []             # animated sea shimmer blobs
var _flash: Dictionary = {}           # city_index -> remaining flash time on delivery
var _city_growth: Dictionary = {}     # city_index -> remaining build reveal time
var _investment_signature := ""
var _investment_reveal := 0.0

# --- Arcane Trade Empire palette ---
const VOID      := Color(0.025, 0.016, 0.035)
const MIDNIGHT  := Color(0.075, 0.043, 0.105)
const SEA_TOP   := Color(0.045, 0.025, 0.080)
const SEA_BOT   := Color(0.105, 0.055, 0.145)
const LAND      := Color(0.155, 0.105, 0.180)
const LAND_HI   := Color(0.265, 0.175, 0.315)
const INK       := Color(0.969, 0.941, 0.875)
const MUTED     := Color(0.650, 0.590, 0.680)
const SKY       := Color(0.608, 0.333, 0.780)
const CYAN      := Color(0.255, 0.765, 0.780)
const GOLD      := Color(0.941, 0.737, 0.345)
const MINT      := Color(0.275, 0.780, 0.576)
const SHADOW    := Color(0.025, 0.012, 0.035)

const TRAIL_LEN := 8

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # receives pinch/drag in its visible band
	_font = UITheme.font("Bold")
	_drone_tex = [load("res://assets/art/griffin_violet.png"), load("res://assets/art/griffin_teal.png"), load("res://assets/art/griffin_gold.png")]
	_griffin_flight_sheet = load("res://assets/art/generated/griffin_flight_sheet.png")
	_package = load("res://assets/art/package.png")
	_cloud = load("res://assets/art/cloud.png")
	_hub_home = load("res://assets/art/generated/arcane_capital_hub_v2.png")
	_hub_city = load("res://assets/art/generated/arcane_city_hub_v2.png")
	_hub_city2 = load("res://assets/art/generated/arcane_locked_hub_v2.png")
	_grid_tile = load("res://assets/art/grid_tile.png")
	_dot = _make_dot_tex()
	_chip_sb = StyleBoxFlat.new()
	_chip_sb.set_corner_radius_all(UITheme.R_CHIP)
	_chip_sb.content_margin_left = 10.0; _chip_sb.content_margin_right = 10.0
	_chip_sb.content_margin_top = 3.0; _chip_sb.content_margin_bottom = 3.0
	_chip_sb.set_border_width_all(1)
	_chip_sb.border_width_top = 2   # frosted top rim, matches UITheme pills
	_coin = load("res://assets/art/coin.png")
	_lock = load("res://assets/art/ic_lock.png")
	_sun = load("res://assets/art/sun_glow.png")
	_aurora = load("res://assets/art/aurora_band.png")
	_realm_bg = load("res://assets/fantasy/arcane_city_world_v1.webp")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # lets the holo grid tile
	GameState.delivered.connect(_on_delivered)
	GameState.country_changed.connect(_on_country_changed_visual)
	# cached sea gradient (replaces 40 draw_rect calls per frame)
	var sg := Gradient.new()
	sg.set_color(0, SEA_TOP); sg.set_color(1, SEA_BOT)
	_sea_tex = GradientTexture2D.new()
	_sea_tex.gradient = sg
	_sea_tex.fill_from = Vector2(0, 0); _sea_tex.fill_to = Vector2(0, 1)
	_sea_tex.width = 4; _sea_tex.height = 256
	# cached vignette edge-fade textures (replaces 32 draw_rect calls/frame)
	_vig_top = _edge_gradient_tex(false)
	_vig_bottom = _edge_gradient_tex(true)
	_vig_left = _edge_gradient_tex(false, true)
	_vig_right = _edge_gradient_tex(true, true)
	# cached vertical land gradient (replaces a 2nd flat inner-shrink polygon)
	var lg := Gradient.new()
	lg.set_color(0, LAND_HI); lg.set_color(1, LAND)
	_land_grad = GradientTexture2D.new()
	_land_grad.gradient = lg
	_land_grad.fill_from = Vector2(0, 0); _land_grad.fill_to = Vector2(0, 1)
	_land_grad.width = 4; _land_grad.height = 128
	_seed_ambiance()
	_recalc_bbox()
	GameState.city_unlocked.connect(_on_city_unlocked_visual)
	_refresh_next_cost()
	set_process(true)

## Solid round dot used to render the outline vertex ticks as one batched
## triangle array. Built here rather than reusing assets/art/dot.png — that one is
## a RING (alpha ~205 at the rim, 8 in the centre), so it rendered the ticks as
## faint hollow specks instead of the filled draw_circle() blobs they replace.
## 16px with a 1px smooth edge, drawn down to ~4px: reads as a round dot.
func _make_dot_tex() -> ImageTexture:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (float(n) - 1.0) * 0.5
	var r := c - 0.5
	for y in range(n):
		for x in range(n):
			var d := Vector2(float(x) - c, float(y) - c).length()
			var a := clampf(r - d + 0.5, 0.0, 1.0)   # 1px antialiased falloff
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## Small cached alpha-fade texture for a screen edge vignette band. `reverse`
## puts the opaque end at position 1 instead of 0 (bottom/right edges fade the
## opposite direction from top/left). `horizontal` fades left<->right instead
## of top<->bottom. Replaces the old per-frame 8-iteration x 4-rect loop.
func _edge_gradient_tex(reverse: bool, horizontal := false) -> GradientTexture2D:
	var g := Gradient.new()
	var opaque := Color(VOID.r, VOID.g, VOID.b, 0.42)
	var clear := Color(VOID.r, VOID.g, VOID.b, 0.0)
	g.set_color(0, clear if reverse else opaque)
	g.set_color(1, opaque if reverse else clear)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	if horizontal:
		tex.fill_from = Vector2(0, 0); tex.fill_to = Vector2(1, 0)
		tex.width = 64; tex.height = 8
	else:
		tex.fill_from = Vector2(0, 0); tex.fill_to = Vector2(0, 1)
		tex.width = 8; tex.height = 64
	return tex

## Cached "next city" unlock cost string — recomputed only when it can
## actually change (unlock/expand), not every frame from _draw_cities().
func _refresh_next_cost() -> void:
	var ci := GameState.current_country
	_next_cost_str = Fmt.short(Economy.city_unlock_cost(ci, GameState.cities_unlocked))

## Memoized text-width measurement (city/cost labels repeat every frame while
## on screen but rarely change) — avoids re-measuring the same string+size.
func _measure(text: String, font_size: int) -> float:
	var key := text + "@" + str(font_size)
	if _text_width_cache.has(key):
		return _text_width_cache[key]
	var w: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	_text_width_cache[key] = w
	return w

## Bounding box of the current country's outline + cities (map space), so the
## projection fills the band instead of assuming the full unit square.
func _recalc_bbox() -> void:
	var ci := GameState.current_country
	_outline_cache = Economy.country_outline(ci)
	var pts := _outline_cache
	var cities := Economy.country_cities(ci)
	if pts.is_empty() and cities.is_empty():
		_bbox = Rect2(0, 0, 1, 1)
		return
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for p in pts:
		minp = minp.min(p); maxp = maxp.max(p)
	for c in cities:
		var cp := Vector2(c["x"], c["y"])
		minp = minp.min(cp); maxp = maxp.max(cp)
	var r := Rect2(minp, maxp - minp)
	if r.size.x < 0.001 or r.size.y < 0.001:
		r = Rect2(0, 0, 1, 1)
	_bbox = r
	_bbox_ci = ci

func _reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	_touches.clear()
	_last_pinch = 0.0

func _seed_ambiance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# 3 parallax clouds: depth in {0=far,1=mid,2=near} affects speed/scale/alpha
	for i in range(3):
		_clouds.append({
			"x": rng.randf(),
			"y": rng.randf_range(0.05, 0.45),
			"depth": i,
			"speed": 0.006 + float(i) * 0.006,
			"scale": 1.6 + float(i) * 0.5,
		})
	# faint star/dust field (normalized coords, slow upward drift)
	for _i in range(14):
		_stars.append({
			"x": rng.randf(),
			"y": rng.randf(),
			"r": rng.randf_range(0.8, 2.0),
			"ph": rng.randf() * TAU,
			"sp": rng.randf_range(0.01, 0.025),
		})
	# sea caustic shimmer blobs
	for _i in range(7):
		_caustics.append({
			"x": rng.randf(),
			"y": rng.randf_range(0.35, 0.95),
			"r": rng.randf_range(28.0, 64.0),
			"ph": rng.randf() * TAU,
			"sp": rng.randf_range(0.4, 0.9),
		})

func _process(delta: float) -> void:
	# reduce_motion freezes the ambient sine clock (caustics / scanline / star
	# twinkle / coastline breathe / aurora drift / drone bob) — a stated
	# accessibility constraint the map previously ignored. Functional motion
	# (drone travel via vt, pops, flashes, camera, self-heal) keeps running.
	if not Fx.reduce_motion:
		_t += delta
	# Self-heal a stale country: loading a save sets GameState.current_country
	# but emits no country_changed, so the bbox/outline cached at _ready() (for
	# Portugal, country 0) would keep drawing the wrong map until the next
	# expand. Detect the mismatch and re-fit here so a returning player sees the
	# correct country immediately.
	if GameState.current_country != _bbox_ci:
		# only _recalc_bbox (fixes the outline/fit) + cost — NOT _reset_view: zoom/
		# pan aren't persisted (already default on load) and resetting them here
		# would stomp the boot intro's zoom-in tween on the first frame.
		_recalc_bbox(); _refresh_next_cost()
	var investment_signature := "%d:%d:%d:%d" % [
		int(GameState.levels.get("speed", 0)), int(GameState.levels.get("cargo", 0)),
		int(GameState.levels.get("value", 0)), int(GameState.levels.get("routes", 0))]
	if _investment_signature.is_empty():
		_investment_signature = investment_signature
	elif investment_signature != _investment_signature:
		_investment_signature = investment_signature
		if not Fx.reduce_motion:
			_investment_reveal = 0.9
	if _investment_reveal > 0.0:
		_investment_reveal = maxf(0.0, _investment_reveal - delta)
	# advance floating pops (mutate in place; skip entirely when idle — the
	# common case outside the few seconds right after a delivery/unlock)
	if not _pops.is_empty():
		for i in range(_pops.size() - 1, -1, -1):
			var p: Dictionary = _pops[i]
			p["life"] = float(p["life"]) - delta
			p["y"] = float(p["y"]) - 34.0 * delta
			if float(p["life"]) <= 0.0:
				_pops.remove_at(i)
	# drift clouds (wrap) — ambient, frozen under reduce_motion
	if not Fx.reduce_motion:
		for c in _clouds:
			c["x"] += c["speed"] * delta
			if c["x"] > 1.25:
				c["x"] = -0.25
	# decay delivery flashes (mutate in place; skip when nothing is flashing)
	if not _flash.is_empty():
		var expired: Array = []
		for key: int in _flash:
			var rem: float = float(_flash[key]) - delta
			if rem > 0.0:
				_flash[key] = rem
			else:
				expired.append(key)
		for key in expired:
			_flash.erase(key)
	# A newly unlocked settlement rises from the map instead of appearing as a
	# static icon. Functional state is already committed by GameState; this is a
	# short, purely visual reveal and remains frozen when reduce-motion is active.
	if not _city_growth.is_empty():
		var finished: Array = []
		for key: int in _city_growth:
			var rem: float = float(_city_growth[key]) - delta
			if rem > 0.0:
				_city_growth[key] = rem
			else:
				finished.append(key)
		for key in finished:
			_city_growth.erase(key)
	queue_redraw()

func _band_ctr() -> Vector2:
	return Vector2(size.x * 0.5, band_top + (band_bottom - band_top) * 0.5)

## Projection without zoom/pan: fits the country bbox to the band (uniform scale).
func _base_proj(p: Vector2) -> Vector2:
	var bw := size.x
	var bh := band_bottom - band_top
	var s: float = minf(bw / _bbox.size.x, bh / _bbox.size.y) * 0.86
	return _band_ctr() + (p - _bbox.get_center()) * s

func _proj(p: Vector2) -> Vector2:
	var ctr := _band_ctr()
	return ctr + (_base_proj(p) - ctr) * zoom + pan

## Cinematic punch-in on a just-unlocked city, then ease back out.
func focus_city(idx: int) -> void:
	if Fx.reduce_motion or not _touches.is_empty():
		return
	var cities := Economy.country_cities(GameState.current_country)
	if idx < 0 or idx >= cities.size():
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	var pt := Vector2(cities[idx]["x"], cities[idx]["y"])
	var tz := 1.8
	var tp := -(_base_proj(pt) - _band_ctr()) * tz
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(self, "zoom", tz, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(self, "pan", tp, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.chain().tween_interval(0.7)
	_cam_tween.chain().tween_property(self, "zoom", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(self, "pan", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Zoom-out reveal when arriving in a new country.
func reveal_country() -> void:
	if Fx.reduce_motion:
		return
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	zoom = 2.2
	var cities := Economy.country_cities(GameState.current_country)
	if not cities.is_empty():
		var pt := Vector2(cities[0]["x"], cities[0]["y"])
		pan = -(_base_proj(pt) - _band_ctr()) * zoom
	_cam_tween = create_tween()
	_cam_tween.set_parallel(true)
	_cam_tween.tween_property(self, "zoom", 1.0, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_tween.tween_property(self, "pan", Vector2.ZERO, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- input (zoom/pan)

## Cheap tap feedback so the play area feels responsive between purchases.
func _tap_ripple(pos: Vector2) -> void:
	Audio.play("tap")
	if not Fx.reduce_motion:
		Fx.ring_pulse(self, pos, Color(SKY.r, SKY.g, SKY.b, 0.9), 1.5)

func _gui_input(event: InputEvent) -> void:
	# any interaction cancels the cinematic camera — the player always wins
	if _cam_tween != null and _cam_tween.is_valid():
		if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton:
			_cam_tween.kill()
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() == 1:
				_tap_start_pos = t.position
				_tap_start_ms = Time.get_ticks_msec()
		else:
			var was_single: bool = _touches.size() == 1
			_touches.erase(t.index)
			if _touches.size() < 2:
				_last_pinch = 0.0
			# quick tap (no drag, no pinch) → responsive ripple + tick
			if was_single and t.position.distance_to(_tap_start_pos) < 14.0 \
					and Time.get_ticks_msec() - _tap_start_ms < 250:
				_tap_ripple(t.position)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var ks := _touches.keys()
			var a: Vector2 = _touches[ks[0]]
			var b: Vector2 = _touches[ks[1]]
			var dist := a.distance_to(b)
			if _last_pinch > 0.0 and dist > 0.0:
				_zoom_at(zoom * (dist / _last_pinch), (a + b) * 0.5)
			_last_pinch = dist
		else:
			pan += d.relative
			_clamp_pan()
		accept_event()
	elif event is InputEventMouseButton:
		if not _touches.is_empty():
			return
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(zoom * 1.12, mb.position); accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(zoom / 1.12, mb.position); accept_event()
	elif event is InputEventMouseMotion:
		if not _touches.is_empty():
			return
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			pan += mm.relative
			_clamp_pan()
			accept_event()

func _zoom_at(target: float, focus: Vector2) -> void:
	var old := zoom
	zoom = clampf(target, ZOOM_MIN, ZOOM_MAX)
	var ctr := Vector2(size.x * 0.5, band_top + (band_bottom - band_top) * 0.5)
	# keep the focus point stationary on screen
	pan = pan - (focus - ctr - pan) * (zoom / old - 1.0)
	if zoom <= ZOOM_MIN + 0.001:
		zoom = ZOOM_MIN
		pan = Vector2.ZERO
	_clamp_pan()

func _clamp_pan() -> void:
	var bh := band_bottom - band_top
	var mx := size.x * 0.5 * (zoom - 1.0) + 80.0
	var my := bh * 0.5 * (zoom - 1.0) + 80.0
	pan.x = clampf(pan.x, -mx, mx)
	pan.y = clampf(pan.y, -my, my)

func _draw() -> void:
	var w := size.x
	var h := band_bottom - band_top
	_draw_sea(w, h)
	_draw_horizon_light(w, h)

	var ci := GameState.current_country

	var cities := Economy.country_cities(ci)
	# The authored city panorama is now the world itself. The former polygon,
	# survey grid and procedural terrain remain as a fallback for missing assets,
	# but must never cover the premium illustration in a normal build.
	if _realm_bg == null:
		_draw_grid(w, h)
		_draw_caustics(w, h)
		_draw_landmass(_outline_cache)
		_draw_realm_details(_outline_cache, cities, ci)
	if cities.is_empty():
		# clouds/stars drift ABOVE land/routes (below only the vignette), so
		# the parallax depth cue reads instead of vanishing under the landmass
		_draw_clouds(w, h)
		_draw_stars(w, h)
		_draw_vignette(w, h)
		_draw_pops()
		return

	var cap := _proj(Vector2(cities[0]["x"], cities[0]["y"]))
	var route_geom := _draw_routes(cap, cities)
	_draw_ground_traffic(cap, route_geom)
	_draw_drones(cap, cities, route_geom)
	_draw_cities(cap, cities, ci)
	_draw_clouds(w, h)
	_draw_stars(w, h)
	_draw_vignette(w, h)
	_draw_pops()

# ---------------------------------------------------------------- background

func _draw_sea(w: float, h: float) -> void:
	# Painterly realm texture gives the route simulation a real fantasy world.
	if _realm_bg != null:
		# The landscape panorama spans behind HUD, side panel and navigation just
		# like a premium strategy-game world scene; interactive map content still
		# uses the safe band between HUD and navigation.
		draw_texture_rect(_realm_bg, Rect2(0, 0, w, size.y), false, Color.WHITE)
	# translucent arcane tint keeps labels and glowing routes readable.
	var cyc := 0.5 + 0.5 * sin(_t * 0.05)
	var tint_alpha := 0.07 if _realm_bg != null else 0.26
	var tint := Color(0.22, 0.10, 0.30, tint_alpha).lerp(Color(0.08, 0.24, 0.28, tint_alpha * 0.8), cyc)
	draw_texture_rect(_sea_tex, Rect2(0, band_top, w, h), false, tint)

## Warm sun glow at top-right + slowly drifting aurora ribbon on the horizon —
## the light source that gives the scene contrast against the cyan coast.
func _draw_horizon_light(w: float, _h: float) -> void:
	if _sun != null:
		draw_texture_rect(_sun, Rect2(w - 300.0, band_top - 60.0, 360.0, 360.0), false, Color(1.0, 0.72, 0.35, 0.16))
	if _aurora != null:
		var drift := sin(_t * 0.07) * 40.0
		draw_texture_rect(_aurora, Rect2(-60.0 + drift, band_top, w + 120.0, 90.0), false, Color(1, 1, 1, 0.22))

func _draw_grid(w: float, h: float) -> void:
	# perspective dot/line grid converging toward a horizon near band_top —
	# batched into 2 draw_multiline() calls instead of 21 separate draw_line()
	# calls, and the vertical line color is built once instead of per-segment.
	var line := Color(0.62, 0.40, 0.74, 0.055)   # faint enchanted cartography grid
	var horizon := band_top + h * 0.06
	# horizontal lines compressing upward
	var hpts := PackedVector2Array()
	for i in range(1, 11):
		var f := float(i) / 11.0
		var y := horizon + (band_bottom - horizon) * (f * f)
		hpts.append(Vector2(0, y)); hpts.append(Vector2(w, y))
	draw_multiline(hpts, line, 1.0)
	# converging verticals toward a vanishing point
	var vp := Vector2(w * 0.5, horizon)
	var vline := Color(line.r, line.g, line.b, 0.07)
	var vpts := PackedVector2Array()
	for i in range(0, 11):
		var bx := w * float(i) / 10.0
		vpts.append(Vector2(bx, band_bottom)); vpts.append(vp.lerp(Vector2(bx, band_bottom), 0.18))
	draw_multiline(vpts, vline, 1.0)
	# slow downward scanline band (live-console vibe)
	var sweep := fmod(_t * 0.10, 1.0)
	var sy := band_top + h * sweep
	draw_rect(Rect2(0, sy, w, 26.0), Color(CYAN.r, CYAN.g, CYAN.b, 0.04))

func _draw_caustics(w: float, h: float) -> void:
	for c in _caustics:
		var px := float(c["x"]) * w
		var py := band_top + float(c["y"]) * h
		var pulse: float = 0.5 + 0.5 * sin(_t * float(c["sp"]) + float(c["ph"]))
		var a := 0.018 + 0.022 * pulse
		var r: float = float(c["r"]) * (0.85 + 0.15 * pulse)
		draw_circle(Vector2(px, py), r, Color(SKY.r, SKY.g, SKY.b, a))

func _draw_clouds(w: float, h: float) -> void:
	if _cloud == null:
		return
	var cs := Vector2(_cloud.get_width(), _cloud.get_height())
	for c in _clouds:
		var sc: float = float(c["scale"])
		var dim := cs * sc
		var px := float(c["x"]) * (w + dim.x) - dim.x * 0.5
		var py := band_top + float(c["y"]) * h
		var depth: int = int(c["depth"])
		var alpha := 0.05 + 0.03 * float(depth)
		draw_texture_rect(_cloud, Rect2(px, py, dim.x, dim.y), false, Color(0.62, 0.78, 1.0, alpha))

func _draw_stars(w: float, h: float) -> void:
	for s in _stars:
		var drift := fmod(float(s["y"]) - _t * float(s["sp"]), 1.0)
		if drift < 0.0:
			drift += 1.0
		var px := float(s["x"]) * w
		var py := band_top + drift * h
		var tw: float = 0.4 + 0.6 * (0.5 + 0.5 * sin(_t * 1.4 + float(s["ph"])))
		draw_circle(Vector2(px, py), float(s["r"]), Color(CYAN.r, CYAN.g, CYAN.b, 0.18 * tw))

func _draw_vignette(w: float, h: float) -> void:
	# soft edge framing via 4 cached-gradient texture bands — was 8 iterations
	# x 4 draw_rect() calls (32 draws) plus 8 Color allocations every frame.
	var band := 42.0
	draw_texture_rect(_vig_top, Rect2(0, band_top, w, band), false)
	draw_texture_rect(_vig_bottom, Rect2(0, band_top + h - band, w, band), false)
	draw_texture_rect(_vig_left, Rect2(0, band_top, band, h), false)
	draw_texture_rect(_vig_right, Rect2(w - band, band_top, band, h), false)

# ---------------------------------------------------------------- landmass

func _draw_landmass(outline: PackedVector2Array) -> void:
	if outline.size() < 3:
		return
	# Geometry (projected points, shadow offset, closed outline, inner-light
	# shrink, grid/gradient UVs) only actually changes when the camera moves
	# (zoom/pan) or the outline itself changes — not while the player is just
	# watching the map sit still, the common idle-game case. Rebuild only then.
	if zoom != _lm_zoom or pan != _lm_pan or _lm_pts.size() != outline.size():
		_lm_zoom = zoom; _lm_pan = pan
		_lm_pts = PackedVector2Array()
		for p in outline:
			_lm_pts.append(_proj(p))
		# shadow offset scales with zoom so the landmass "lift" reads consistently
		# instead of collapsing when pinch-zoomed in (the outline scales, so must
		# its shadow). sqrt keeps the ramp subtle.
		var sh_off := Vector2(5, 9) * sqrt(zoom)
		_lm_sh = PackedVector2Array()
		for q in _lm_pts:
			_lm_sh.append(q + sh_off)
		_lm_closed = _lm_pts.duplicate()
		_lm_closed.append(_lm_pts[0])
		var ctr := _centroid(_lm_pts)
		_lm_inner = PackedVector2Array()
		for q in _lm_pts:
			_lm_inner.append(q.lerp(ctr, 0.10))
		_lm_grid_uvs = PackedVector2Array()
		for q in _lm_pts:
			_lm_grid_uvs.append(q / 64.0)
		# gradient UVs: v=0 at the landmass's screen-space top, v=1 at bottom,
		# so the single cached vertical LAND_HI->LAND texture reads correctly
		# regardless of zoom/pan (replaces a 2nd flat inner-shrink fill poly)
		var min_y := INF; var max_y := -INF
		for q in _lm_pts:
			min_y = minf(min_y, q.y); max_y = maxf(max_y, q.y)
		var yr := maxf(1.0, max_y - min_y)
		_lm_land_uvs = PackedVector2Array()
		for q in _lm_pts:
			_lm_land_uvs.append(Vector2(0.5, (q.y - min_y) / yr))
		# triangulate once (see _lm_idx). _lm_sh is _lm_pts + a constant offset,
		# so it shares the same topology.
		_lm_idx = Geometry2D.triangulate_polygon(_lm_pts)
		_lm_land_cols = PackedColorArray(); _lm_land_cols.resize(_lm_pts.size())
		_lm_grid_cols = PackedColorArray(); _lm_grid_cols.resize(_lm_pts.size())
		_lm_sh_cols = PackedColorArray(); _lm_sh_cols.resize(_lm_sh.size())
		# tick quads: 4 verts + 6 indices per outline vertex, textured with the round
		# dot.png so they render the same as the draw_circle() they replace
		_tick_pts = PackedVector2Array(); _tick_uvs = PackedVector2Array()
		_tick_idx = PackedInt32Array()
		for i in range(_lm_pts.size()):
			var q: Vector2 = _lm_pts[i]
			var o := i * 4
			_tick_pts.append(q + Vector2(-2.2, -2.2)); _tick_pts.append(q + Vector2(2.2, -2.2))
			_tick_pts.append(q + Vector2(2.2, 2.2));   _tick_pts.append(q + Vector2(-2.2, 2.2))
			_tick_uvs.append(Vector2(0, 0)); _tick_uvs.append(Vector2(1, 0))
			_tick_uvs.append(Vector2(1, 1)); _tick_uvs.append(Vector2(0, 1))
			_tick_idx.append_array([o, o + 1, o + 2, o, o + 2, o + 3])
		_tick_cols = PackedColorArray(); _tick_cols.resize(_tick_pts.size())

	var pts := _lm_pts
	var closed := _lm_closed

	# drop shadow: land visibly lifts off the sea. All three fills below go via
	# RenderingServer with the cached _lm_idx instead of draw_colored_polygon(),
	# which would ear-clip the outline again on every single call.
	var ci_rid := get_canvas_item()
	_lm_sh_cols.fill(Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.5))
	RenderingServer.canvas_item_add_triangle_array(ci_rid, _lm_idx, _lm_sh, _lm_sh_cols)

	# soft outer glow underlay (a few expanding faint strokes)
	for g in range(4):
		var gw := 18.0 - float(g) * 4.0
		var ga := 0.05 + 0.03 * float(g)
		draw_polyline(closed, Color(SKY.r, SKY.g, SKY.b, ga), gw, true)

	# filled land: single smooth top-light gradient fill (was two flat-color
	# polygons stacked to fake a gradient, leaving a hard ring-like inner edge)
	_lm_land_cols.fill(Color(1, 1, 1, 1))
	RenderingServer.canvas_item_add_triangle_array(ci_rid, _lm_idx, pts, _lm_land_cols,
		_lm_land_uvs, PackedInt32Array(), PackedFloat32Array(), _land_grad.get_rid())
	# holo survey grid clipped to the landmass (repeat-tiled via uv > 1)
	if _grid_tile != null:
		_lm_grid_cols.fill(Color(GOLD.r, GOLD.g, GOLD.b, 0.035))
		RenderingServer.canvas_item_add_triangle_array(ci_rid, _lm_idx, pts, _lm_grid_cols,
			_lm_grid_uvs, PackedInt32Array(), PackedFloat32Array(), _grid_tile.get_rid())

	# animated holo coastline: wide soft glow + bright thin breathing rim
	var glow := 0.5 + 0.5 * sin(_t * 1.5)
	draw_polyline(closed, Color(SKY.r, SKY.g, SKY.b, 0.22), 7.0, true)
	draw_polyline(closed, Color(GOLD.r, GOLD.g, GOLD.b, 0.48 + 0.28 * glow), 2.0, true)
	# survey corner ticks at each vertex — one textured triangle array rather
	# than one non-batchable draw_circle() per outline vertex. fill() is a
	# native memset-class loop, so the glow still pulses for ~free.
	if _tick_pts.size() > 0:
		_tick_cols.fill(Color(GOLD.r, GOLD.g, GOLD.b, 0.32 + 0.20 * glow))
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _tick_idx,
			_tick_pts, _tick_cols, _tick_uvs, PackedInt32Array(), PackedFloat32Array(),
			_dot.get_rid())

func _centroid(pts: PackedVector2Array) -> Vector2:
	var acc := Vector2.ZERO
	for q in pts:
		acc += q
	return acc / float(max(1, pts.size()))

## Layered cartography turns the land from a flat purple polygon into a realm:
## rivers, mountain chains, forests and province boundaries are deterministic,
## cheap to draw, and remain beneath routes/cities so gameplay stays readable.
func _draw_realm_details(outline: PackedVector2Array, cities: Array, realm_index: int) -> void:
	if outline.size() < 8:
		return
	var centre := _proj(Vector2(0.5, 0.5))
	var projected := PackedVector2Array()
	for point in outline:
		projected.append(_proj(point))

	# Three faint province borders radiate from the capital district.
	for border_index in range(3):
		var edge_index := (realm_index * 3 + border_index * 6 + 2) % projected.size()
		var edge: Vector2 = projected[edge_index]
		var side := -1.0 if border_index % 2 == 0 else 1.0
		var ctrl := centre.lerp(edge, 0.52) + (edge - centre).orthogonal().normalized() * 18.0 * side
		var border := PackedVector2Array()
		for step in range(13):
			border.append(_route_point(centre, ctrl, edge, float(step) / 12.0))
		draw_polyline(border, Color(GOLD.r, GOLD.g, GOLD.b, 0.13), 1.2, true)

	# A luminous river crosses the realm and branches toward a second coast.
	var river_a: Vector2 = projected[(realm_index + 1) % projected.size()]
	var river_b: Vector2 = projected[(realm_index + 10) % projected.size()]
	var river_ctrl := centre + Vector2(26.0 * sin(float(realm_index)), -18.0)
	var river := PackedVector2Array()
	for step in range(21):
		river.append(_route_point(river_a, river_ctrl, river_b, float(step) / 20.0))
	draw_polyline(river, Color(0.18, 0.66, 0.78, 0.18), 5.0, true)
	draw_polyline(river, Color(0.36, 0.88, 0.92, 0.48), 1.4, true)

	# Mountain chain: small double-peaked glyphs, positioned safely inside land.
	var mountain_edge: Vector2 = projected[(realm_index * 5 + 4) % projected.size()]
	for mountain_index in range(5):
		var p := centre.lerp(mountain_edge, 0.30 + 0.11 * float(mountain_index))
		p += Vector2(float(mountain_index % 2) * 8.0, sin(float(mountain_index) * 2.1) * 9.0)
		var height := 13.0 + float(mountain_index % 3) * 3.0
		var peak := PackedVector2Array([p + Vector2(-11, 7), p + Vector2(0, -height), p + Vector2(11, 7)])
		draw_polyline(peak, Color(0.78, 0.62, 0.88, 0.48), 2.0, true)
		draw_line(p + Vector2(-4, -height * 0.35), p + Vector2(0, -height), Color(INK.r, INK.g, INK.b, 0.32), 1.2)

	# Forest groves form recognizable territories around the outer settlements.
	for grove_index in range(3):
		var forest_edge: Vector2 = projected[(realm_index * 2 + grove_index * 5 + 7) % projected.size()]
		var grove := centre.lerp(forest_edge, 0.55)
		for tree_index in range(5):
			var ox := float((tree_index % 3) - 1) * 9.0
			var oy := float(tree_index / 3) * 10.0 + float(tree_index % 2) * 3.0
			var tree := grove + Vector2(ox, oy)
			var crown := PackedVector2Array([tree + Vector2(-5, 4), tree + Vector2(0, -7), tree + Vector2(5, 4)])
			draw_colored_polygon(crown, Color(0.16, 0.46, 0.34, 0.52))
			draw_line(tree + Vector2(0, 3), tree + Vector2(0, 8), Color(GOLD.r, GOLD.g, GOLD.b, 0.24), 1.0)

	# Roads connect every settlement even before courier routes are unlocked,
	# making the realm read as inhabited rather than an empty level selector.
	for city_index in range(1, cities.size()):
		var city: Dictionary = cities[city_index]
		var destination := _proj(Vector2(city["x"], city["y"]))
		draw_dashed_line(centre, destination, Color(GOLD.r, GOLD.g, GOLD.b, 0.20), 1.4, 7.0, false)

# ---------------------------------------------------------------- routes

## Quadratic-bezier control point for a route: bows the lane sideways so lanes
## read as flight arcs; alternate sides per route index to avoid overlap.
func _route_ctrl(a: Vector2, b: Vector2, r: int) -> Vector2:
	var mid := (a + b) * 0.5
	var d := a.distance_to(b)
	if d < 0.001:
		return mid
	var side_f := -1.0 if (r % 2 == 0) else 1.0
	return mid + (b - a).orthogonal().normalized() * d * 0.16 * side_f

func _route_point(a: Vector2, ctrl: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)

## Draws route lanes and returns each route's {b, ctrl} geometry so
## _draw_drones() doesn't redundantly recompute _proj()/_route_ctrl() per
## drone for a value that's identical for every drone sharing the same route.
func _draw_routes(cap: Vector2, cities: Array) -> Dictionary:
	# tie the lane's core brightness to the same breathing pulse as the
	# coastline rim — the flight lanes are more functionally important than
	# the decorative outline but used to read visibly weaker (flat 0.45)
	var glow := 0.5 + 0.5 * sin(_t * 1.5)
	var route_geom: Dictionary = {}
	for r in range(GameState.cities_unlocked):
		var idx: int = 1 + r
		if idx >= cities.size():
			continue
		var cp := _proj(Vector2(cities[idx]["x"], cities[idx]["y"]))
		var ctrl := _route_ctrl(cap, cp, r)
		route_geom[r] = {"b": cp, "ctrl": ctrl}
		var pts := PackedVector2Array()
		var segs := 14
		for i in range(segs + 1):
			pts.append(_route_point(cap, ctrl, cp, float(i) / float(segs)))
		# wide soft glow lane + bright core, along the arc
		draw_polyline(pts, Color(GOLD.r, GOLD.g, GOLD.b, 0.12), 10.0, true)
		draw_polyline(pts, Color(GOLD.r, GOLD.g, GOLD.b, 0.62 + 0.28 * glow), 2.2, true)
		# two traveling flow highlights per lane (busier logistics feel)
		for k in range(2):
			var phase := fmod(_t * 0.35 + float(r) * 0.27 + float(k) * 0.5, 1.0)
			var flow := _route_point(cap, ctrl, cp, phase)
			draw_circle(flow, 5.5, Color(SKY.r, SKY.g, SKY.b, 0.20))
			draw_circle(flow, 2.5, Color(1.0, 0.88, 0.52, 0.95))
			draw_circle(flow, 6.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.35))
	return route_geom

## Merchant wagons keep active routes visibly productive between griffin
## arrivals. Route investment increases traffic density in the world.
func _draw_ground_traffic(cap: Vector2, route_geom: Dictionary) -> void:
	var route_level := int(GameState.levels.get("routes", 0))
	var wagons_per_route := 1 + mini(2, route_level / 10)
	for route_key in route_geom:
		var geom: Dictionary = route_geom[route_key]
		var destination: Vector2 = geom["b"]
		var ctrl: Vector2 = geom["ctrl"]
		for wagon in range(wagons_per_route):
			var phase := fmod(_t * (0.055 + float(route_level) * 0.0015)
					+ float(route_key) * 0.31 + float(wagon) / float(wagons_per_route), 1.0)
			var pos := _route_point(cap, ctrl, destination, phase)
			var tangent := (ctrl - cap).lerp(destination - ctrl, phase)
			draw_set_transform(pos + Vector2(0, 9), tangent.angle(), Vector2.ONE)
			draw_circle(Vector2(-5, 4), 2.2, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.72))
			draw_circle(Vector2(5, 4), 2.2, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.72))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-8, -3), Vector2(5, -3), Vector2(8, 3), Vector2(-6, 3)
			]), Color(0.32, 0.16, 0.08, 0.94))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-5, -4), Vector2(0, -10), Vector2(6, -4)
			]), Color(GOLD.r, GOLD.g * 0.72, GOLD.b * 0.42, 0.92))
			draw_circle(Vector2(1, -5), 1.6, Color(GOLD.r, GOLD.g, GOLD.b, 0.88))
	draw_set_transform_matrix(Transform2D.IDENTITY)

# ---------------------------------------------------------------- drones

func _draw_drones(cap: Vector2, cities: Array, route_geom: Dictionary) -> void:
	var skin: Dictionary = Economy.SKINS.get(GameState.skin_active, Economy.SKINS["classic"])
	var body: Color = skin["body"]
	var trail_col: Color = skin["trail"]
	for di in range(GameState.vdrones.size()):
		var v: Dictionary = GameState.vdrones[di]
		var route: int = int(v["route"])
		var b: Vector2
		var ctrl: Vector2
		if route_geom.has(route):
			# every drone on the same route shares identical geometry —
			# reuse what _draw_routes() already computed instead of rerunning
			# _proj()/_route_ctrl() (2 sqrt calls) per drone
			b = route_geom[route]["b"]
			ctrl = route_geom[route]["ctrl"]
		else:
			var rr: int = clampi(1 + route, 1, cities.size() - 1)
			b = _proj(Vector2(cities[rr]["x"], cities[rr]["y"]))
			ctrl = _route_ctrl(cap, b, route)
		var tval: float = float(v.get("vt", v["t"]))   # slow cosmetic clock (see game_state VISUAL_SPEED_FACTOR)
		var vdir: int = int(v.get("vdir", v["dir"]))
		var base := _route_point(cap, ctrl, b, tval)
		# takeoff/landing ease: shrink + settle near pads instead of instant flips
		var edge := minf(tval, 1.0 - tval)
		var k := clampf(edge / 0.08, 0.0, 1.0)
		var dsc := lerpf(0.65, 1.0, k)
		# ambient micro-bob (suppressed near pads so the drone visibly descends)
		var bob := sin(_t * 2.4 + float(di) * 1.7) * 2.5 * k
		var lane_offset := (b - cap).orthogonal().normalized() * float((di % 3) - 1) * 5.0
		var pos := base + lane_offset + Vector2(0, bob)

		# trail history
		var hist: Array = _trails.get(di, [])
		hist.append(pos)
		while hist.size() > TRAIL_LEN:
			hist.remove_at(0)
		_trails[di] = hist
		_draw_trail(hist, trail_col)

		# soft ground shadow (offset down)
		# soft grounded blob via the AA dot texture, not a hard-edged draw_circle disc
		var sh_r := 15.0 * dsc
		draw_texture_rect(_dot, Rect2(pos.x - sh_r, pos.y + 14.0 * dsc - sh_r * 0.5, sh_r * 2.0, sh_r), false, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.28))
		# under-glow
		draw_circle(pos, 16.0 * dsc, Color(SKY.r, SKY.g, SKY.b, 0.10))

		# carried package on outbound leg (world-space: hangs below the drone),
		# scaled by dsc so it shrinks/settles in sync with the drone near pads
		# instead of staying full-size while the drone shrinks around it
		if vdir == 1:
			if _package != null:
				var psz := 18.0 * dsc
				draw_texture_rect(_package, Rect2(pos.x - psz * 0.5, pos.y + 9.0 * dsc, psz, psz), false)

		# Heading from the Bezier tangent. The production griffin sheet faces
		# right, so reverse journeys use a horizontal flip instead of rotating
		# the courier upside-down. A restrained bank follows the curved route.
		var deriv := (ctrl - cap).lerp(b - ctrl, tval) * float(vdir)
		var ang := 0.0
		if deriv.length_squared() > 0.0001:
			ang = deriv.angle()
		ang += sin(_t * 2.0 + float(di) * 1.3) * 0.06
		if _griffin_flight_sheet != null:
			var frame := 2 if Fx.reduce_motion else (int(floor(_t * 7.5 + float(di) * 0.8)) % 6)
			var src := Rect2(float(frame % 3) * 256.0, float(floori(float(frame) / 3.0)) * 256.0, 256.0, 256.0)
			var flip_x := deriv.x < 0.0
			if flip_x:
				ang += -PI if ang > 0.0 else PI
			var sprite_scale := Vector2(-dsc if flip_x else dsc, dsc)
			draw_set_transform(pos, ang, sprite_scale)
			draw_texture_rect_region(_griffin_flight_sheet, Rect2(-23, -23, 46, 46), src)
		else:
			# Safe fallback for projects imported before the generated sheet exists.
			var tex: Texture2D = _drone_tex[di % _drone_tex.size()]
			if tex != null:
				draw_set_transform(pos, ang + PI * 0.5, Vector2(dsc, dsc))
				draw_texture_rect(tex, Rect2(-17, -17, 34, 34), false, body)
		if _griffin_flight_sheet != null or not _drone_tex.is_empty():
			draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_trail(hist: Array, col: Color) -> void:
	if hist.size() < 2:
		return
	for i in range(hist.size() - 1):
		var f := float(i) / float(hist.size())
		var a := 0.5 * f   # was 0.30 — trails read weaker than the static coastline
		var ww := 1.0 + 3.0 * f
		draw_line(hist[i], hist[i + 1], Color(col.r, col.g, col.b, a), ww)

# ---------------------------------------------------------------- cities

func _draw_cities(cap: Vector2, cities: Array, _ci: int) -> void:
	var occupied := PackedVector2Array()
	for i in range(cities.size()):
		var cp := _proj(Vector2(cities[i]["x"], cities[i]["y"]))
		var nm: String = cities[i]["name"]
		var flash: float = float(_flash.get(i, 0.0))
		if i == 0:
			if _hub_home == null:
				_draw_city_district(cp, i, true)
			_capital_marker(cp, flash)
			_label(cp, nm, GOLD)
			occupied.append(cp)
		elif i <= GameState.cities_unlocked:
			var dense := false
			if zoom < 1.65 and i < GameState.cities_unlocked:
				for prior: Vector2 in occupied:
					if cp.distance_to(prior) < 42.0:
						dense = true
						break
			if dense:
				_compact_marker(cp, flash)
			else:
				if _hub_city == null:
					_draw_city_district(cp, i, false)
				_active_marker(cp, flash, i)
			occupied.append(cp)
			# On the overview only the frontier city is named. Pinch-zooming turns
			# the map into inspection mode and reveals the remaining labels. This
			# keeps dense late-game realms legible on a 540px portrait viewport.
			if i == GameState.cities_unlocked or zoom >= 1.65:
				_label(cp, nm, Color(0.80, 1.0, 1.0))
		else:
			var is_next := (i == GameState.cities_unlocked + 1)
			_locked_marker(cp, is_next)
			if is_next:
				_cost_chip(cp, _next_cost_str)

## Level-of-detail marker for older hubs whose full crests would overlap in the
## portrait overview. Zooming past 1.65 restores the complete city artwork.
func _compact_marker(p: Vector2, flash: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	draw_circle(p, 8.0 + pulse * 2.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.10))
	draw_circle(p, 4.2, Color(MIDNIGHT.r, MIDNIGHT.g, MIDNIGHT.b, 0.96))
	draw_circle(p, 2.4, Color(CYAN.r, CYAN.g, CYAN.b, 0.82))
	draw_arc(p, 6.0, 0.0, TAU, 16, Color(CYAN.r, CYAN.g, CYAN.b, 0.35 + pulse * 0.20), 1.2)
	if flash > 0.0:
		_delivery_flash(p, CYAN, flash)

## Development is now visible on the map itself. Upgrade investment raises the
## skyline through four restrained tiers; the capital is always one tier ahead.
## All shapes are code-native, so they stay crisp at every viewport and zoom.
func _city_development_tier(is_capital: bool) -> int:
	var invested := 0
	for key in GameState.levels:
		invested += int(GameState.levels[key])
	var tier := 1 + int(float(invested) / 32.0)
	if is_capital:
		tier += 1
	return clampi(tier, 1, 4)

func _city_reveal(city_index: int) -> float:
	if Fx.reduce_motion or not _city_growth.has(city_index):
		return 1.0
	var age: float = 1.25 - float(_city_growth[city_index])
	return ease(clampf(age / 0.72, 0.0, 1.0), -1.8)

func _draw_city_district(p: Vector2, city_index: int, is_capital: bool) -> void:
	var tier := _city_development_tier(is_capital)
	var reveal := _city_reveal(city_index)
	var col := GOLD if is_capital else CYAN
	var overview_scale := 0.84 if zoom < 1.65 else 1.0
	var width := (62.0 if is_capital else 46.0) * overview_scale
	var base_y := p.y + 7.0

	# Soft foundation and a narrow upward light column make the settlement read
	# as part of the magical map without competing with labels or couriers.
	draw_ellipse_soft(Vector2(p.x, base_y + 4.0), Vector2(width * 0.62, 8.0), Color(col.r, col.g, col.b, 0.10 * reveal))
	draw_colored_polygon(PackedVector2Array([
		Vector2(p.x - width * 0.34, base_y), Vector2(p.x - width * 0.12, base_y - 44.0 * reveal),
		Vector2(p.x + width * 0.12, base_y - 44.0 * reveal), Vector2(p.x + width * 0.34, base_y),
	]), Color(col.r, col.g, col.b, 0.035 * reveal))

	var count := tier + 2
	for n in range(count):
		var slot: float = float(n) - float(count - 1) * 0.5
		var bw := 7.0 + float((n + city_index) % 2) * 2.0
		var bh := (13.0 + float((n * 11 + city_index * 5) % 18) + float(tier) * 3.0) * reveal
		if n == count / 2:
			bh += (10.0 if is_capital else 5.0) * reveal
		var bx := p.x + slot * (width / float(count)) - bw * 0.5
		var top := base_y - bh
		var body := Color(MIDNIGHT.r * 0.72, MIDNIGHT.g * 0.72, MIDNIGHT.b * 0.78, 0.94 * reveal)
		draw_rect(Rect2(bx, top, bw, bh), body)
		# Arcane spires provide a recognisable fantasy silhouette at small scale.
		if (n + tier) % 2 == 0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(bx - 1.0, top), Vector2(bx + bw * 0.5, top - (5.0 + tier) * reveal),
				Vector2(bx + bw + 1.0, top),
			]), Color(MIDNIGHT.r * 0.65, MIDNIGHT.g * 0.65, MIDNIGHT.b * 0.72, 0.96 * reveal))
		# One or two warm/cyan windows per tower imply life without visual noise.
		if reveal > 0.45:
			var window_col := Color(col.r, col.g, col.b, 0.66)
			draw_rect(Rect2(bx + bw * 0.5 - 1.0, base_y - minf(8.0, bh * 0.45), 2.0, 3.0), window_col)
			if tier >= 3 and bh > 24.0:
				draw_rect(Rect2(bx + bw * 0.5 - 1.0, base_y - 17.0, 2.0, 3.0), window_col)

	# A fine baseline unifies the separate towers into one readable district.
	draw_line(Vector2(p.x - width * 0.5, base_y), Vector2(p.x + width * 0.5, base_y), Color(col.r, col.g, col.b, 0.42 * reveal), 1.4)
	_draw_district_investments(p, city_index, is_capital, reveal, width, base_y)
	if _city_growth.has(city_index) and not Fx.reduce_motion:
		var ring_alpha := clampf(float(_city_growth[city_index]) / 1.25, 0.0, 1.0)
		draw_arc(p, 24.0 + (1.0 - ring_alpha) * 38.0, 0.0, TAU, 36, Color(col.r, col.g, col.b, ring_alpha * 0.75), 2.4)

## Upgrade families own distinct world structures: cargo builds warehouses,
## value opens markets, speed raises beacons and routes add street lamps.
func _draw_district_investments(p: Vector2, city_index: int, is_capital: bool,
		reveal: float, width: float, base_y: float) -> void:
	var district_scale := 1.18 if is_capital else 0.88
	var speed_level := int(GameState.levels.get("speed", 0))
	var cargo_level := int(GameState.levels.get("cargo", 0))
	var value_level := int(GameState.levels.get("value", 0))
	var route_level := int(GameState.levels.get("routes", 0))

	if cargo_level > 0:
		for side in [-1.0, 1.0]:
			var wx: float = p.x + float(side) * width * 0.48
			var wh := (8.0 + minf(8.0, float(cargo_level) * 0.45)) * district_scale * reveal
			var ww := (13.0 + minf(7.0, float(cargo_level) * 0.35)) * district_scale
			draw_rect(Rect2(wx - ww * 0.5, base_y - wh, ww, wh), Color(0.18, 0.09, 0.16, 0.94 * reveal))
			draw_colored_polygon(PackedVector2Array([
				Vector2(wx - ww * 0.62, base_y - wh), Vector2(wx, base_y - wh - 5.0 * district_scale),
				Vector2(wx + ww * 0.62, base_y - wh)
			]), Color(0.43, 0.20, 0.15, 0.96 * reveal))
			draw_rect(Rect2(wx - 2.0, base_y - 5.0, 4.0, 5.0), Color(GOLD.r, GOLD.g, GOLD.b, 0.56 * reveal))
		if cargo_level >= 10:
			var crane_x := p.x - width * 0.62
			draw_line(Vector2(crane_x, base_y), Vector2(crane_x, base_y - 28.0 * district_scale), Color(0.58, 0.34, 0.20, 0.88 * reveal), 2.2)
			draw_line(Vector2(crane_x, base_y - 27.0 * district_scale), Vector2(crane_x + 18.0 * district_scale, base_y - 27.0 * district_scale), Color(GOLD.r, GOLD.g, GOLD.b, 0.74 * reveal), 2.0)
		if cargo_level >= 25:
			draw_rect(Rect2(p.x - 10.0 * district_scale, base_y - 30.0 * district_scale, 20.0 * district_scale, 18.0 * district_scale), Color(0.30, 0.13, 0.18, 0.96 * reveal))
			draw_colored_polygon(PackedVector2Array([Vector2(p.x - 12.0 * district_scale, base_y - 30.0 * district_scale), Vector2(p.x, base_y - 40.0 * district_scale), Vector2(p.x + 12.0 * district_scale, base_y - 30.0 * district_scale)]), Color(GOLD.r, GOLD.g, GOLD.b, 0.82 * reveal))

	if value_level > 0:
		var stalls := 1 + mini(2, value_level / 8)
		for stall in range(stalls):
			var sx: float = p.x + (float(stall) - float(stalls - 1) * 0.5) * 13.0 * district_scale
			var sy: float = base_y + 7.0 + float(city_index % 2) * 2.0
			draw_rect(Rect2(sx - 5.0 * district_scale, sy - 5.0 * district_scale, 10.0 * district_scale, 5.0 * district_scale), Color(0.20, 0.10, 0.23, 0.92 * reveal))
			draw_colored_polygon(PackedVector2Array([
				Vector2(sx - 6.0 * district_scale, sy - 5.0 * district_scale), Vector2(sx - 3.0 * district_scale, sy - 10.0 * district_scale),
				Vector2(sx + 3.0 * district_scale, sy - 10.0 * district_scale), Vector2(sx + 6.0 * district_scale, sy - 5.0 * district_scale)
			]), Color(SKY.r, SKY.g, SKY.b, 0.90 * reveal))
			draw_circle(Vector2(sx, sy - 8.0 * district_scale), 1.3 * district_scale, Color(GOLD.r, GOLD.g, GOLD.b, 0.92 * reveal))
		if value_level >= 25:
			var pavilion := Vector2(p.x, base_y + 11.0 * district_scale)
			draw_arc(pavilion, 12.0 * district_scale, PI, TAU, 20, Color(SKY.r, SKY.g, SKY.b, 0.94 * reveal), 4.0)
			draw_circle(pavilion + Vector2(0, -10.0 * district_scale), 3.0 * district_scale, Color(GOLD.r, GOLD.g, GOLD.b, 0.95 * reveal))

	if speed_level > 0:
		var beacon_height := (34.0 + minf(22.0, float(speed_level) * 0.8)) * district_scale * reveal
		var beacon_x := p.x + width * 0.28
		draw_line(Vector2(beacon_x, base_y), Vector2(beacon_x, base_y - beacon_height), Color(0.30, 0.16, 0.38, 0.96 * reveal), 4.0 * district_scale)
		var pulse := 0.5 + 0.5 * sin(_t * (2.0 + float(speed_level) * 0.04) + float(city_index))
		var beacon := Vector2(beacon_x, base_y - beacon_height)
		draw_circle(beacon, (3.0 + pulse * 2.0) * district_scale, Color(CYAN.r, CYAN.g, CYAN.b, (0.45 + pulse * 0.35) * reveal))
		draw_line(beacon, beacon + Vector2(0, -18.0 * district_scale), Color(CYAN.r, CYAN.g, CYAN.b, 0.18 * reveal), 2.0)
		var portal_phase := 0.0 if Fx.reduce_motion else _t
		if speed_level >= 10:
			draw_arc(beacon, 9.0 * district_scale, portal_phase, portal_phase + TAU * 1.65, 24, Color(CYAN.r, CYAN.g, CYAN.b, 0.72 * reveal), 1.8)
		if speed_level >= 25:
			draw_arc(beacon, 15.0 * district_scale, -portal_phase * 0.7, -portal_phase * 0.7 + TAU * 1.75, 30, Color(SKY.r, SKY.g, SKY.b, 0.88 * reveal), 3.0)
			draw_circle(beacon, 7.0 * district_scale, Color(0.32, 0.12, 0.55, 0.72 * reveal))

	if route_level > 0:
		var lamps := 2 + mini(2, route_level / 10)
		for lamp in range(lamps):
			var side := -1.0 if lamp % 2 == 0 else 1.0
			var lx: float = p.x + side * (width * 0.30 + float(lamp / 2) * 7.0)
			var ly: float = base_y + 4.0 + float(lamp / 2) * 5.0
			draw_line(Vector2(lx, ly), Vector2(lx, ly - 9.0 * district_scale), Color(0.24, 0.14, 0.25, 0.92 * reveal), 1.6)
			draw_circle(Vector2(lx, ly - 10.0 * district_scale), 2.2 * district_scale, Color(GOLD.r, GOLD.g, GOLD.b, 0.88 * reveal))
		if route_level >= 25:
			var gate_y := base_y + 5.0 * district_scale
			draw_line(Vector2(p.x - 13.0 * district_scale, gate_y), Vector2(p.x - 13.0 * district_scale, gate_y - 21.0 * district_scale), Color(0.36, 0.20, 0.34, 0.94 * reveal), 3.2)
			draw_line(Vector2(p.x + 13.0 * district_scale, gate_y), Vector2(p.x + 13.0 * district_scale, gate_y - 21.0 * district_scale), Color(0.36, 0.20, 0.34, 0.94 * reveal), 3.2)
			draw_arc(Vector2(p.x, gate_y - 20.0 * district_scale), 13.0 * district_scale, PI, TAU, 22, Color(GOLD.r, GOLD.g, GOLD.b, 0.86 * reveal), 3.0)

	if _investment_reveal > 0.0 and is_capital and not Fx.reduce_motion:
		var alpha := clampf(_investment_reveal / 0.9, 0.0, 1.0)
		draw_arc(p, 42.0 + (1.0 - alpha) * 38.0, 0.0, TAU, 40, Color(GOLD.r, GOLD.g, GOLD.b, alpha * 0.72), 3.0)
		for spark in range(7):
			var angle := TAU * float(spark) / 7.0 + _t
			var radius := 24.0 + (1.0 - alpha) * 24.0
			draw_circle(p + Vector2.from_angle(angle) * radius, 2.2, Color(GOLD.r, GOLD.g, GOLD.b, alpha))

## CanvasItem has no soft ellipse primitive. Layered ellipses keep this cheap,
## deterministic and compatible with the mobile renderer.
func draw_ellipse_soft(center: Vector2, radius: Vector2, color: Color) -> void:
	for layer in range(4, 0, -1):
		var f := float(layer) / 4.0
		var pts := PackedVector2Array()
		for s in range(20):
			var a := TAU * float(s) / 20.0
			pts.append(center + Vector2(cos(a) * radius.x * f, sin(a) * radius.y * f))
		var alpha := color.a * (0.18 + (1.0 - f) * 0.20)
		draw_colored_polygon(pts, Color(color.r, color.g, color.b, alpha))

func _on_city_unlocked_visual(index: int) -> void:
	_refresh_next_cost()
	_flash[index] = 0.5
	if not Fx.reduce_motion:
		_city_growth[index] = 1.25

func _on_country_changed_visual(_index: int) -> void:
	_recalc_bbox()
	_reset_view()
	_refresh_next_cost()
	# Histories use screen positions from the previous realm. Clearing them
	# prevents one-frame trail streaks across the new map during its reveal.
	_trails.clear()
	_flash.clear()
	_city_growth.clear()
	if not Fx.reduce_motion:
		_city_growth[0] = 1.25
	reveal_country()

func _capital_marker(p: Vector2, flash: float) -> void:
	# hub_home texture if available, else procedural golden pad
	var breath: float = 0.5 + 0.5 * sin(_t * 1.6)
	var reveal := _city_reveal(0)
	var tier := _city_development_tier(true)
	# tall ambient ground glow
	draw_circle(p, 30.0 + breath * 6.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.10 + 0.05 * breath))
	if _hub_home != null:
		var s := (58.0 + float(tier) * 2.0) if zoom < 1.65 else (70.0 + float(tier) * 2.0)
		var rs := s * reveal
		# Buildings stand above their route node; the landing platform rests on
		# `p` while the label remains below it. Centering the old crest on `p`
		# made artwork, route and name collide in the same 40px square.
		draw_texture_rect(_hub_home, Rect2(p.x - rs * 0.5, p.y - rs + 8.0, rs, rs), false, Color(1, 1, 1, reveal))
	else:
		draw_circle(p, 11.0, GOLD)
		draw_circle(p, 5.0, INK)
	# pulsing landing ring via draw_arc (phase from shared clock)
	var ph := _t * 1.2
	draw_arc(p, 20.0 + breath * 3.0, ph, ph + TAU, 32, Color(GOLD.r, GOLD.g, GOLD.b, 0.7), 2.5)
	# rotating radar sweep with fading trail arc
	var ra := _t * 0.9
	draw_arc(p, 30.0, ra - 0.85, ra, 10, Color(GOLD.r, GOLD.g, GOLD.b, 0.10), 9.0)
	draw_line(p, p + Vector2.from_angle(ra) * 34.0, Color(GOLD.r, GOLD.g, GOLD.b, 0.30), 1.6)
	if flash > 0.0:
		_delivery_flash(p, GOLD, flash)

func _active_marker(p: Vector2, flash: float, city_index: int) -> void:
	var pulse: float = 0.5 + 0.5 * sin(_t * 3.0)
	var reveal := _city_reveal(city_index)
	var tier := _city_development_tier(false)
	draw_circle(p, 14.0 + pulse * 4.0, Color(CYAN.r, CYAN.g, CYAN.b, 0.16))
	if _hub_city != null:
		var s := (40.0 + float(tier) * 2.0) if zoom < 1.65 else (50.0 + float(tier) * 2.0)
		var rs := s * reveal
		draw_texture_rect(_hub_city, Rect2(p.x - rs * 0.5, p.y - rs + 6.0, rs, rs), false, Color(1, 1, 1, reveal))
	else:
		draw_circle(p, 8.0, CYAN)
		draw_circle(p, 3.6, INK)
	draw_arc(p, 11.0, 0, TAU, 24, Color(CYAN.r, CYAN.g, CYAN.b, 0.4 + 0.3 * pulse), 1.6)
	if flash > 0.0:
		_delivery_flash(p, CYAN, flash)

func _locked_marker(p: Vector2, is_next: bool) -> void:
	if is_next:
		# The next expansion is a real construction site, not another abstract
		# crest. Its warm pulse makes the progression target obvious at a glance.
		var pulse: float = 0.5 + 0.5 * sin(_t * 2.2)
		draw_circle(p, 16.0 + pulse * 5.0, Color(MUTED.r, MUTED.g, MUTED.b, 0.14 + 0.06 * pulse))
		if _hub_city2 != null:
			var s := 42.0 if zoom < 1.65 else 52.0
			draw_texture_rect(_hub_city2, Rect2(p.x - s * 0.5, p.y - s + 6.0, s, s), false, Color(0.72, 0.76, 0.88, 0.72 + 0.20 * pulse))
		else:
			draw_circle(p, 7.0, Color(MUTED.r, MUTED.g, MUTED.b, 0.9))
		draw_arc(p, 12.0, 0, TAU, 24, Color(GOLD.r, GOLD.g, GOLD.b, 0.35 + 0.3 * pulse), 1.6)
	else:
		# far-locked: dim
		draw_circle(p, 6.0, Color(MUTED.r, MUTED.g, MUTED.b, 0.35))
		draw_circle(p, 2.4, Color(MUTED.r, MUTED.g, MUTED.b, 0.55))

func _delivery_flash(p: Vector2, col: Color, t: float) -> void:
	# expanding ring + rising light beam, t goes 0.5 -> 0, eased so the ring
	# expands fast then decelerates instead of a flat constant-speed expansion
	var f: float = clamp(t / 0.5, 0.0, 1.0)
	var ef := 1.0 - pow(f, 2.5)
	var r := 14.0 + ef * 34.0
	draw_arc(p, r, 0, TAU, 28, Color(col.r, col.g, col.b, f * 0.8), 2.5)
	draw_line(p, p + Vector2(0, -46.0 * ef - 8.0), Color(col.r, col.g, col.b, f * 0.35), 3.0)
	# parcel visibly dropping onto the pad, with a smooth fade-in instead of a
	# hard t>0.2 cutoff that used to pop the sprite in at ~40% alpha in one frame
	if _package != null:
		var pkg_fade := smoothstep(0.0, 0.2, t)
		if pkg_fade > 0.0:
			var drop := (0.5 - t) * 30.0
			draw_texture_rect(_package, Rect2(p.x - 9.0, p.y - 26.0 + drop, 18, 18), false, Color(1, 1, 1, f * pkg_fade))

# ---------------------------------------------------------------- labels

func _label(p: Vector2, text: String, col: Color) -> void:
	if _font == null:
		return
	var lw := 220.0
	# frosted pill backing for legibility (pill height + baseline track the font
	# size so a larger label never clips its backing)
	var tw := _measure(text, 18)
	var pill := Rect2(p.x - tw * 0.5 - 10.0, p.y + 22.0, tw + 20.0, 26.0)
	_chip_sb.bg_color = Color(MIDNIGHT.r, MIDNIGHT.g, MIDNIGHT.b, 0.72)
	_chip_sb.border_color = Color(col.r, col.g, col.b, 0.30)
	draw_style_box(_chip_sb, pill)
	# shadow copy first (the +credits pops already do this) so light labels stay
	# legible where they cross the breathing coastline or a route lane
	draw_string(_font, Vector2(p.x - lw * 0.5, p.y + 41.5), text, HORIZONTAL_ALIGNMENT_CENTER, lw, 18, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.75))
	draw_string(_font, Vector2(p.x - lw * 0.5, p.y + 40.0), text, HORIZONTAL_ALIGNMENT_CENTER, lw, 18, col)

func _cost_chip(p: Vector2, cost: String) -> void:
	if _font == null:
		return
	# lives ABOVE the marker (name pills live below) so lanes never collide
	var lw := 200.0
	var tw := _measure(cost, 17)
	var chip_y := p.y - 46.0
	if _hub_city2 != null:
		chip_y = p.y - (74.0 if zoom < 1.65 else 88.0)
	var pill := Rect2(p.x - tw * 0.5 - 27.0, chip_y, tw + 45.0, 26.0)
	_chip_sb.bg_color = Color(MIDNIGHT.r, MIDNIGHT.g, MIDNIGHT.b, 0.78)
	_chip_sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.35)
	draw_style_box(_chip_sb, pill)
	if _lock != null:
		draw_texture_rect(_lock, Rect2(pill.position.x + 8.0, pill.position.y + 6.0, 14, 14), false, Color(GOLD.r, GOLD.g, GOLD.b, 0.95))
	draw_string(_font, Vector2(p.x - lw * 0.5 + 9.5, chip_y + 18.5), cost, HORIZONTAL_ALIGNMENT_CENTER, lw, 17, Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.7))
	draw_string(_font, Vector2(p.x - lw * 0.5 + 9.0, chip_y + 17.0), cost, HORIZONTAL_ALIGNMENT_CENTER, lw, 17, Color(GOLD.r, GOLD.g, GOLD.b, 0.95))

# ---------------------------------------------------------------- pops / fx

func _on_delivered(_amount: float, city_index: int, _count: int) -> void:
	# Deliveries fire on the fast economic cadence, but drones move on the 20x
	# slower cosmetic clock — so at high income the beacons strobe far faster
	# than any drone visibly arrives (reads as random flicker). Throttle to
	# ~1-in-(drones/4) so flashes/pops roughly match perceived arrivals.
	_deliver_seen += 1
	var step: int = clampi(GameState.drones / 2, 2, 30)
	if _deliver_seen % step != 0:
		return
	var cities := Economy.country_cities(GameState.current_country)
	var idx: int = clampi(city_index, 0, cities.size() - 1)
	# beacon flash on the destination
	_flash[idx] = 0.5
	# Earnings text is intentionally owned by main.gd. Drawing a second value
	# here caused gold and green numbers to stack over the same city at high
	# delivery rates. The map keeps only the concise destination beacon.

func _draw_pops() -> void:
	if _font == null:
		return
	for p in _pops:
		var life: float = float(p["life"])
		var a: float = clampf(life, 0.0, 1.0)
		# spring overshoot in, settle, drift with a light sideways arc
		var age := 1.0 - life
		var sc := lerpf(0.5, 1.15, clampf(age / 0.12, 0.0, 1.0))
		if age > 0.12:
			sc = lerpf(1.15, 1.0, clampf((age - 0.12) / 0.15, 0.0, 1.0))
		var px: float = float(p["x"]) + sin(life * 3.0) * 6.0
		var py: float = float(p["y"])
		var txt: String = String(p["text"])
		draw_set_transform(Vector2(px, py), 0.0, Vector2(sc, sc))
		if _coin != null:
			draw_texture_rect(_coin, Rect2(-64.0, -11.0, 18, 18), false, Color(1, 1, 1, a))
		draw_string(_font, Vector2(-42.0, 2.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 24, Color(SHADOW.r, SHADOW.g, SHADOW.b, a * 0.8))
		draw_string(_font, Vector2(-42.0, 0.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 24, Color(MINT.r, MINT.g, MINT.b, a))
		draw_set_transform_matrix(Transform2D.IDENTITY)
