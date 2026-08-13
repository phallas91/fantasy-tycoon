extends Control
## Main scene — Arcane Trade Empire. Built on Drone Tycoon: Sky Fleet (MIT).

const NAV_H := 70.0
const SIDE_PANEL_W := 410.0
const OFFLINE_POPUP_MIN_SECONDS := 60.0
# The top HUD owns the first 198 logical pixels once its objective ribbon is
# visible. Starting management at 150 made the panel cover that objective on
# every landscape device; keep a small breathing gap below the complete HUD.
const LANDSCAPE_PANEL_TOP := 170.0
const MANAGEMENT_PAGE_SIZE := 3
const ART    := "res://assets/art/"
const GUTTER := 12.0
const GRIFFIN_FLIGHT := preload("res://scripts/griffin_flight.gd")
const MAP_VIEW := preload("res://scripts/map_view.gd")
const BONUS_DRONE := preload("res://scripts/bonus_drone.gd")

var _map: Control
var _bonus: Control
var _hud: PanelContainer
var _map_floor_anchor: Control
var _bottom_bg: Panel
var _nav_bar: HBoxContainer
var _nav_sep: ColorRect
var _safe_top := 0.0
var _safe_bottom := 0.0
var _pages: Array
var _nav_btns: Array
var _nav_icons: Array
var _nav_labels: Array
var _nav_dots: Array
var _nav_ind: Panel
var _focus_card: PanelContainer
var _focus_title: Label
var _focus_detail: Label
var _focus_btn: Button
var _focus_prog_fill: Panel
var _active_tab := 0
var _nav_stage := -1
var _toasts: VBoxContainer
var _page_groups: Dictionary = {}
var _page_indices: Dictionary = {}
var _page_labels: Dictionary = {}
var _page_gestures: Dictionary = {}

# HUD
var _credits_lbl: Label
var _gems_lbl: Label
var _infl_lbl: Label
var _income_lbl: Label
var _country_lbl: Label
var _credits_chip: Control
var _gems_chip: Control
var _infl_chip: Control
var _blessing_badge: PanelContainer
var _event_row: HBoxContainer
var _event_icon: TextureRect
var _event_name_lbl: Label
var _event_time_lbl: Label
var _next_obj_lbl: Button
var _ribbon_bg: Panel
var _objective_cache: Dictionary = {}
var _achieve_count_lbl: Label
var _claim_all_btn: Button
var _event_timer_bar: Panel
var _ribbon_fill: Panel
var _disp_credits := 0.0

# previous values for chip-pop detection
var _prev_gems := 0
var _prev_infl := 0
var _prev_combo_mult := 1.0
var _prev_buy_mode := -999
var _prev_income_col := Color(0, 0, 0, 0)   # dirty-check for the income label's colour override
var _nav_sb_on: StyleBox                    # the only two nav styleboxes, built once in _switch_tab
var _nav_sb_off: StyleBox

# Tab widgets
var _rows := {}
var _talent_rows := {}
var _gem_rows := {}
var _skin_rows := {}
var _iap_rows := {}
var _iap_section: Control
var _iap_intro_card: PanelContainer
var _restore_iap_btn: Button
var _arcane_collection_nodes: Array[Control] = []
var _courier_style_nodes: Array[Control] = []
var _daily_shop_card: PanelContainer
var _section_lbls: Array = []   # section header labels, re-translated on locale change
var _mode_btns := {}
var _drone_btn: Button
var _drone_detail: Label
var _expand_btn: Button
var _expand_detail: Label
var _expand_card: Control
var _expand_panel_unlocked := false
var _streak_lbl: Label
var _streak_chip: PanelContainer
var _daily_hud_sig := ""
var _combo_chip: PanelContainer
var _combo_lbl: Label
var _city_prog_fill: Panel
var _progress_lbl: Label
var _city_list_box: VBoxContainer
var _city_income_labels := {}
var _city_rows := {}
var _prestige_shop_box: VBoxContainer
var _achieve_box: VBoxContainer
var _prestige_shop_rows := {}
var _prestige_btn: Button
var _prestige_info_lbl: Label
var _prestige_section: Control
var _prestige_card: PanelContainer
var _prestige_panel_unlocked := false
var _pgems_lbl: Label
var _achieve_cells := {}
var _achieve_prog_fills := {}
var _achieve_prog_lbls := {}
var _settings_stats_lbl: Label = null
var _prestige_ready_prev := false
var _tap_block_until := 0   # ms; swipe guard so paging never triggers a purchase
var _auto_mgr_toggle: Control
var _auto_mgr_section: Control
var _auto_manager_panel_unlocked := false
var _upgrade_unlock_rank := -1
var _ascendant_lbl: Label
var _ascendant_btn: Button

# Missions tab (contracts)
var _mission_title_lbls: Array = []
var _mission_prog_bars: Array = []
var _mission_prog_lbls: Array = []
var _mission_time_lbls: Array = []
var _mission_claim_btns: Array = []
var _mission_reward_lbls: Array = []
var _mission_x2_btns: Array = []
var _mission_reroll_btns: Array = []
var _mission_gem_lbls: Array = []
var _mission_gem_icons: Array = []
var _mission_cards: Array = []
var _mission_weekly_section: Control
var _mission_visible_count := -1
var _claim_all_available := false
# change-detection so _update_contracts() (called 4x/sec) only rebuilds a
# slot's text/fills when its progress/ready/claimed actually moved, instead
# of unconditionally re-shaping every label every call
var _mission_last_progress: Array = [-1.0, -1.0, -1.0, -1.0]
var _mission_last_ready: Array = [false, false, false, false]
var _mission_last_claimed: Array = [false, false, false, false]

# Income milestone celebration
const INCOME_MILESTONES: Array = [1000.0, 10000.0, 100000.0, 1000000.0, 10000000.0, 100000000.0, 1000000000.0]
const MILESTONE_LABELS: Array  = ["1K", "10K", "100K", "1M", "10M", "100M", "1B"]
var _income_milestone_idx := 0

# Floating delivery earnings are time-gated instead of delivery-count-gated.
# At late-game speeds hundreds of logical deliveries can land per second, so a
# count gate still created a wall of overlapping labels on narrow screens.
var _delivery_fx_bank := 0.0
var _last_delivery_fx_ms := 0
var _fountain_counter := 0
var _resume_reward_queued := false
var _save_recovery_queued := false
var _boot_complete := false

func _ready() -> void:
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.build()
	_bg(); _build_map(); _build_bonus_drone(); _build_hud()
	_build_bottom_bg(); _build_map_floor_anchor(); _build_pages(); _build_guided_action(); _build_nav(); _build_toasts()
	_apply_safe_area()
	call_deferred("_apply_safe_area")

	GameState.city_unlocked.connect(_on_city_unlocked)
	GameState.city_developed.connect(_on_city_developed)
	GameState.country_changed.connect(_on_country_changed)
	GameState.region_completed.connect(_on_region_completed)
	GameState.prosperity_advanced.connect(_on_prosperity_advanced)
	GameState.auto_bought.connect(_on_auto_bought)
	GameState.delivered.connect(_on_delivered)
	Achievements.unlocked.connect(_on_achievement)
	Events.started.connect(_on_event_start)
	Events.ended.connect(func(_id): _event_row.visible = false)
	# Daily rewards are an optional return incentive, never a launch blocker.
	# The compact HUD claim chip and Shop dot update from Daily.pending instead.
	Daily.reward_ready.connect(_refresh_daily_hud)
	Prestige.prestiged.connect(_on_prestige)
	Contracts.completed.connect(_on_contract_completed)
	SaveSystem.session_offline_ready.connect(_on_session_offline_ready)
	SaveSystem.save_recovered.connect(_on_save_recovered)
	Billing.purchased.connect(_on_iap_purchased)
	Billing.purchase_failed.connect(_on_iap_failed)
	Billing.catalog_updated.connect(_refresh_iap_prices)

	var loaded := SaveSystem.load_game()
	for product_id: String in Billing.PRODUCT_ORDER:
		_update_iap_row(product_id)
	_disp_credits = GameState.credits
	_prev_gems = GameState.gems; _prev_infl = GameState.influence
	_rebuild_city_list()
	_refresh_progressive_nav()
	_switch_tab(0)
	if Fx.reduce_motion:
		_post_boot(loaded)
	else:
		_boot_intro(loaded)

## Welcome popups run only after the boot ceremony so it is never covered.
func _post_boot(loaded: bool) -> void:
	_boot_complete = true
	if not loaded:
		# The in-world guided card already teaches the one opening action. Starting
		# behind a second full-screen tutorial made the city feel like a menu and
		# repeated the same instruction before the player could touch the world.
		_switch_tab(0)
		if is_instance_valid(_focus_btn):
			Fx.shimmer(_focus_btn, UITheme.GREEN, true)
	elif _should_show_offline_popup():
		_show_offline_popup(GameState.pending_offline, GameState.pending_offline_seconds)
	else:
		_collect_short_offline_reward()

## Brief app switches should never interrupt play with a full-screen reward
## ceremony. One minute is long enough for offline earnings to feel intentional;
## shorter absences are credited silently and remain fully lossless.
func _should_show_offline_popup() -> bool:
	return GameState.pending_offline > 1.0 \
		and GameState.pending_offline_seconds >= OFFLINE_POPUP_MIN_SECONDS

func _collect_short_offline_reward() -> void:
	if GameState.pending_offline <= 0.0 or _should_show_offline_popup():
		return
	GameState.collect_offline(1.0)
	_disp_credits = GameState.credits

## Recovery can happen during load, underneath the cinematic cover. Hold the
## confirmation until boot and any welcome/reward modal have finished so the
## player actually sees that their progress was protected.
func _on_save_recovered() -> void:
	if _save_recovery_queued:
		return
	_save_recovery_queued = true
	await get_tree().process_frame
	while not _boot_complete or _has_modal_overlay():
		await get_tree().create_timer(0.35).timeout
	_save_recovery_queued = false
	_toast(tr("Progresso recuperado com segurança."), UITheme.GREEN, "ic_achieve")

## A warm resume does not reload the scene. Queue its offline reward until any
## modal the player left open has closed, preventing stacked popups while still
## guaranteeing that the newly earned credits are presented and collectable.
func _on_session_offline_ready(_amount: float, _seconds: float) -> void:
	if _resume_reward_queued:
		return
	_resume_reward_queued = true
	await get_tree().process_frame
	while _has_modal_overlay():
		await get_tree().create_timer(0.35).timeout
	_resume_reward_queued = false
	if _should_show_offline_popup():
		_show_offline_popup(GameState.pending_offline, GameState.pending_offline_seconds)
	else:
		_collect_short_offline_reward()

func _has_modal_overlay() -> bool:
	for child in get_children():
		if child is CanvasLayer and (child as CanvasLayer).layer == 150:
			return true
	return false

## First-ever launch only (SaveSystem.load_game() found no save).  The former
## tall list of tips felt like a terms screen and could overflow on small phones.
## This compact, no-scroll carousel teaches one idea at a time and gives the
## player a clear first action when it closes.  Settings can reopen it via Help.
func _show_welcome_popup() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.ACCENT)
	var eyebrow := _lbl("ARCANE TRADE ACADEMY", 13, UITheme.GOLD)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", UITheme.font("Bold")); box.add_child(eyebrow)

	# Signature griffin courier crowns the tutorial without taking over the screen.
	var hero: TextureRect = GRIFFIN_FLIGHT.new()
	hero.custom_minimum_size = Vector2(156, 124)
	hero.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(hero)
	var welcome := _lbl(tr("Bem-vindo, Piloto!"), 27, UITheme.INK)
	welcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	welcome.add_theme_font_override("font", UITheme.font("Bold")); box.add_child(welcome)
	var sub := _lbl(tr("A tua frota de entregas está pronta a descolar."), 15, UITheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(sub)

	# First contact teaches exactly one action. Later systems explain themselves
	# only when progression reveals them, keeping the opening calm and focused.
	var slides: Array = [
		["ic_drone", UITheme.ACCENT, "Compra drones e melhorias", "Cada entrega gera créditos automaticamente."],
	]

	var stage := PanelContainer.new()
	stage.custom_minimum_size = Vector2(0, 230)
	stage.add_theme_stylebox_override("panel", UITheme.action_card(UITheme.ACCENT)); box.add_child(stage)
	var stage_v := VBoxContainer.new(); stage_v.alignment = BoxContainer.ALIGNMENT_CENTER
	stage_v.add_theme_constant_override("separation", 10); stage.add_child(stage_v)
	var badge := _icon_badge("ic_drone", UITheme.ACCENT, 64, 32)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; stage_v.add_child(badge)
	var title := _lbl("", 23, UITheme.INK); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UITheme.font("Bold")); stage_v.add_child(title)
	var body := _lbl("", 16, UITheme.MUTED); body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; stage_v.add_child(body)

	var progress := HBoxContainer.new(); progress.alignment = BoxContainer.ALIGNMENT_CENTER
	progress.add_theme_constant_override("separation", 8); box.add_child(progress)
	var dots: Array = []
	for _i in slides.size():
		var dot := Panel.new(); dot.custom_minimum_size = Vector2(34, 6)
		progress.add_child(dot); dots.append(dot)

	var actions := HBoxContainer.new(); actions.add_theme_constant_override("separation", 8); box.add_child(actions)
	var back := Button.new(); back.text = "‹"; back.custom_minimum_size = Vector2(74, 62)
	back.add_theme_font_size_override("font_size", 30); back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	actions.add_child(back)
	var next := _wide_btn(UITheme.ACCENT); next.custom_minimum_size = Vector2(0, 62)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL; actions.add_child(next)
	var close := Button.new(); close.text = "×"; close.custom_minimum_size = Vector2(74, 62)
	close.add_theme_font_size_override("font_size", 26); close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	actions.add_child(close)

	var state := {"page": 0}
	var render := func() -> void:
		var page: int = int(state["page"])
		var slide: Array = slides[page]
		var accent: Color = slide[1]
		stage.add_theme_stylebox_override("panel", UITheme.action_card(accent))
		badge.add_theme_stylebox_override("panel", UITheme.icon_badge(accent, 64, 32))
		var badge_icon := badge.get_child(0) as TextureRect
		badge_icon.texture = _opt_tex(str(slide[0]))
		title.text = tr(str(slide[2])); body.text = tr(str(slide[3]))
		back.disabled = page == 0
		next.text = tr("Abrir o Basar!") if page == slides.size() - 1 else "%d / %d   →" % [page + 1, slides.size()]
		for i in dots.size():
			var c: Color = accent if i == page else UITheme.MUTED.darkened(0.45)
			(dots[i] as Panel).add_theme_stylebox_override("panel", UITheme.prog_fill(c))

	back.pressed.connect(func():
		if int(state["page"]) <= 0: return
		Fx.press(back); state["page"] = int(state["page"]) - 1; render.call()
	)
	next.pressed.connect(func():
		Fx.press(next); Audio.play("tap")
		if int(state["page"]) < slides.size() - 1:
			state["page"] = int(state["page"]) + 1; render.call()
			return
		_dismiss(layer); _switch_tab(0)
		_toast(tr("Compra drones e melhorias"), UITheme.ACCENT, "ic_drone")
		if is_instance_valid(_drone_btn): Fx.shimmer(_drone_btn, UITheme.ACCENT)
	)
	close.pressed.connect(func(): Fx.press(close); _dismiss(layer))
	render.call()
	Fx.shimmer(next, UITheme.ACCENT, true)

## First-launch ceremony: branded cover, drone fly-through, then UI cascade.
func _boot_intro(loaded: bool) -> void:
	# The opaque cover goes up FIRST, using PRESET_FULL_RECT (no viewport-size
	# math at all) so it hides the fully-built game instantly on frame 1 — even
	# though we then wait a couple of frames before laying out the title/drone.
	var layer := CanvasLayer.new(); layer.layer = 200
	add_child(layer)
	var cover := TextureRect.new()
	cover.texture = load("res://assets/fantasy/arcane_realm.webp")
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.modulate = Color(0.94, 0.91, 1.0, 1.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cover)
	# A restrained cinematic grade preserves the new key-art's gold detail while
	# guaranteeing clean title contrast across every phone crop.
	var grade := ColorRect.new(); grade.color = Color(0.035, 0.018, 0.075, 0.20)
	grade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade.mouse_filter = Control.MOUSE_FILTER_IGNORE; cover.add_child(grade)

	# Let the just-built UI settle its landscape layout for a couple of frames
	# before we start tweening the HUD/adbar in (the title/hero are anchored
	# full-rect / centred so they no longer need any viewport-size math).
	await get_tree().process_frame
	await get_tree().process_frame

	# Title occupies the calm upper sky; the generated griffin remains the single
	# hero instead of being covered by a second sprite. This reads like authored
	# key art rather than an illustration with UI dropped on its focal point.
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 32; box.offset_right = -32; box.offset_top = 64 + _safe_top
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(box)
	var eyebrow := _lbl("FANTASY  ·  IDLE  ·  TYCOON", 14, UITheme.CYAN)
	eyebrow.add_theme_font_override("font", UITheme.font("SemiBold"))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(eyebrow)
	var t1 := _lbl("ARCANE TRADE", 46, UITheme.INK)
	t1.add_theme_font_override("font", UITheme.font("Bold"))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(t1)
	var t2 := _lbl("EMPIRE", 27, UITheme.GOLD)
	t2.add_theme_font_override("font", UITheme.font("Bold"))
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_child(t2)

	# Bottom loading ceremony: a real branded transition instead of a timed blank
	# cover. It stays compact and never needs scrolling, even on short displays.
	var load_box := VBoxContainer.new()
	load_box.anchor_left = 0; load_box.anchor_right = 1
	load_box.anchor_top = 1; load_box.anchor_bottom = 1
	load_box.offset_left = 42; load_box.offset_right = -42
	load_box.offset_top = -118 - _safe_bottom; load_box.offset_bottom = -42 - _safe_bottom
	load_box.add_theme_constant_override("separation", 8); cover.add_child(load_box)
	var load_lbl := _lbl("A ABRIR ROTAS COMERCIAIS", 13, Color(0.86, 0.82, 0.91))
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; load_box.add_child(load_lbl)
	var load_bg := Panel.new(); load_bg.custom_minimum_size = Vector2(0, 7)
	load_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); load_box.add_child(load_bg)
	var load_fill := Panel.new(); load_fill.anchor_left = 0; load_fill.anchor_right = 0
	load_fill.anchor_top = 0; load_fill.anchor_bottom = 1
	load_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.GOLD)); load_bg.add_child(load_fill)

	# entrance: slow camera settle, then typography and loading progress
	cover.pivot_offset = cover.size * 0.5
	if not Fx.reduce_motion: cover.scale = Vector2(1.045, 1.045)
	eyebrow.modulate = Color(1, 1, 1, 0)
	t1.modulate = Color(1, 1, 1, 0); t2.modulate = Color(1, 1, 1, 0)
	load_box.modulate = Color(1, 1, 1, 0)
	if not Fx.reduce_motion:
		var intro := create_tween(); intro.set_parallel(true)
		intro.tween_property(cover, "scale", Vector2.ONE, 1.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		intro.tween_property(eyebrow, "modulate:a", 1.0, 0.30).set_delay(0.08)
		intro.tween_property(t1, "modulate:a", 1.0, 0.38).set_delay(0.17)
		intro.tween_property(t2, "modulate:a", 1.0, 0.38).set_delay(0.28)
		intro.tween_property(load_box, "modulate:a", 1.0, 0.28).set_delay(0.32)
		intro.tween_property(load_fill, "anchor_right", 1.0, 1.05).set_delay(0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		# one-shot light sweep across the wordmark once it's settled — a branded
		# reveal on the first-impression frame instead of a flat cross-fade.
		intro.chain().tween_callback(func():
			if is_instance_valid(t1): Fx.shimmer(t1, UITheme.GOLD)
			if is_instance_valid(load_fill): Fx.shimmer(load_fill, UITheme.CYAN)
		)
	else:
		eyebrow.modulate = Color.WHITE; t1.modulate = Color.WHITE; t2.modulate = Color.WHITE
		load_box.modulate = Color.WHITE; load_fill.anchor_right = 1.0

	_hud.offset_top = -160.0
	_map.zoom = 1.15

	var tw := create_tween()
	tw.tween_interval(1.45)   # let the authored key-art and brand land before revealing play
	tw.tween_property(cover, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(_hud, "offset_top", 20.0 + _safe_top, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_map, "zoom", 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(layer):
			layer.queue_free()
		_post_boot(loaded)
	)

# ── Background (layered depth) ────────────────────────────────────────────────

func _bg() -> void:
	var grad := Gradient.new(); grad.set_color(0, UITheme.BG0); grad.set_color(1, UITheme.BG1)
	var gt := GradientTexture2D.new(); gt.gradient = grad; gt.fill_from = Vector2(0,0); gt.fill_to = Vector2(0,1); gt.width = 16; gt.height = 128
	var bg := TextureRect.new(); bg.texture = gt; bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(bg)
	# aurora band glow near the top, behind HUD
	var aurora := _opt_tex("aurora_band")
	if aurora != null:
		var ab := TextureRect.new(); ab.texture = aurora
		ab.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ab.stretch_mode = TextureRect.STRETCH_SCALE
		ab.anchor_left = 0; ab.anchor_right = 1; ab.anchor_top = 0; ab.anchor_bottom = 0
		ab.offset_top = 0; ab.offset_bottom = 360
		ab.modulate = Color(1, 1, 1, 0.55); ab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ab)
		# slow breathing glow so the sky feels alive behind the HUD
		if not Fx.reduce_motion:
			var aur_tw := ab.create_tween().set_loops()
			aur_tw.tween_property(ab, "modulate:a", 0.72, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			aur_tw.tween_property(ab, "modulate:a", 0.42, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_map() -> void:
	_map = MAP_VIEW.new(); _map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map.management_panel_right = SIDE_PANEL_W
	add_child(_map)
	_map.city_selected.connect(_show_city_inspector)
	_map.investment_selected.connect(_open_investment_from_map)
	# vignette over the map (under the UI chrome added later)
	var vig := _opt_tex("vignette")
	if vig != null:
		var vr := TextureRect.new(); vr.texture = vig
		vr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; vr.stretch_mode = TextureRect.STRETCH_SCALE
		vr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vr.modulate = Color(1, 1, 1, 0.3); vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vr)

func _build_bonus_drone() -> void:
	_bonus = BONUS_DRONE.new()
	_bonus.caught.connect(_show_bonus_popup)
	add_child(_bonus)

# ── HUD ───────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	_hud = PanelContainer.new()
	_hud.anchor_left = 0; _hud.anchor_right = 1; _hud.anchor_top = 0; _hud.anchor_bottom = 0
	_hud.offset_left = GUTTER; _hud.offset_right = -GUTTER; _hud.offset_top = 20
	_hud.add_theme_stylebox_override("panel", UITheme.glass())
	add_child(_hud)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 7); _hud.add_child(v)

	# Row 1: stat chips (credits prominent)
	var r1 := HBoxContainer.new(); r1.add_theme_constant_override("separation", 6); v.add_child(r1)
	var c1 := _chip("ic_credits", UITheme.GOLD, 30, 26, true); _credits_lbl = c1["label"]; _credits_chip = c1["root"]; r1.add_child(c1["root"])
	# tap credits to see the exact numbers + full income multiplier breakdown
	_credits_chip.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
				or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			Fx.press(_credits_chip); Audio.play("tap")   # the HUD hero chip finally acknowledges its own tap
			_show_income_breakdown())
	# both secondary chips share one size (was 22 vs 21 — an imperceptible 1px
	# split that just fragmented the type ramp); the size step is the hero chip's
	var c2 := _chip("ic_gems", UITheme.CYAN, 22); _gems_lbl = c2["label"]; _gems_chip = c2["root"]; r1.add_child(c2["root"])
	var c3 := _chip("ic_prestige", UITheme.VIOLET, 22); _infl_lbl = c3["label"]; _infl_chip = c3["root"]; r1.add_child(c3["root"])
	_country_lbl = Label.new(); _country_lbl.add_theme_font_size_override("font_size", 17)
	_country_lbl.add_theme_color_override("font_color", UITheme.MUTED)
	r1.add_child(_country_lbl)
	_blessing_badge = PanelContainer.new(); _blessing_badge.add_theme_stylebox_override("panel", UITheme.solid(UITheme.GOLD, 14))
	var vb := HBoxContainer.new(); vb.add_theme_constant_override("separation", 3); _blessing_badge.add_child(vb)
	vb.add_child(_icon("ic_blessing", 18))
	var vl := Label.new(); vl.text = "Bênção"; vl.add_theme_font_size_override("font_size", 15)
	vl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	vl.add_theme_font_override("font", UITheme.font("Bold")); vb.add_child(vl)
	_blessing_badge.visible = false; r1.add_child(_blessing_badge)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; r1.add_child(sp)

	# Return reward, combo and live rate share the same compact resource rail.
	# Keeping every 44px+ target in one row gives the fantasy world another 44px
	# of vertical breathing room without sacrificing information or touch size.
	_streak_chip = PanelContainer.new()
	_streak_chip.custom_minimum_size = Vector2(92, 44)
	_streak_chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_streak_chip.tooltip_text = tr("Recompensa Diária")
	_streak_chip.add_theme_stylebox_override("panel", UITheme.stat_chip(UITheme.AMBER))
	_streak_chip.gui_input.connect(func(e: InputEvent):
		var tapped := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
			or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
		if tapped:
			Fx.press(_streak_chip)
			Audio.play("tap")
			_show_daily_popup()
	)
	var sh := HBoxContainer.new(); sh.add_theme_constant_override("separation", 3); _streak_chip.add_child(sh)
	sh.add_child(_icon("ic_streak", 18))
	_streak_lbl = Label.new(); _streak_lbl.add_theme_font_size_override("font_size", 15)
	_streak_lbl.add_theme_color_override("font_color", UITheme.AMBER)
	_streak_lbl.add_theme_font_override("font", UITheme.font("Bold")); sh.add_child(_streak_lbl)
	r1.add_child(_streak_chip)
	_combo_chip = PanelContainer.new()
	_combo_chip.add_theme_stylebox_override("panel", UITheme.stat_chip(UITheme.ORANGE))
	var cch := HBoxContainer.new(); cch.add_theme_constant_override("separation", 3); _combo_chip.add_child(cch)
	cch.add_child(_icon("ic_boost", 18))
	_combo_lbl = Label.new(); _combo_lbl.add_theme_font_size_override("font_size", 17)
	_combo_lbl.add_theme_color_override("font_color", UITheme.ORANGE)
	_combo_lbl.add_theme_font_override("font", UITheme.font("Bold")); cch.add_child(_combo_lbl)
	_combo_chip.visible = false; r1.add_child(_combo_chip)
	_income_lbl = Label.new(); _income_lbl.add_theme_font_size_override("font_size", 21)
	_income_lbl.add_theme_color_override("font_color", UITheme.GREEN)
	_income_lbl.add_theme_font_override("font", UITheme.font("Bold"))
	_income_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; r1.add_child(_income_lbl)
	var gear := Button.new(); gear.icon = _opt_tex("ic_gear")
	gear.expand_icon = true; gear.add_theme_constant_override("icon_max_width", 40)
	gear.custom_minimum_size = Vector2(64, 64)
	gear.add_theme_stylebox_override("normal", UITheme.nav_item(false))
	gear.add_theme_stylebox_override("hover",  UITheme.nav_item(true))
	gear.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	gear.pressed.connect(func(): Fx.press(gear); _show_settings()); r1.add_child(gear)

	# Row 3: progress ribbon (% to next unlock)
	_ribbon_bg = Panel.new(); _ribbon_bg.custom_minimum_size = Vector2(0, 8)
	_ribbon_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); v.add_child(_ribbon_bg)
	_ribbon_fill = Panel.new()
	_ribbon_fill.anchor_left = 0; _ribbon_fill.anchor_right = 0.0
	_ribbon_fill.anchor_top = 0; _ribbon_fill.anchor_bottom = 1
	_ribbon_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.ACCENT))
	_ribbon_bg.add_child(_ribbon_fill)
	# Smart objective ribbon: one tap opens the exact dashboard page containing
	# the recommended action. This replaces a passive, city-only caption.
	_next_obj_lbl = Button.new(); _next_obj_lbl.text = ""
	_next_obj_lbl.custom_minimum_size = Vector2(0, 44)
	_next_obj_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_obj_lbl.add_theme_font_size_override("font_size", 13)
	_next_obj_lbl.add_theme_font_override("font", UITheme.font("Bold"))
	_next_obj_lbl.add_theme_color_override("font_color", UITheme.MUTED)
	_next_obj_lbl.add_theme_color_override("font_hover_color", UITheme.INK)
	_next_obj_lbl.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_next_obj_lbl.add_theme_stylebox_override("hover", UITheme.nav_item(true))
	_next_obj_lbl.add_theme_stylebox_override("pressed", UITheme.nav_item(true))
	_next_obj_lbl.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_next_obj_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_next_obj_lbl.pressed.connect(_jump_to_objective)
	v.add_child(_next_obj_lbl)

	# Row 4: event banner (hidden when no event)
	_event_row = HBoxContainer.new(); _event_row.add_theme_constant_override("separation", 8)
	_event_row.visible = false; v.add_child(_event_row)
	_event_icon = _icon("ic_event", 24); _event_row.add_child(_event_icon)
	var ev_info := VBoxContainer.new(); ev_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _event_row.add_child(ev_info)
	_event_name_lbl = Label.new(); _event_name_lbl.add_theme_font_size_override("font_size", 17)
	_event_name_lbl.add_theme_font_override("font", UITheme.font("Bold")); ev_info.add_child(_event_name_lbl)
	_event_time_lbl = Label.new(); _event_time_lbl.add_theme_font_size_override("font_size", 20)
	_event_time_lbl.add_theme_font_override("font", UITheme.font("Bold"))
	_event_time_lbl.add_theme_color_override("font_color", UITheme.INK)
	_event_time_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; _event_row.add_child(_event_time_lbl)
	var bar_bg := Panel.new(); bar_bg.custom_minimum_size = Vector2(0, 8)
	bar_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); ev_info.add_child(bar_bg)
	_event_timer_bar = Panel.new()
	_event_timer_bar.anchor_left = 0; _event_timer_bar.anchor_right = 1
	_event_timer_bar.anchor_top = 0; _event_timer_bar.anchor_bottom = 1
	bar_bg.add_child(_event_timer_bar)

func _chip(icon: String, color: Color, lbl_size: int, icon_sz := 22, hero := false) -> Dictionary:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.hero_chip(color) if hero else UITheme.stat_chip(color))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 5 if hero else 4); pc.add_child(h)
	h.add_child(_icon(icon, icon_sz))
	var lbl := Label.new(); lbl.add_theme_font_size_override("font_size", lbl_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_override("font", UITheme.font("Bold")); h.add_child(lbl)
	return {"root": pc, "label": lbl}

# ── Map/page boundary ─────────────────────────────────────────────────────────

func _build_map_floor_anchor() -> void:
	_map_floor_anchor = Control.new()
	_map_floor_anchor.anchor_left = 0; _map_floor_anchor.anchor_right = 1
	_map_floor_anchor.anchor_top = 1; _map_floor_anchor.anchor_bottom = 1
	_map_floor_anchor.offset_top = -NAV_H
	_map_floor_anchor.offset_bottom = -NAV_H
	_map_floor_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_floor_anchor)

# ── Bottom bg ─────────────────────────────────────────────────────────────────

func _build_bottom_bg() -> void:
	_bottom_bg = Panel.new()
	_bottom_bg.anchor_left = 0; _bottom_bg.anchor_right = 0
	_bottom_bg.anchor_top = 0; _bottom_bg.anchor_bottom = 1
	_bottom_bg.offset_left = GUTTER; _bottom_bg.offset_right = SIDE_PANEL_W
	_bottom_bg.offset_top = LANDSCAPE_PANEL_TOP; _bottom_bg.offset_bottom = -NAV_H
	_bottom_bg.add_theme_stylebox_override("panel", UITheme.bottom_panel())
	_bottom_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_bottom_bg)

## First-session focus: modern tycoon games begin in the world with one obvious
## action. The full management dashboard is earned after the first meaningful
## purchase instead of competing with the city from the opening frame.
func _build_guided_action() -> void:
	_focus_card = PanelContainer.new()
	_focus_card.anchor_left = 0.5; _focus_card.anchor_right = 0.5
	_focus_card.anchor_top = 1.0; _focus_card.anchor_bottom = 1.0
	_focus_card.offset_left = -300.0; _focus_card.offset_right = 300.0
	_focus_card.offset_top = -212.0; _focus_card.offset_bottom = -86.0
	_focus_card.add_theme_stylebox_override("panel", UITheme.glass())
	add_child(_focus_card)
	var stack := VBoxContainer.new(); stack.add_theme_constant_override("separation", 8)
	_focus_card.add_child(stack)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 16)
	stack.add_child(row)
	row.add_child(_icon_badge("ic_drone", UITheme.GOLD, 66, 38))
	var copy := VBoxContainer.new(); copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER; copy.add_theme_constant_override("separation", 2)
	_focus_title = _lbl(tr("Começa a tua primeira rota comercial"), 22, UITheme.INK)
	_focus_title.add_theme_font_override("font", UITheme.font("Bold")); copy.add_child(_focus_title)
	_focus_detail = _lbl(tr("Contrata um correio grifo e vê a cidade ganhar vida."), 15, UITheme.MUTED)
	_focus_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; copy.add_child(_focus_detail)
	row.add_child(copy)
	_focus_btn = _buy_btn(UITheme.GREEN); _focus_btn.custom_minimum_size = Vector2(176, 64)
	_focus_btn.add_theme_font_size_override("font_size", 19)
	_focus_btn.pressed.connect(func():
		if not _can_tap(): return
		var income_before := GameState.income_per_sec()
		if GameState.buy_drones() > 0:
			Fx.press(_focus_btn); Audio.play("whoosh")
			_reward_fx(_focus_btn, UITheme.GOLD, "spark", 12)
			_show_income_gain(income_before, _focus_btn)
			_refresh_progressive_nav()
		else:
			Fx.error_shake(_focus_btn)
	)
	row.add_child(_focus_btn)
	var progress_bg := Panel.new(); progress_bg.custom_minimum_size = Vector2(0, 6)
	progress_bg.add_theme_stylebox_override("panel", UITheme.prog_bg())
	stack.add_child(progress_bg)
	_focus_prog_fill = Panel.new()
	_focus_prog_fill.anchor_top = 0; _focus_prog_fill.anchor_bottom = 1
	_focus_prog_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.GREEN))
	progress_bg.add_child(_focus_prog_fill)

# ── Pages ──────────────────────────────────────────────────────────────────────

func _build_pages() -> void:
	_pages = [_build_fleet_tab(), _build_cities_tab(), _build_talents_tab(),
			  _build_legado_tab(), _build_shop_tab(), _build_missions_tab()]
	for pg in _pages:
		add_child(pg)
		_make_scrollable(pg)
		_enable_page_mode(pg as ScrollContainer)

## Premium dashboard navigation: management content changes in discrete pages
## instead of moving behind a scrollbar. Three blocks plus the pager fit even
## the compact 720 px landscape height without touching the navigation bar.
func _enable_page_mode(sc: ScrollContainer) -> void:
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if sc.get_child_count() == 0: return
	var box := sc.get_child(0) as VBoxContainer
	_page_indices[sc] = 0

	var pager := HBoxContainer.new()
	pager.alignment = BoxContainer.ALIGNMENT_CENTER
	pager.add_theme_constant_override("separation", 12)
	pager.custom_minimum_size = Vector2(0, 48)
	pager.set_meta("page_pager", true)
	sc.set_meta("page_pager", pager)
	var prev := Button.new(); prev.text = "‹"; prev.custom_minimum_size = Vector2(64, 44)
	var status := _lbl("", 18, UITheme.CYAN); status.custom_minimum_size = Vector2(170, 0)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := Button.new(); next.text = "›"; next.custom_minimum_size = Vector2(64, 44)
	for button: Button in [prev, next]:
		button.add_theme_font_size_override("font_size", 25)
		button.add_theme_stylebox_override("normal", UITheme.nav_item(false))
		button.add_theme_stylebox_override("hover", UITheme.nav_item(true))
		button.add_theme_stylebox_override("pressed", UITheme.nav_item(true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	pager.add_child(prev); pager.add_child(status); pager.add_child(next)
	box.add_child(pager)
	_page_labels[sc] = status
	prev.pressed.connect(func():
		if not _can_tap(): return
		Fx.press(prev); _change_management_page(sc, -1)
	)
	next.pressed.connect(func():
		if not _can_tap(): return
		Fx.press(next); _change_management_page(sc, 1)
	)
	prev.set_meta("pager_peer", next)
	next.set_meta("pager_peer", prev)
	sc.set_meta("pager_prev", prev); sc.set_meta("pager_next", next)
	_page_gestures[sc] = {"delta": Vector2.ZERO, "locked": false}
	sc.gui_input.connect(func(event: InputEvent): _on_page_swipe(sc, event))
	_refresh_page_units(sc)
	_show_management_page(sc, 0)

## Rebuild page units after dynamic lists change. Containers marked
## `page_flatten` contribute their individual rows, preventing a tall city or
## achievement list from becoming one clipped, unreachable page item.
func _refresh_page_units(sc: ScrollContainer) -> void:
	if sc.get_child_count() == 0: return
	var box := sc.get_child(0) as VBoxContainer
	var items: Array = []
	for child in box.get_children():
		if child.get_meta("page_pager", false):
			continue
		if child.get_meta("page_flatten", false):
			for row in child.get_children():
				if row is CanvasItem and not row.is_queued_for_deletion():
					items.append(row)
		else:
			items.append(child)
	_page_groups[sc] = items

func _refresh_page_container(container: Control) -> void:
	var node: Node = container
	while node != null and not (node is ScrollContainer):
		node = node.get_parent()
	if node is ScrollContainer and _page_labels.has(node):
		_refresh_page_units(node as ScrollContainer)
		_show_management_page(node as ScrollContainer, int(_page_indices.get(node, 0)))

func _change_management_page(sc: ScrollContainer, delta: int) -> void:
	var before := int(_page_indices.get(sc, 0))
	_show_management_page(sc, before + delta)
	if int(_page_indices.get(sc, 0)) != before:
		Audio.play("page", 1.0, -5.0)

func _available_page_items(sc: ScrollContainer) -> Array:
	var items: Array = []
	if not _page_groups.has(sc): return items
	for candidate in _page_groups[sc]:
		var candidate_item := candidate as CanvasItem
		if bool(candidate_item.get_meta("progression_hidden", false)):
			candidate_item.visible = false
		else:
			items.append(candidate_item)
	return items

func _show_management_page(sc: ScrollContainer, requested: int) -> void:
	if not _page_groups.has(sc): return
	var items := _available_page_items(sc)
	var total := maxi(1, ceili(float(items.size()) / float(MANAGEMENT_PAGE_SIZE)))
	var old_page := int(_page_indices.get(sc, 0))
	var page := clampi(requested, 0, total - 1)
	_page_indices[sc] = page
	for i in range(items.size()):
		var item := items[i] as CanvasItem
		item.modulate.a = 1.0
		item.visible = floori(float(i) / float(MANAGEMENT_PAGE_SIZE)) == page
	var status: Label = _page_labels[sc]
	if total <= 7:
		var dots := PackedStringArray()
		for i in total:
			dots.append("●" if i == page else "•")
		status.text = "  ".join(dots)
	else:
		status.text = "%d / %d" % [page + 1, total]
	var prev := sc.get_meta("pager_prev") as Button
	var next := sc.get_meta("pager_next") as Button
	var pager := sc.get_meta("page_pager") as Control
	pager.visible = total > 1
	prev.disabled = page <= 0
	next.disabled = page >= total - 1
	call_deferred("_fit_management_panel", sc, total)
	# A restrained stagger makes the discrete page swap read as an intentional
	# dashboard transition instead of content abruptly blinking in and out.
	if page != old_page and not Fx.reduce_motion:
		var order := 0
		for i in range(items.size()):
			if floori(float(i) / float(MANAGEMENT_PAGE_SIZE)) != page: continue
			var item := items[i] as CanvasItem
			item.modulate.a = 0.0
			var tw := item.create_tween()
			tw.tween_interval(float(order) * 0.035)
			tw.tween_property(item, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			order += 1

## Every management page hugs its visible cards. Hidden catalogue entries and
## rows on neighbouring pages must never turn into an empty full-height slab
## over the world; tall pages still clamp safely against the navigation bar.
func _fit_management_panel(sc: ScrollContainer, total_pages: int) -> void:
	if not is_instance_valid(sc) or _pages.is_empty() or sc != _pages[_active_tab]:
		return
	var nav_top := size.y - NAV_H - _safe_bottom
	if sc.get_child_count() > 0:
		# VBoxContainer's combined minimum still includes progression-hidden rows
		# for part of the layout cycle. That made a one-offer shop reserve the full
		# dashboard height and leave a large dead violet slab over the city. Measure
		# the cards which are actually visible on the selected page instead.
		var content_height := 0.0
		var visible_count := 0
		for candidate in _available_page_items(sc):
			var item := candidate as Control
			if is_instance_valid(item) and item.is_visible_in_tree():
				content_height += item.get_combined_minimum_size().y
				visible_count += 1
		if visible_count > 1:
			content_height += float(visible_count - 1) * 11.0
		var pager := sc.get_meta("page_pager") as Control
		if total_pages > 1 and is_instance_valid(pager) and pager.is_visible_in_tree():
			content_height += pager.get_combined_minimum_size().y + 11.0
		var compact_bottom := minf(nav_top, sc.offset_top + maxf(96.0, content_height + 10.0))
		sc.anchor_bottom = 0.0
		sc.offset_bottom = compact_bottom
		_bottom_bg.anchor_bottom = 0.0
		_bottom_bg.offset_bottom = compact_bottom + 6.0

## Make the WHOLE card surface swipe-aware. Buttons stay usable but pass gesture
## events to the page container; non-interactive decoration never intercepts.
func _make_scrollable(n: Node) -> void:
	for child in n.get_children():
		if child is BaseButton:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		elif child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_make_scrollable(child)

## Horizontal swipe paging for touch and mouse. Vertical movement never scrolls
## the panel; it only cancels horizontal intent. Once a gesture turns into a
## swipe, purchase taps remain blocked through the release frame.
func _on_page_swipe(sc: ScrollContainer, event: InputEvent) -> void:
	if not _page_gestures.has(sc): return
	var gesture: Dictionary = _page_gestures[sc]
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			gesture["delta"] = Vector2.ZERO
			gesture["locked"] = false
		else:
			var touch_delta: Vector2 = gesture["delta"]
			if bool(gesture["locked"]) or touch_delta.length_squared() > 9.0:
				_tap_block_until = maxi(_tap_block_until, Time.get_ticks_msec() + 120)
			gesture["delta"] = Vector2.ZERO
			gesture["locked"] = false
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				gesture["delta"] = Vector2.ZERO
				gesture["locked"] = false
			else:
				var mouse_delta: Vector2 = gesture["delta"]
				if bool(gesture["locked"]) or mouse_delta.length_squared() > 9.0:
					_tap_block_until = maxi(_tap_block_until, Time.get_ticks_msec() + 120)
				gesture["delta"] = Vector2.ZERO
				gesture["locked"] = false
		return
	var relative := Vector2.ZERO
	if event is InputEventScreenDrag:
		relative = (event as InputEventScreenDrag).relative
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0: return
		relative = mm.relative
	else:
		return
	if gesture["locked"]: return
	var delta: Vector2 = gesture["delta"]
	delta += relative
	gesture["delta"] = delta
	if delta.length_squared() > 9.0:
		_tap_block_until = Time.get_ticks_msec() + 180
	if absf(delta.x) >= 72.0 and absf(delta.x) > absf(delta.y) * 1.25:
		gesture["locked"] = true
		sc.accept_event()
		_change_management_page(sc, 1 if delta.x < 0.0 else -1)

func _can_tap() -> bool:
	return Time.get_ticks_msec() >= _tap_block_until

# ── Nav bar ─────────────────────────────────────────────────────────────────────

func _build_nav() -> void:
	_nav_sep = ColorRect.new(); _nav_sep.color = UITheme.BORDER
	_nav_sep.anchor_left = 0; _nav_sep.anchor_right = 1; _nav_sep.anchor_top = 1; _nav_sep.anchor_bottom = 1
	_nav_sep.offset_top = -NAV_H - 1; _nav_sep.offset_bottom = -NAV_H
	_nav_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(_nav_sep)

	_nav_bar = HBoxContainer.new()
	_nav_bar.anchor_left = 0; _nav_bar.anchor_right = 1
	_nav_bar.anchor_top = 1; _nav_bar.anchor_bottom = 1
	_nav_bar.offset_top = -NAV_H; _nav_bar.offset_bottom = 0
	_nav_bar.add_theme_constant_override("separation", 0)
	add_child(_nav_bar)

	var defs := [["ic_nav_fleet","Frota"],["ic_nav_cities","Cidades"],
		["ic_nav_talents","Talentos"],["ic_nav_legado","Legado"],
		["ic_nav_shop","Loja"],["ic_nav_missions","Missões"]]
	for i in defs.size():
		_nav_bar.add_child(_make_nav_btn(defs[i][0], defs[i][1], i))

	# sliding accent indicator resting on top edge of the nav bar (glowing pill)
	_nav_ind = Panel.new()
	_nav_ind.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.ACCENT.lightened(0.15)))
	_nav_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nav_ind.anchor_left = 0; _nav_ind.anchor_right = 0
	_nav_ind.anchor_top = 1; _nav_ind.anchor_bottom = 1
	_nav_ind.offset_top = -NAV_H - 2; _nav_ind.offset_bottom = -NAV_H + 4
	add_child(_nav_ind)

func _make_nav_btn(icon_name: String, label_text: String, idx: int) -> Button:
	var btn := Button.new(); btn.text = ""
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, NAV_H)
	btn.add_theme_stylebox_override("normal",  UITheme.nav_item(false))
	btn.add_theme_stylebox_override("hover",   UITheme.nav_item(false))
	btn.add_theme_stylebox_override("pressed", UITheme.nav_item(true))
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

	var box := VBoxContainer.new(); box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE; btn.add_child(box)
	var ic := _icon(icon_name, 30); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE; box.add_child(ic)
	var lbl := Label.new(); lbl.text = tr(label_text); lbl.set_meta("i18n", label_text)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)

	# affordable dot (top-right)
	var dot := _icon("dot", 10); dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.modulate = UITheme.GOLD; dot.anchor_left = 1; dot.anchor_right = 1
	dot.anchor_top = 0; dot.anchor_bottom = 0
	dot.offset_left = -22; dot.offset_right = -10; dot.offset_top = 14; dot.offset_bottom = 26
	dot.visible = false; btn.add_child(dot)

	btn.pressed.connect(func(): Fx.press(btn); _switch_tab(idx))
	_nav_btns.append(btn); _nav_icons.append(ic); _nav_labels.append(lbl); _nav_dots.append(dot)
	return btn

func _switch_tab(i: int) -> void:
	if not _nav_unlocked(i):
		return
	_active_tab = i
	if _nav_sb_on == null:
		_nav_sb_on = UITheme.nav_item(true)
		_nav_sb_off = UITheme.nav_item(false)
	var dashboard_ready := _progression_stage() > 0
	for j in _pages.size():
		_pages[j].visible = dashboard_ready and (j == i)
	if i >= 0 and i < _pages.size():
		var active_page := _pages[i] as ScrollContainer
		_show_management_page(active_page, int(_page_indices.get(active_page, 0)))
		# The city catalogue spans several compact pages. Opening it should land on
		# the frontier settlement — the route the player can improve now or the
		# next city they can unlock — rather than on a redundant summary page.
		if i == 1:
			var frontier_row := _frontier_city_row()
			if is_instance_valid(frontier_row):
				_show_control_page(active_page, frontier_row)
	for j in _nav_btns.size():
		var active := (j == i)
		var btn: Button = _nav_btns[j]
		var ic: TextureRect = _nav_icons[j]
		var lbl: Label = _nav_labels[j]
		# nav_item() only ever yields two distinct boxes, so build them once rather
		# than allocating 12 fresh StyleBoxFlats per tab switch. Sharing one across
		# Controls is safe — the override connects CONNECT_REFERENCE_COUNTED.
		var sb: StyleBox = _nav_sb_on if active else _nav_sb_off
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover",  sb)
		ic.modulate = UITheme.ACCENT if active else UITheme.MUTED
		lbl.add_theme_color_override("font_color", UITheme.INK if active else UITheme.MUTED)
		var target := 1.12 if active else 1.0
		ic.pivot_offset = ic.size * 0.5
		# _stagger_in() honours reduce_motion but these nav tweens never did —
		# snap instead of animating (also skips 6 Tweens per switch).
		if Fx.reduce_motion:
			ic.scale = Vector2(target, target)
		else:
			var tw := ic.create_tween()
			tw.tween_property(ic, "scale", Vector2(target, target), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _nav_ind != null:
		var visible_tabs: Array[int] = []
		for nav_index in _nav_btns.size():
			if _nav_btns[nav_index].visible:
				visible_tabs.append(nav_index)
		var visible_pos := maxi(visible_tabs.find(i), 0)
		var bw := get_viewport_rect().size.x / float(maxi(visible_tabs.size(), 1))
		var pad := bw * 0.22
		if Fx.reduce_motion:
			_nav_ind.offset_left = bw * float(visible_pos) + pad
			_nav_ind.offset_right = bw * float(visible_pos + 1) - pad
		else:
			var tw2 := _nav_ind.create_tween()
			tw2.set_parallel(true)
			tw2.tween_property(_nav_ind, "offset_left", bw * float(visible_pos) + pad, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw2.tween_property(_nav_ind, "offset_right", bw * float(visible_pos + 1) - pad, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_stagger_in(i)

## Reveal one system at a time, only after its purpose is understandable.
func _progression_stage() -> int:
	var upgrade_total := 0
	for level: int in GameState.levels.values():
		upgrade_total += level
	# A prestige veteran has already learned every dashboard system. Resetting the
	# local city must not hide the shop, legacy, and research navigation again.
	if Prestige.count > 0:
		return 5
	if GameState.current_country >= 3:
		return 5
	if GameState.current_country >= 2:
		return 4
	if GameState.current_country >= 1:
		return 3
	if GameState.cities_unlocked >= 2:
		return 2
	if GameState.drones >= 4 or upgrade_total >= 2:
		return 1
	return 0

func _refresh_focus_action() -> void:
	if not is_instance_valid(_focus_card) or not _focus_card.visible:
		return
	var first_cost := GameState.drone_cost_multi(1)
	var income := GameState.income_per_sec()
	var waiting := GameState.credits < first_cost
	if GameState.drones <= 1:
		_focus_title.text = tr("Começa a tua primeira rota comercial")
		_focus_detail.text = tr("Contrata um correio grifo e vê a cidade ganhar vida.") \
			+ (_eta_suffix(first_cost, income) if waiting else "")
	else:
		_focus_title.text = tr("Comprar Drones") + "  ·  %d/4" % GameState.drones
		_focus_detail.text = tr("Tens %d drones") % GameState.drones \
			+ (_eta_suffix(first_cost, income) if waiting else "")
	if is_instance_valid(_focus_prog_fill):
		_set_fill(_focus_prog_fill, clampf(GameState.credits / first_cost, 0.0, 1.0))

func _nav_unlocked(tab_index: int) -> bool:
	var stage := _progression_stage()
	match tab_index:
		0: return true
		1: return stage >= 1
		5: return stage >= 2
		2: return stage >= 3
		4: return stage >= 4
		3: return stage >= 5
	return false

func _refresh_progressive_nav() -> void:
	if _nav_btns.is_empty():
		return
	var stage := _progression_stage()
	# Prestige can advance the paid catalogue without changing the navigation
	# stage, so refresh this before the cheap navigation early-out.
	_refresh_shop_catalog()
	if stage == _nav_stage:
		return
	var previous_stage := _nav_stage
	_nav_stage = stage
	var dashboard_ready := stage > 0
	_bottom_bg.visible = dashboard_ready
	_nav_bar.visible = dashboard_ready
	_nav_sep.visible = dashboard_ready
	_nav_ind.visible = dashboard_ready
	_focus_card.visible = not dashboard_ready
	# The opening action card is already the complete tutorial. Repeating that
	# objective in the global ribbon wastes city space and creates two competing
	# calls to action; the long-term advisor appears with the earned dashboard.
	_ribbon_bg.visible = dashboard_ready
	_next_obj_lbl.visible = dashboard_ready
	_gems_chip.visible = dashboard_ready
	_infl_chip.visible = dashboard_ready
	_country_lbl.visible = dashboard_ready
	_streak_chip.visible = dashboard_ready
	for i in _nav_btns.size():
		_nav_btns[i].visible = dashboard_ready and _nav_unlocked(i)
	if not _nav_unlocked(_active_tab):
		_active_tab = 0
	_switch_tab(_active_tab)
	# The fourth courier is the first chapter ending. Without an explicit hand-off,
	# the focused opening card simply vanished and a full dashboard appeared in its
	# place. Celebrate the learned loop, name the one newly relevant system and
	# point at its recommended construction card before anything else asks attention.
	if previous_stage == 0 and stage == 1:
		call_deferred("_reveal_first_dashboard_chapter")

func _reveal_first_dashboard_chapter() -> void:
	if _progression_stage() < 1 or not is_instance_valid(_rows.get("cargo", {}).get("card", null)):
		return
	var card := _rows["cargo"]["card"] as Control
	_toast(tr("Karawane bereit · Stadtaufbau freigeschaltet!"), UITheme.GOLD, "ic_city")
	_show_control_page(_pages[0] as ScrollContainer, card)
	Fx.shimmer(card, UITheme.GOLD, true)
	Fx.ring_pulse(card, card.size * 0.5, UITheme.GOLD, 1.8)
	Audio.play("milestone")
	Fx.vibrate(34)

## Fade-cascade the rows of the newly shown tab.
func _stagger_in(i: int) -> void:
	if Fx.reduce_motion: return
	if i < 0 or i >= _pages.size(): return
	var sc: ScrollContainer = _pages[i]
	if sc.get_child_count() == 0: return
	var vbox := sc.get_child(0)
	var k := 0
	for child in vbox.get_children():
		if not (child is CanvasItem): continue
		var ci := child as CanvasItem
		# Page management has already hidden every off-page catalogue row. Counting
		# those invisible rows delayed the pager by more than a second in the shop,
		# leaving a seemingly broken empty panel. Animate only what the player sees;
		# navigation itself remains immediately usable.
		if not ci.visible or bool(ci.get_meta("page_pager", false)):
			ci.modulate.a = 1.0
			continue
		ci.modulate = Color(1, 1, 1, 0)
		var tw := ci.create_tween()
		tw.tween_interval(float(k) * 0.04)
		tw.tween_property(ci, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		k += 1

# ── Scroll wrapper ──────────────────────────────────────────────────────────────

func _scroll(title: String) -> Array:
	var sc := ScrollContainer.new(); sc.name = title
	sc.anchor_left = 0; sc.anchor_right = 0
	sc.anchor_top = 0; sc.anchor_bottom = 1
	sc.offset_top = LANDSCAPE_PANEL_TOP; sc.offset_bottom = -NAV_H
	sc.offset_left = GUTTER + 6.0; sc.offset_right = SIDE_PANEL_W - 6.0
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 11)
	sc.add_child(v)
	return [sc, v]

# ── Section header (uppercase + hairline rule) ────────────────────────────────

func _section(text: String, color: Color, icon_name := "") -> Control:
	var wrap := VBoxContainer.new(); wrap.add_theme_constant_override("separation", 4)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6); wrap.add_child(h)
	if icon_name != "":
		h.add_child(_icon(icon_name, 22))
	# tr() explicitly BEFORE upper-casing: Label.text auto-translates on
	# assignment, so translating the already-uppercased string would look up
	# the wrong (uppercase) key in the CSV and silently miss.
	var l := Label.new(); l.text = tr(text).to_upper()
	l.set_meta("i18n", text)          # original key, re-uppercased on locale change
	_section_lbls.append(l)
	l.add_theme_font_size_override("font_size", 16); l.add_theme_font_override("font", UITheme.font("Bold"))
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
	var rule := Panel.new(); rule.custom_minimum_size = Vector2(0, 2)
	rule.add_theme_stylebox_override("panel", UITheme.section_rule()); wrap.add_child(rule)
	return wrap

# ── Fleet tab ───────────────────────────────────────────────────────────────────

func _build_fleet_tab() -> ScrollContainer:
	var r := _scroll("Frota"); var v: VBoxContainer = r[1]

	var seg_row := HBoxContainer.new(); seg_row.add_theme_constant_override("separation", 6); v.add_child(seg_row)
	for m: Array in [[1,"×1"],[10,"×10"],[100,"×100"],[-1,"Máx"]]:
		var mode_val: int = m[0]; var mode_lbl: String = m[1]
		var b := Button.new(); b.text = mode_lbl; b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 48); b.add_theme_font_size_override("font_size", 20)
		# cache both styleboxes once instead of allocating fresh ones every
		# _process() frame regardless of whether buy_mode actually changed
		b.set_meta("seg_off", UITheme.seg(false))
		b.set_meta("seg_on", UITheme.seg(true))
		b.add_theme_stylebox_override("normal",  b.get_meta("seg_off"))
		b.add_theme_stylebox_override("hover",   b.get_meta("seg_off"))
		b.add_theme_stylebox_override("pressed", b.get_meta("seg_on"))
		b.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
		b.pressed.connect(func(): GameState.buy_mode = mode_val; Fx.press(b))
		seg_row.add_child(b); _mode_btns[mode_val] = b

	var dr := _row(UITheme.ACCENT, "ic_drone")
	dr["title"].text = "Comprar Drones"
	_drone_detail = dr["detail"]
	_drone_btn = _cbuy(UITheme.GREEN, 160.0)
	_drone_btn.pressed.connect(func():
		if not _can_tap(): return
		var income_before := GameState.income_per_sec()
		if GameState.buy_drones() > 0:
			Fx.press(_drone_btn); Audio.play("whoosh")
			_reward_fx(_drone_btn, UITheme.ACCENT, "spark", 8)
			_show_income_gain(income_before, _drone_btn)
		else:
			Fx.error_shake(_drone_btn)
	)
	dr["right"].add_child(_drone_btn); v.add_child(dr["card"])

	for key: String in ["speed", "cargo", "value", "routes"]:
		v.add_child(_make_upgrade_row(key))

	_auto_mgr_section = _section("Gestor Automático", UITheme.VIOLET, "ic_blessing")
	_auto_mgr_section.set_meta("progression_hidden", true)
	_auto_mgr_section.visible = false
	v.add_child(_auto_mgr_section)
	_auto_mgr_toggle = _settings_toggle("Gestor de Frota Automático", GameState.auto_manager, func(on: bool):
		GameState.auto_manager = on; SaveSystem.save_game())
	_auto_mgr_toggle.set_meta("progression_hidden", true)
	_auto_mgr_toggle.visible = false
	_auto_mgr_toggle.tooltip_text = tr("Compra automaticamente a opção com maior ganho por moeda. Disponível para todos.")
	v.add_child(_auto_mgr_toggle)

	_prestige_section = _section("Prestige", UITheme.PRESTIGE, "ic_prestige")
	_prestige_section.set_meta("progression_hidden", true); v.add_child(_prestige_section)
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.prestige_card())
	_prestige_card = pp; _prestige_card.set_meta("progression_hidden", true); v.add_child(pp)
	var pv := VBoxContainer.new(); pv.add_theme_constant_override("separation", 8); pp.add_child(pv)
	_prestige_info_lbl = _lbl("", 16, UITheme.MUTED)
	_prestige_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(_prestige_info_lbl)
	_prestige_btn = Button.new(); _prestige_btn.add_theme_font_size_override("font_size", 22)
	_prestige_btn.add_theme_font_override("font", UITheme.font("Bold"))
	_prestige_btn.icon = _opt_tex("ic_prestige"); _prestige_btn.expand_icon = true
	_prestige_btn.add_theme_constant_override("icon_max_width", 26)
	_prestige_btn.custom_minimum_size = Vector2(0, 68)
	_prestige_btn.add_theme_stylebox_override("normal",   UITheme.prestige_btn_ready())
	_prestige_btn.add_theme_stylebox_override("hover",    UITheme.prestige_btn_ready())
	_prestige_btn.add_theme_stylebox_override("pressed",  UITheme.prestige_card())
	_prestige_btn.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	_prestige_btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	_prestige_btn.pressed.connect(func():
		if not _can_tap(): return
		Fx.press(_prestige_btn); _show_prestige_confirm()
	)
	pv.add_child(_prestige_btn)
	return r[0]

# ── Cities tab ──────────────────────────────────────────────────────────────────

func _build_cities_tab() -> ScrollContainer:
	var r := _scroll("Cidades"); var v: VBoxContainer = r[1]
	_progress_lbl = _lbl("", 17, UITheme.MUTED)
	_progress_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(_progress_lbl)
	var cpb := Panel.new(); cpb.custom_minimum_size = Vector2(0, 10)
	cpb.add_theme_stylebox_override("panel", UITheme.prog_bg()); v.add_child(cpb)
	_city_prog_fill = Panel.new()
	_city_prog_fill.anchor_left = 0; _city_prog_fill.anchor_right = 0.0
	_city_prog_fill.anchor_top = 0; _city_prog_fill.anchor_bottom = 1
	_city_prog_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.CYAN))
	cpb.add_child(_city_prog_fill)

	var er := _row(UITheme.GOLD, "ic_city")
	_expand_card = er["card"]
	er["title"].text = "Expandir país"
	er["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_expand_detail = er["detail"]
	_expand_btn = _cbuy(UITheme.GOLD.darkened(0.08), 150.0)
	_expand_btn.pressed.connect(func():
		if not _can_tap(): return
		if GameState.can_expand(): Fx.press(_expand_btn); _show_expansion_confirm()
		else: Fx.error_shake(_expand_btn)
	)
	er["right"].add_child(_expand_btn); v.add_child(_expand_card)
	_expand_card.set_meta("progression_hidden", not GameState.all_cities_unlocked())

	v.add_child(_section("Rede de cidades", UITheme.CYAN, "ic_city"))
	_city_list_box = VBoxContainer.new()
	_city_list_box.add_theme_constant_override("separation", 7)
	_city_list_box.set_meta("page_flatten", true)
	v.add_child(_city_list_box)
	_rebuild_city_list()
	return r[0]

## One compact status row per city of the current country (fills the Cidades tab).
func _rebuild_city_list() -> void:
	if _city_list_box == null: return
	_city_income_labels.clear()
	_city_rows.clear()
	for c in _city_list_box.get_children():
		c.queue_free()
	var ci := GameState.current_country
	var cities := Economy.country_cities(ci)
	for i in range(cities.size()):
		var city_index := i
		var row := Button.new()
		row.custom_minimum_size = Vector2(0, 50)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		row.set_meta("city_index", city_index)
		_city_rows[city_index] = row
		var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); row.add_child(h)
		var nm := _lbl(str(cities[i]["name"]), 17, UITheme.INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if i == 0:
			var base := UITheme.PANEL2.lerp(UITheme.GOLD, 0.10)
			row.add_theme_stylebox_override("normal", UITheme.solid(base, 14))
			row.add_theme_stylebox_override("hover", UITheme.solid(base.lightened(0.08), 14))
			row.add_theme_stylebox_override("pressed", UITheme.solid(base.darkened(0.08), 14))
			h.add_child(_icon("ic_city", 22)); h.add_child(nm)
			var tag := _lbl("SEDE", 16, UITheme.GOLD)
			tag.add_theme_font_override("font", UITheme.font("Bold")); h.add_child(tag)
			h.add_child(_lbl("›", 22, UITheme.GOLD))
			row.pressed.connect(func():
				if not _can_tap(): return
				Fx.press(row); _show_city_inspector(city_index)
			)
		elif i <= GameState.cities_unlocked:
			var base := UITheme.PANEL2.lerp(UITheme.CYAN, 0.08)
			row.add_theme_stylebox_override("normal", UITheme.solid(base, 14))
			row.add_theme_stylebox_override("hover", UITheme.solid(base.lightened(0.08), 14))
			row.add_theme_stylebox_override("pressed", UITheme.solid(base.darkened(0.08), 14))
			h.add_child(_icon("ic_range", 22)); h.add_child(nm)
			var income := _lbl("", 15, UITheme.GREEN)
			income.add_theme_font_override("font", UITheme.font("Bold")); h.add_child(income)
			_city_income_labels[i - 1] = income
			var city_level := GameState.city_development_level(i)
			var runes := _lbl("◆".repeat(city_level) + "◇".repeat(GameState.CITY_DEVELOPMENT_MAX - city_level), 15, UITheme.GOLD)
			runes.tooltip_text = tr("Nível de rota %d/%d · Renda +%s/s") % [
				city_level, GameState.CITY_DEVELOPMENT_MAX, Fmt.short(GameState.projected_city_development_gain(i))]
			h.add_child(runes); h.add_child(_lbl("›", 22, UITheme.CYAN))
			row.set_meta("development_level", city_level)
			row.pressed.connect(func():
				if not _can_tap(): return
				Fx.press(row); _show_city_inspector(city_index)
			)
		elif i == GameState.cities_unlocked + 1:
			var base := UITheme.PANEL2.lerp(UITheme.ACCENT, 0.10)
			row.add_theme_stylebox_override("normal", UITheme.solid(base, 14))
			row.add_theme_stylebox_override("hover", UITheme.solid(base.lightened(0.08), 14))
			row.add_theme_stylebox_override("pressed", UITheme.solid(base.darkened(0.08), 14))
			h.add_child(_icon("ic_city", 22)); h.add_child(nm)
			var reward_stack := VBoxContainer.new()
			reward_stack.alignment = BoxContainer.ALIGNMENT_CENTER
			reward_stack.add_theme_constant_override("separation", -2)
			var cost := _lbl(Fmt.short(Economy.city_unlock_cost(ci, GameState.cities_unlocked)), 15, UITheme.GOLD)
			cost.add_theme_font_override("font", UITheme.font("Bold")); reward_stack.add_child(cost)
			var projected_gain := GameState.projected_city_income_gain()
			var gain := _lbl("+" + Fmt.short(projected_gain) + "/s", 12, UITheme.GREEN)
			gain.add_theme_font_override("font", UITheme.font("Bold")); reward_stack.add_child(gain)
			h.add_child(reward_stack)
			h.add_child(_lbl("›", 22, UITheme.ACCENT))
			row.set_meta("projected_income_gain", projected_gain)
			row.tooltip_text = tr("Renda +%s/s") % Fmt.short(projected_gain)
			row.pressed.connect(func():
				if not _can_tap(): return
				Fx.press(row); _show_city_inspector(city_index)
			)
		else:
			var locked_style := UITheme.solid(UITheme.PANEL2.darkened(0.15), 14)
			row.add_theme_stylebox_override("normal", locked_style)
			row.add_theme_stylebox_override("disabled", locked_style)
			row.disabled = true
			nm.add_theme_color_override("font_color", UITheme.MUTED)
			h.add_child(_icon("ic_lock", 20)); h.add_child(nm)
		_make_scrollable(row)
		_city_list_box.add_child(row)
	call_deferred("_refresh_page_container", _city_list_box)
	_refresh_city_income_labels(GameState.income_per_sec())
	_sync_city_expansion_visibility(false)

func _sync_city_expansion_visibility(celebrate := false) -> void:
	if not is_instance_valid(_expand_card):
		return
	var unlocked := GameState.all_cities_unlocked()
	var changed := unlocked != _expand_panel_unlocked
	_expand_panel_unlocked = unlocked
	_expand_card.set_meta("progression_hidden", not unlocked)
	_refresh_page_container(_expand_card)
	if changed and unlocked and celebrate:
		_toast(tr("%s desbloqueada!") % tr("Expandir país"), UITheme.GOLD, "ic_city")
		if _active_tab == 1:
			_show_control_page(_pages[1] as ScrollContainer, _expand_card)
			Fx.shimmer(_expand_card, UITheme.GOLD)
			Fx.ring_pulse(_expand_card, _expand_card.size * 0.5, UITheme.GOLD, 1.7)

func _frontier_city_row() -> Control:
	if _city_rows.is_empty():
		return null
	var cities := Economy.country_cities(GameState.current_country)
	var frontier := clampi(GameState.cities_unlocked, 0, cities.size() - 1)
	if not GameState.all_cities_unlocked():
		frontier = clampi(GameState.cities_unlocked + 1, 1, cities.size() - 1)
	return _city_rows.get(frontier, null) as Control

func _refresh_city_income_labels(_realm_income: float) -> void:
	for route: int in _city_income_labels:
		var income_label := _city_income_labels[route] as Label
		if is_instance_valid(income_label):
			income_label.text = "+" + Fmt.short(GameState.route_income_per_sec(route)) + "/s"

# ── Talents tab ─────────────────────────────────────────────────────────────────

func _build_talents_tab() -> ScrollContainer:
	var r := _scroll("Talentos"); var v: VBoxContainer = r[1]
	var info := _lbl("Influência ganha-se ao expandir países.\nGasta-a em bónus válidos até ao próximo Prestige.", 16, UITheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(info)
	for key: String in Economy.TALENT_ORDER:
		v.add_child(_make_talent_row(key))
	return r[0]

# ── Legado tab ──────────────────────────────────────────────────────────────────

func _build_legado_tab() -> ScrollContainer:
	var r := _scroll("Legado"); var v: VBoxContainer = r[1]

	var ps_card := PanelContainer.new(); ps_card.add_theme_stylebox_override("panel", UITheme.prestige_card()); v.add_child(ps_card)
	var ps_v := VBoxContainer.new(); ps_v.add_theme_constant_override("separation", 6); ps_card.add_child(ps_v)
	var ps_h := HBoxContainer.new(); ps_h.add_theme_constant_override("separation", 6); ps_v.add_child(ps_h)
	ps_h.add_child(_icon("ic_prestige", 24))
	ps_h.add_child(_lbl("Sistema de Prestige", 21, UITheme.PRESTIGE))
	var ps_info := _lbl("Reinicia com multiplicador permanente.\nRequer 5.º país desbloqueado.", 15, UITheme.MUTED)
	ps_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ps_v.add_child(ps_info)

	# Prestige Gems balance — distinct from the HUD's Influência chip, which
	# players previously had no way to tell apart (same icon/colour, no label
	# anywhere showed the actual pgems total).
	var pg_row := HBoxContainer.new(); pg_row.add_theme_constant_override("separation", 6); ps_v.add_child(pg_row)
	pg_row.add_child(_icon("ic_prestige", 20))
	pg_row.add_child(_lbl("Gemas de Prestígio:", 15, UITheme.MUTED))
	_pgems_lbl = _lbl("0", 17, UITheme.PRESTIGE)
	_pgems_lbl.add_theme_font_override("font", UITheme.font("Bold")); pg_row.add_child(_pgems_lbl)

	v.add_child(_section("Loja de Prestige", UITheme.PRESTIGE, "ic_prestige"))
	_prestige_shop_box = VBoxContainer.new()
	_prestige_shop_box.add_theme_constant_override("separation", 11)
	_prestige_shop_box.set_meta("page_flatten", true)
	v.add_child(_prestige_shop_box)
	_rebuild_prestige_shop()

	v.add_child(_section("Conquistas", UITheme.GOLD, "ic_achieve"))
	_achieve_count_lbl = _lbl("", 15, UITheme.MUTED)
	v.add_child(_achieve_count_lbl)
	_achieve_box = VBoxContainer.new()
	_achieve_box.add_theme_constant_override("separation", 11)
	_achieve_box.set_meta("page_flatten", true)
	v.add_child(_achieve_box)
	_rebuild_achievements()
	return r[0]

## Rebuilds the Prestige Shop rows from scratch — used on tab build and after a
## full progress reset (buy states can't just be toggled back, each row wires
## its own one-shot "Obtido" callback state at construction time).
func _rebuild_prestige_shop() -> void:
	if _prestige_shop_box == null: return
	for c in _prestige_shop_box.get_children():
		c.queue_free()
	_prestige_shop_rows.clear()
	for id: String in Prestige.SHOP_ORDER:
		_prestige_shop_box.add_child(_make_prestige_shop_row(id))
	_prestige_shop_box.add_child(_make_ascendant_row())
	call_deferred("_refresh_page_container", _prestige_shop_box)

## Rebuilds the Achievements list from scratch — see _rebuild_prestige_shop.
## Cards differ structurally by done/secret state at construction time (extra
## checkmark icon, progress bar, or "???" secret text), so a reset needs a
## fresh build rather than toggling an existing row's fields.
func _rebuild_achievements() -> void:
	if _achieve_box == null: return
	for c in _achieve_box.get_children():
		c.queue_free()
	_achieve_cells.clear(); _achieve_prog_fills.clear(); _achieve_prog_lbls.clear()
	# unlocked ones sink to the bottom so the still-to-earn goals lead the list
	var ids: Array = Achievements.DEFS.keys()
	ids.sort_custom(func(a, b): return int(Achievements.is_done(a)) < int(Achievements.is_done(b)))
	for id: String in ids:
		_achieve_box.add_child(_make_achievement_row(id))
	if _achieve_count_lbl != null and is_instance_valid(_achieve_count_lbl):
		_achieve_count_lbl.text = tr("Desbloqueadas: %d / %d") % [Achievements.done_count(), Achievements.total_count()]
	call_deferred("_refresh_page_container", _achieve_box)

## Per-item icon so Legacy rows lead with the same circular icon-badge every
## other tab's rows have — the Legacy tab was the one place rows started straight
## into text with an empty right gutter, breaking the cross-tab card language.
const _PRESTIGE_ICONS := {
	"speed_5": "ic_speed", "cargo_5": "ic_cargo", "value_5": "ic_value",
	"offline_10": "ic_boost", "offline_20": "ic_boost", "drones_10": "ic_drone",
	"drones_25": "ic_drone", "guild_24h": "ic_blessing", "start_c2": "ic_range",
}

func _make_prestige_shop_row(id: String) -> PanelContainer:
	var item: Dictionary = Prestige.SHOP[id]
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.prestige_card())
	var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 10); pp.add_child(ph)
	ph.add_child(_icon_badge(_PRESTIGE_ICONS.get(id, "ic_prestige"), UITheme.VIOLET))
	var pv := VBoxContainer.new(); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(pv)
	pv.add_child(_lbl(item["name"], 19, UITheme.INK))
	var pd := _lbl(item["desc"], 16, UITheme.MUTED); pd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(pd)
	var pb := Button.new(); pb.text = str(int(item["cost"]))
	pb.icon = _opt_tex("ic_prestige"); pb.expand_icon = true; pb.add_theme_constant_override("icon_max_width", 20)
	pb.custom_minimum_size = Vector2(106, 52); pb.add_theme_font_size_override("font_size", 18)
	pb.add_theme_stylebox_override("normal",   UITheme.prestige_btn_ready())
	pb.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	pb.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	pb.pressed.connect(func():
		if not _can_tap(): return
		if Prestige.buy_shop(id):
			Fx.press(pb); Audio.play("buy"); _reward_fx(pb, UITheme.PRESTIGE, "gem", 8)
			pb.text = "Obtido"; pb.icon = _opt_tex("ic_check"); pb.disabled = true
		else:
			Fx.error_shake(pb)
	)
	if Prestige.has_shop(id):
		pb.text = "Obtido"; pb.icon = _opt_tex("ic_check"); pb.disabled = true
	ph.add_child(pb)
	_prestige_shop_rows[id] = {"btn": pb, "cost": int(item["cost"])}
	return pp

## Repeatable pgems sink at the end of the Prestige Shop list — unlike the
## fixed one-shot items above it, this one never shows "Obtido"; its cost/level
## text is refreshed every frame in _process() (see _ascendant_lbl/_ascendant_btn).
func _make_ascendant_row() -> PanelContainer:
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.prestige_card())
	var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 10); pp.add_child(ph)
	ph.add_child(_icon_badge("ic_prestige", UITheme.VIOLET))
	var pv := VBoxContainer.new(); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(pv)
	pv.add_child(_lbl(tr("Núcleo Ascendente"), 19, UITheme.INK))
	_ascendant_lbl = _lbl("", 16, UITheme.MUTED)
	_ascendant_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(_ascendant_lbl)
	_ascendant_btn = Button.new()
	_ascendant_btn.icon = _opt_tex("ic_prestige"); _ascendant_btn.expand_icon = true
	_ascendant_btn.add_theme_constant_override("icon_max_width", 20)
	_ascendant_btn.custom_minimum_size = Vector2(106, 52); _ascendant_btn.add_theme_font_size_override("font_size", 18)
	_ascendant_btn.add_theme_stylebox_override("normal",   UITheme.prestige_btn_ready())
	_ascendant_btn.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	_ascendant_btn.add_theme_stylebox_override("focus",    StyleBoxEmpty.new())
	_ascendant_btn.pressed.connect(func():
		if not _can_tap(): return
		if Prestige.buy_ascendant():
			Fx.press(_ascendant_btn); Audio.play("buy"); _reward_fx(_ascendant_btn, UITheme.PRESTIGE, "gem", 8)
		else:
			Fx.error_shake(_ascendant_btn)
	)
	ph.add_child(_ascendant_btn)
	return pp

func _make_achievement_row(id: String) -> PanelContainer:
	var def: Dictionary = Achievements.DEFS[id]
	var done: bool = Achievements.is_done(id)
	var secret: bool = bool(def.get("secret", false)) and not done
	var pp := PanelContainer.new(); pp.add_theme_stylebox_override("panel", UITheme.achievement_card(done))
	var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 10); pp.add_child(ph)
	var icon_lbl := Label.new(); icon_lbl.text = "?" if secret else str(def["icon"])
	icon_lbl.add_theme_font_size_override("font_size", 28); icon_lbl.custom_minimum_size = Vector2(34, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; ph.add_child(icon_lbl)
	var pv := VBoxContainer.new(); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; ph.add_child(pv)
	var name_lbl := _lbl("???" if secret else str(def["name"]), 18, UITheme.GOLD if done else UITheme.INK)
	name_lbl.add_theme_font_override("font", UITheme.font("Bold")); pv.add_child(name_lbl)
	var desc_lbl := _lbl("Conquista secreta." if secret else str(def["desc"]), 16, UITheme.MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; pv.add_child(desc_lbl)
	if not done and not secret:
		var prog := Achievements.progress(id)
		if prog.y > 0.0:
			var pb_bg := Panel.new(); pb_bg.custom_minimum_size = Vector2(0, 5)
			pb_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); pv.add_child(pb_bg)
			var pb_fill := Panel.new(); pb_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
			pb_fill.anchor_right = clampf(prog.x / prog.y, 0.0, 1.0)
			pb_fill.visible = pb_fill.anchor_right >= 0.02
			pb_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.GOLD))
			pb_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; pb_bg.add_child(pb_fill)
			var prog_lbl := _lbl("%s / %s" % [Fmt.short(prog.x), Fmt.short(prog.y)], 12, UITheme.MUTED)
			pv.add_child(prog_lbl)
			_achieve_prog_fills[id] = pb_fill
			_achieve_prog_lbls[id] = prog_lbl
	if done:
		ph.add_child(_icon("ic_check", 26))
	_achieve_cells[id] = pp
	return pp

# ── Shop tab ────────────────────────────────────────────────────────────────────

func _build_shop_tab() -> ScrollContainer:
	var r := _scroll("Loja"); var v: VBoxContainer = r[1]
	_iap_section = _section("Apoiar a guilda", UITheme.VIOLET, "ic_cash")
	v.add_child(_iap_section)
	_iap_intro_card = _card(UITheme.VIOLET); v.add_child(_iap_intro_card)
	var intro := VBoxContainer.new(); intro.add_theme_constant_override("separation", 3)
	_iap_intro_card.add_child(intro)
	var intro_title := _lbl("A tua cidade cresce primeiro", 18, UITheme.INK)
	intro_title.add_theme_font_override("font", UITheme.font("Bold")); intro.add_child(intro_title)
	var intro_detail := _lbl("Todas as rotas e reinos podem ser conquistados gratuitamente. As ofertas opcionais aparecem aos poucos, apenas depois de conheceres o seu valor.", 14, UITheme.MUTED)
	intro_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; intro.add_child(intro_detail)
	for product_id: String in Billing.PRODUCT_ORDER:
		v.add_child(_make_iap_row(product_id))
	_restore_iap_btn = _wide_btn(UITheme.VIOLET.darkened(0.18))
	_restore_iap_btn.text = tr("Restaurar compras")
	_restore_iap_btn.custom_minimum_size = Vector2(0, 54)
	_restore_iap_btn.pressed.connect(func():
		Fx.press(_restore_iap_btn)
		if not Billing.restore(): Fx.error_shake(_restore_iap_btn)
	)
	# Restoration is a platform requirement, but it does not need a mostly empty
	# second catalogue page. Keep the compact action inside the shop explanation.
	_restore_iap_btn.add_theme_font_size_override("font_size", 16)
	intro.add_child(_restore_iap_btn)

	var collection_section := _section("Coleção Arcana", UITheme.GOLD, "ic_gems")
	v.add_child(collection_section); _arcane_collection_nodes.append(collection_section)
	for id: String in Economy.GEM_SHOP_ORDER:
		var gem_card := _make_gem_row(id)
		v.add_child(gem_card); _arcane_collection_nodes.append(gem_card)

	var style_section := _section("Trajes de Mensageiro", UITheme.CYAN, "ic_drone")
	v.add_child(style_section); _courier_style_nodes.append(style_section)
	var sk_info := _lbl("Skins permanentes para a tua frota. Cada skin extra dá +2% de lucros.", 15, UITheme.MUTED)
	sk_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(sk_info); _courier_style_nodes.append(sk_info)
	for id: String in Economy.SKIN_ORDER:
		var skin_card := _make_skin_row(id)
		v.add_child(skin_card); _courier_style_nodes.append(skin_card)

	var daily_card := _card(UITheme.GOLD); v.add_child(daily_card)
	_daily_shop_card = daily_card
	var daily_v := VBoxContainer.new(); daily_v.add_theme_constant_override("separation", 4); daily_card.add_child(daily_v)
	var dch := HBoxContainer.new(); dch.add_theme_constant_override("separation", 6); daily_v.add_child(dch)
	dch.add_child(_icon("ic_daily", 22))
	dch.add_child(_lbl("Recompensa Diária", 20, UITheme.GOLD))
	var daily_info := _lbl("Faz login todos os dias para ganhar gemas e bónus!", 15, UITheme.MUTED)
	daily_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; daily_v.add_child(daily_info)
	var daily_btn := _wide_btn(UITheme.GOLD.darkened(0.06))
	daily_btn.text = "Abrir"
	daily_btn.custom_minimum_size = Vector2(0, 68)
	daily_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
	daily_btn.pressed.connect(func():
		Fx.press(daily_btn)
		if Daily.pending: _show_daily_popup()
		else: _toast("Já recebeste a recompensa de hoje!", UITheme.GOLD, "ic_daily")
	)
	daily_v.add_child(daily_btn)

	_refresh_shop_catalog()
	return r[0]

## Paid choices are earned context, never an opening-screen catalogue. Players
## first learn the core loop, then see permanent convenience, and only encounter
## consumable currency after completing a full run. No offer is ever modal.
func _shop_catalog_stage() -> int:
	if GameState.current_country < 1 and Prestige.count <= 0:
		return 0
	if Prestige.count >= 2:
		return 4
	if Prestige.count >= 1:
		return 3
	if GameState.current_country >= 3:
		return 2
	return 1

func _shop_product_unlocked(product_id: String, stage := -1) -> bool:
	var catalog_stage := _shop_catalog_stage() if stage < 0 else stage
	match product_id:
		"starter": return catalog_stage >= 1 and not Billing.owns(product_id)
		"vip", "perm_x2": return catalog_stage >= 2
		"gems_xs", "gems_s", "gems_m": return catalog_stage >= 3
		"gems_l", "gems_xl": return catalog_stage >= 4
	return false

func _refresh_shop_catalog() -> void:
	if _iap_rows.is_empty():
		return
	var catalog_stage := _shop_catalog_stage()
	for product_id: String in _iap_rows:
		var row: Dictionary = _iap_rows[product_id]
		var card := row.get("card") as CanvasItem
		if card != null:
			card.set_meta("progression_hidden", not _shop_product_unlocked(product_id, catalog_stage))
	if _iap_section != null:
		_iap_section.set_meta("progression_hidden", catalog_stage <= 0)
	if _iap_intro_card != null:
		_iap_intro_card.set_meta("progression_hidden", catalog_stage <= 0)
	# Utility purchases and cosmetics arrive only after the player has completed
	# a full run. Before then the shop explains its promise and offers at most the
	# small set of contextual permanent purchases earned by realm progress.
	var collection_unlocked := catalog_stage >= 3
	for node: Control in _arcane_collection_nodes:
		node.set_meta("progression_hidden", not collection_unlocked)
	for node: Control in _courier_style_nodes:
		node.set_meta("progression_hidden", not collection_unlocked)
	if _daily_shop_card != null:
		# The same reward already has a permanent HUD entry; duplicating it in the
		# shop creates clutter and makes the catalogue feel more aggressive.
		_daily_shop_card.set_meta("progression_hidden", true)
	var shop_page := _pages[4] as ScrollContainer if _pages != null and _pages.size() > 4 else null
	if shop_page != null and _page_labels.has(shop_page):
		_refresh_page_units(shop_page)
		_show_management_page(shop_page, int(_page_indices.get(shop_page, 0)))

func _make_iap_row(product_id: String) -> PanelContainer:
	var product: Dictionary = Billing.PRODUCTS[product_id]
	var icon_name := "ic_gems" if product_id.begins_with("gems_") else "ic_cash"
	var r := _row(UITheme.VIOLET, icon_name)
	r["title"].text = tr(str(product["name"]))
	r["detail"].text = tr(str(product["desc"]))
	r["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := _cbuy(UITheme.VIOLET.darkened(0.10), 112.0)
	btn.text = Billing.display_price(product_id)
	btn.pressed.connect(func():
		if not _can_tap(): return
		Fx.press(btn); Billing.buy(product_id)
	)
	r["right"].add_child(btn)
	_iap_rows[product_id] = {"card": r["card"], "btn": btn}
	_update_iap_row(product_id)
	return r["card"]

func _update_iap_row(product_id: String) -> void:
	if not _iap_rows.has(product_id): return
	var row: Dictionary = _iap_rows[product_id]
	var btn: Button = row["btn"]
	var owned := Billing.owns(product_id)
	btn.disabled = owned or not Billing.can_purchase_product(product_id)
	btn.text = "✓" if owned else Billing.display_price(product_id)

func _refresh_iap_prices() -> void:
	for product_id: String in Billing.PRODUCT_ORDER:
		_update_iap_row(product_id)

func _on_iap_purchased(product_id: String) -> void:
	_update_iap_row(product_id)
	_refresh_shop_catalog()
	if Billing.PRODUCTS.has(product_id):
		_toast(tr(str(Billing.PRODUCTS[product_id]["name"])), UITheme.GOLD, "ic_gems")

func _on_iap_failed(product_id: String, _reason: String) -> void:
	if _iap_rows.has(product_id): Fx.error_shake(_iap_rows[product_id]["btn"])

func _make_skin_row(id: String) -> PanelContainer:
	var p: Dictionary = Economy.SKINS[id]
	var body: Color = p["body"]
	var r := _row(body if id != "classic" else UITheme.CYAN, "ic_drone")
	r["title"].text = p["name"]
	r["detail"].text = p["desc"]; r["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := _cbuy(UITheme.CYAN.darkened(0.18), 120.0)
	btn.pressed.connect(func():
		if not _can_tap(): return
		if GameState.has_skin(id):
			if GameState.set_skin(id):
				Fx.press(btn); Audio.play("whoosh")
				_toast(tr("Skin ativa: %s") % tr(str(p["name"])), body, "ic_drone")
		elif GameState.buy_skin(id):
			Fx.press(btn); Audio.play("buy"); _reward_fx(btn, body, "gem", 8)
			_toast(tr("Nova skin: %s!") % tr(str(p["name"])), body, "ic_drone")
			Fx.confetti(self, Vector2(size.x * 0.5, size.y * 0.45), 24, [body, UITheme.CYAN, UITheme.GOLD])
		else:
			Fx.error_shake(btn)
	)
	r["right"].add_child(btn)
	_skin_rows[id] = {"btn": btn}
	return r["card"]

# ── Card / button widgets ─────────────────────────────────────────────────────

func _card(accent: Color) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UITheme.action_card(accent)); return p

func _wide_btn(color: Color) -> Button:
	var b := Button.new(); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 22); b.add_theme_font_override("font", UITheme.font("Bold"))
	b.add_theme_stylebox_override("normal",   UITheme.action_btn(color))
	b.add_theme_stylebox_override("hover",    UITheme.action_btn(color.lightened(0.10)))
	b.add_theme_stylebox_override("pressed",  UITheme.action_btn(color.darkened(0.12)))
	b.add_theme_stylebox_override("disabled", UITheme.action_btn_disabled())
	b.add_theme_stylebox_override("focus",    StyleBoxEmpty.new()); return b

## Buy button with cached normal/affordable styleboxes (no per-frame alloc).
func _buy_btn(color: Color) -> Button:
	var b := _wide_btn(color)
	b.set_meta("sb_n", b.get_theme_stylebox("normal"))   # _wide_btn already built this exact box
	b.set_meta("sb_a", UITheme.action_btn_affordable(color))
	return b

## Caching the styleboxes (above) killed the per-frame ALLOC, but applying one is
## the expensive half: Control has no equality check, so add_theme_stylebox_override
## fires NOTIFICATION_THEME_CHANGED every call -> Button::_shape() re-runs full text
## shaping + update_minimum_size() cascades a re-sort up the container chain. With
## 22 call sites in _process that was ~1320 forced re-shapes/sec for a state that
## flips a few times a minute. Only touch the button when it actually flipped.
func _afford(b: Button, affordable: bool) -> void:
	if not is_instance_valid(b): return
	if b.get_meta("sb_state", -1) == int(affordable): return   # -1 => first call always applies
	b.set_meta("sb_state", int(affordable))
	b.add_theme_stylebox_override("normal", b.get_meta("sb_a") if affordable else b.get_meta("sb_n"))

## Short "ready in Xm Ys" suffix for a not-yet-affordable cost's detail text —
## "" when already affordable or income is ~0. Takes the frame's already-computed
## income: going through GameState.eta_seconds() re-derived income_per_sec() (an
## O(cities) loop + ~7 pow()) per call, 2-3x per frame, on top of the one _process
## already holds. Same arithmetic as eta_seconds(), same branches.
func _eta_suffix(cost: float, ips: float) -> String:
	if cost <= GameState.credits or ips <= 0.01: return ""
	return "  ·  " + tr("pronto em %s") % Fmt.duration((cost - GameState.credits) / ips)

## Compact horizontal purchase row: [icon] [title+detail] [buy button].
## Returns {card, title, detail, right(HBox for the action button)}.
func _row(accent: Color, icon_name: String) -> Dictionary:
	var card := _card(accent)
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(_icon_badge(icon_name, accent))
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER; info.add_theme_constant_override("separation", 1)
	h.add_child(info)
	var title := _lbl("", 18, UITheme.INK); info.add_child(title)
	var detail := _lbl("", 15, UITheme.MUTED); info.add_child(detail)
	var right := HBoxContainer.new(); right.alignment = BoxContainer.ALIGNMENT_END
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(right)
	return {"card": card, "title": title, "detail": detail, "right": right}

## Compact fixed-width buy button (right-aligned in a row).
func _cbuy(color: Color, w := 150.0) -> Button:
	var b := _buy_btn(color)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	b.custom_minimum_size = Vector2(w, 54)
	b.add_theme_font_size_override("font_size", 19)
	return b

func _make_upgrade_row(key: String) -> PanelContainer:
	var accent_map := {"speed": UITheme.ACCENT, "cargo": UITheme.AMBER, "value": UITheme.GREEN, "routes": UITheme.CYAN}
	var accent: Color = accent_map.get(key, UITheme.ACCENT)
	var r := _row(accent, Economy.UPGRADES[key].get("icon", "ic_speed"))
	r["title"].text = tr(str(Economy.UPGRADES[key]["name"]))
	r["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := _cbuy(UITheme.GREEN)
	btn.pressed.connect(func():
		if not _can_tap(): return
		var income_before := GameState.income_per_sec()
		var before_level := int(GameState.levels[key])
		var before_tier := before_level / Economy.MILESTONE_STEP
		var before_stage: Dictionary = Economy.current_district_stage(key, before_level)
		if GameState.buy_upgrade_multi(key) > 0:
			Fx.press(btn); _reward_fx(btn, accent, "spark", 6)
			_show_income_gain(income_before, btn)
			var after_level := int(GameState.levels[key])
			var after_stage: Dictionary = Economy.current_district_stage(key, after_level)
			var landmark_built := not after_stage.is_empty() and str(after_stage.get("name", "")) != str(before_stage.get("name", ""))
			var milestone_crossed := after_level / Economy.MILESTONE_STEP > before_tier
			Audio.play_upgrade(key, landmark_built or milestone_crossed)
			if landmark_built:
				var landmark_name := tr(str(after_stage["name"]))
				_toast(tr("Construído: %s!") % landmark_name, UITheme.GOLD, str(Economy.UPGRADES[key].get("icon", "ic_city")))
				_map.reveal_landmark(key, landmark_name)
				var landmark_centre := Vector2(size.x * 0.62, size.y * 0.46)
				Fx.confetti(self, landmark_centre, 34, [UITheme.GOLD, accent, UITheme.CYAN])
				Fx.screen_flash(self, accent, 0.13)
				Fx.ring_pulse(self, landmark_centre, accent, 2.8)
				Fx.vibrate(42)
				_map.focus_city(0)
			elif milestone_crossed:
				_toast(tr("MARCO! %s ×2!") % tr(str(Economy.UPGRADES[key]["name"])), UITheme.GOLD, "ic_achieve")
				var c := Vector2(size.x * 0.5, size.y * 0.45)
				Fx.confetti(self, c, 30, [UITheme.GOLD, accent, UITheme.CYAN])
				Fx.screen_flash(self, UITheme.GOLD, 0.12)
				Fx.ring_pulse(self, c, UITheme.GOLD, 2.6)
		else:
			Fx.error_shake(btn)
	)
	r["right"].add_child(btn)
	_rows[key] = {"btn": btn, "title": r["title"], "detail": r["detail"]}
	_rows[key]["card"] = r["card"]
	return r["card"]

func _make_talent_row(key: String) -> PanelContainer:
	var p: Dictionary = Economy.TALENTS[key]
	var r := _row(UITheme.VIOLET, p.get("icon", "ic_prestige"))
	r["title"].text = p["name"]
	r["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := _cbuy(UITheme.VIOLET.darkened(0.10), 120.0)
	btn.icon = _opt_tex("ic_prestige"); btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 20)
	btn.pressed.connect(func():
		if not _can_tap(): return
		if GameState.buy_talent(key):
			Fx.press(btn); Audio.play("buy"); _reward_fx(btn, UITheme.VIOLET, "gem", 6)
		else:
			Fx.error_shake(btn)
	)
	r["right"].add_child(btn)
	_talent_rows[key] = {"btn": btn, "detail": r["detail"]}
	return r["card"]

func _make_gem_row(id: String) -> PanelContainer:
	var p: Dictionary = Economy.GEM_SHOP[id]
	var r := _row(UITheme.CYAN, p.get("icon", "ic_gems"))
	r["title"].text = p["name"]
	r["detail"].text = p["desc"]; r["detail"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var btn := _cbuy(UITheme.CYAN.darkened(0.18), 120.0)
	btn.icon = _opt_tex("ic_gems"); btn.expand_icon = true
	btn.add_theme_constant_override("icon_max_width", 20)
	btn.pressed.connect(func(): _buy_gem(id, btn))
	r["right"].add_child(btn)
	_gem_rows[id] = {"btn": btn}
	return r["card"]

## Small pinned corner badge for highlighting the best-value / recommended
## purchase. NOTE: PanelContainer is a real Container — unlike a plain
## Control (see the nav bar's affordable "dot"), it ignores a child's own
## anchors/offsets and stretches every direct child to the full content rect.
## The correct way to carve out a corner within a Container is size_flags
## (SHRINK_END/SHRINK_BEGIN), which lets the child collapse to its natural
## size and align within that shared rect instead of filling it.
func _add_ribbon(card: PanelContainer, text: String, color: Color) -> void:
	var rb := PanelContainer.new()
	rb.size_flags_horizontal = Control.SIZE_SHRINK_END
	rb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = color; sb.set_corner_radius_all(8)
	sb.content_margin_left = 8; sb.content_margin_right = 8
	sb.content_margin_top = 3; sb.content_margin_bottom = 3
	rb.add_theme_stylebox_override("panel", sb)
	var l := _lbl(text, 13, Color(0.08, 0.06, 0.0))
	l.add_theme_font_override("font", UITheme.font("Bold"))
	rb.add_child(l)
	card.add_child(rb)

func _buy_gem(id: String, btn: Button) -> void:
	if not _can_tap(): return
	var ok := false
	var grants_cash := false
	match id:
		"boost":      ok = GameState.buy_gem_boost()
		"cash":       ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["cash"]["cost"]), 3600.0); grants_cash = true
		"warp":       ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["warp"]["cost"]), 28800.0); grants_cash = true
		"warp24":     ok = GameState.buy_gem_cash(int(Economy.GEM_SHOP["warp24"]["cost"]), 86400.0); grants_cash = true
		"drone_pack": ok = GameState.buy_gem_drones(int(Economy.GEM_SHOP["drone_pack"]["cost"]), 10)
		"combo_time": ok = GameState.buy_gem_combo_time(int(Economy.GEM_SHOP["combo_time"]["cost"]))
	if ok:
		Fx.press(btn); Audio.play("buy"); _disp_credits = GameState.credits
		_reward_fx(btn, UITheme.CYAN, "gem", 7)
		if grants_cash: Fx.chip_pop(_credits_chip, UITheme.GOLD)
	else:
		Fx.error_shake(btn)

# ── Toasts ───────────────────────────────────────────────────────────────────────

func _build_toasts() -> void:
	_toasts = VBoxContainer.new(); _toasts.anchor_left = 0.5; _toasts.anchor_right = 0.5
	_toasts.offset_top = 166; _toasts.offset_left = -290; _toasts.offset_right = 290
	_toasts.alignment = BoxContainer.ALIGNMENT_CENTER; add_child(_toasts)

func _toast(text: String, accent: Color, icon_name := "") -> void:
	while _toasts.get_child_count() >= 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UITheme.toast(accent))
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8); pc.add_child(h)
	if icon_name != "":
		h.add_child(_icon(icon_name, 22))
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color.WHITE)
	# Milestones can name several newly earned systems. Keep every localized toast
	# inside the authored 580px lane instead of letting one long translation widen
	# the container beyond a small landscape phone.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h.add_child(l)
	_toasts.add_child(pc)
	pc.modulate = Color(1, 1, 1, 0); pc.position.y -= 8
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(pc, "modulate:a", 1.0, 0.18)
	tw.tween_property(pc, "position:y", pc.position.y + 8, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.0)
	tw.chain().tween_property(pc, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(pc.queue_free)

# ── Per-frame update ─────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_refresh_progressive_nav()
	_refresh_focus_action()
	_disp_credits = lerpf(_disp_credits, GameState.credits, clampf(delta * 8.0, 0.0, 1.0))
	if abs(_disp_credits - GameState.credits) < 1.0: _disp_credits = GameState.credits
	_credits_lbl.text = Fmt.short(_disp_credits)
	_gems_lbl.text    = str(GameState.gems)
	_infl_lbl.text    = (Prestige.tier_name() + " · " + str(GameState.influence)) if Prestige.count > 0 else str(GameState.influence)
	_blessing_badge.visible = GameState.is_guild_blessing_active()
	if _pgems_lbl != null and is_instance_valid(_pgems_lbl):
		_pgems_lbl.text = str(Prestige.pgems)
	if _ascendant_lbl != null and is_instance_valid(_ascendant_lbl):
		var alv := Prestige.ascendant_level; var acost := Prestige.ascendant_cost()
		_ascendant_lbl.text = tr("Nv %d · +%d%% permanente · repetível") % [alv, alv]
		_ascendant_btn.text = str(acost)
		_ascendant_btn.disabled = Prestige.pgems < acost

	# chip-pop on discrete currency increases
	if GameState.gems > _prev_gems: Fx.chip_pop(_gems_chip, UITheme.CYAN)
	if GameState.influence > _prev_infl: Fx.chip_pop(_infl_chip, UITheme.VIOLET)
	_prev_gems = GameState.gems; _prev_infl = GameState.influence

	var ips := GameState.income_per_sec()
	_income_lbl.text = "+" + Fmt.short(ips) + "/s"
	# Same no-equality-check trap as _afford(): re-applying the override fires
	# NOTIFICATION_THEME_CHANGED (font_dirty + an extra min-size push) every frame
	# for a colour that only moves when an event starts/ends, minutes apart.
	var inc_col: Color = Events.color() if Events.is_active() else UITheme.GREEN
	if inc_col != _prev_income_col:
		_prev_income_col = inc_col
		_income_lbl.add_theme_color_override("font_color", inc_col)
	var cm := GameState.combo_mult()
	if cm > 1.0:
		_combo_chip.visible = true
		_combo_lbl.text = "×%.2f" % cm
		if cm > _prev_combo_mult:
			Fx.chip_pop(_combo_chip, UITheme.ORANGE)
			var ctier: float = clampf((cm - 1.0) / 2.0, 0.0, 1.0)
			Audio.play("tap", 1.0 + ctier * 0.6, -3.0)
			Fx.vibrate(int(20.0 + ctier * 40.0))
			Fx.ring_pulse(_combo_chip, _combo_chip.size * 0.5, UITheme.ORANGE, 1.6)
	else:
		_combo_chip.visible = false
	_prev_combo_mult = cm

	var country_nm := Economy.country_name(GameState.current_country)
	_country_lbl.text = "%s · %d/%d" % [
		country_nm, GameState.current_country + 1, Economy.num_countries()]
	_refresh_daily_hud()

	_map.band_top    = _hud.position.y + _hud.size.y + 8.0
	_map.band_bottom = _map_floor_anchor.position.y - 8.0
	_bonus.band_top = _map.band_top
	_bonus.band_bottom = _map.band_bottom

	# Smart objective refreshes four times per second; the progress fill itself
	# remains frame-smooth while credits rise.
	if _objective_cache.is_empty() or Engine.get_frames_drawn() % 15 == 0:
		_refresh_smart_objective()
	_set_fill(_ribbon_fill, _objective_progress())
	# cities tab progress bar + the city button/detail block below both need
	# this — computed once here instead of twice per frame (each call does
	# two pow() calls internally)
	var next_city_cost := GameState.next_city_cost()
	_set_fill(_city_prog_fill, clampf(GameState.credits / next_city_cost, 0.0, 1.0) if next_city_cost > 0.0 else 1.0)

	if Events.is_active():
		_set_fill(_event_timer_bar, Events.time_pct())
		_event_time_lbl.text = Fmt.duration(Events.time_left())

	if GameState.buy_mode != _prev_buy_mode:
		for m in _mode_btns:
			var seg_btn: Button = _mode_btns[m]
			var active: bool = (GameState.buy_mode == int(m))
			var sb: StyleBox = seg_btn.get_meta("seg_on") if active else seg_btn.get_meta("seg_off")
			seg_btn.add_theme_stylebox_override("normal", sb)
			seg_btn.add_theme_stylebox_override("hover",  sb)
		_prev_buy_mode = GameState.buy_mode
	# Bulk purchasing is earned gradually instead of confronting a new player
	# with four equivalent controls. Existing saves derive prosperity from their
	# levels and therefore retain every mode they have already reached.
	for mode in _mode_btns:
		var required_rank := 0
		match int(mode):
			10: required_rank = 1
			100: required_rank = 2
			-1: required_rank = 3
		(_mode_btns[mode] as Button).visible = GameState.prosperity_rank >= required_rank

	var dc := GameState.drone_planned(); var dcost := GameState.drone_cost_multi(maxi(1, dc))
	_drone_btn.text     = (("×%d   " % dc) if GameState.buy_mode != 1 else "") + Fmt.short(dcost)
	_drone_btn.disabled = GameState.credits < dcost
	_afford(_drone_btn, not _drone_btn.disabled)
	_drone_detail.text  = (tr("Tens %d drones") % GameState.drones) + _eta_suffix(dcost, ips)
	if is_instance_valid(_focus_btn):
		_focus_btn.text = tr("Contratar") + "  ·  " + Fmt.short(dcost)
		_focus_btn.disabled = GameState.credits < dcost
		_afford(_focus_btn, not _focus_btn.disabled)

	# Automation is earned only after the player has learned the four manual
	# construction paths. Hiding both heading and toggle keeps the opening screen
	# focused, while existing saves retain access through derived prosperity.
	var auto_manager_unlocked := GameState.prosperity_rank >= 2
	if auto_manager_unlocked != _auto_manager_panel_unlocked:
		_auto_manager_panel_unlocked = auto_manager_unlocked
		_auto_mgr_section.set_meta("progression_hidden", not auto_manager_unlocked)
		_auto_mgr_toggle.set_meta("progression_hidden", not auto_manager_unlocked)
		_refresh_page_container(_auto_mgr_toggle)
	var prestige_panel_unlocked := GameState.current_country >= 3 or Prestige.count > 0
	if prestige_panel_unlocked != _prestige_panel_unlocked:
		_prestige_panel_unlocked = prestige_panel_unlocked
		_prestige_section.set_meta("progression_hidden", not prestige_panel_unlocked)
		_prestige_card.set_meta("progression_hidden", not prestige_panel_unlocked)
		_refresh_page_container(_prestige_card)
	# Construction paths enter the fleet pager only after their city chapter is
	# earned. Marking them as progression-hidden lets pagination remove them
	# entirely instead of leaving blank slots/pages.
	if _upgrade_unlock_rank != GameState.prosperity_rank:
		_sync_upgrade_unlocks()

	for key: String in _rows:
		var count := GameState.planned_count(key); var cost := GameState.upgrade_cost_multi(key, maxi(1, count))
		var row: Dictionary = _rows[key]
		var btn: Button = row["btn"]
		if not GameState.is_upgrade_unlocked(key):
			btn.disabled = true
			continue
		btn.text    = (("×%d   " % count) if GameState.buy_mode != 1 else "") + Fmt.short(cost)
		btn.disabled = GameState.credits < cost
		_afford(btn, not btn.disabled)
		var ulvl := int(GameState.levels[key])
		var projected_gain := GameState.projected_upgrade_income_gain(key, count, ips)
		var projected_text := Fmt.short(projected_gain)
		# the detail string only actually changes when level/count/cost move,
		# not every single frame — cache the last-rendered signature and skip
		# the tr()+%-format rebuild when nothing it depends on has changed
		var sig := [ulvl, count, cost, projected_text]
		if row.get("_sig") != sig:
			row["_sig"] = sig
			(row["title"] as Label).text = tr(str(Economy.UPGRADES[key]["name"])) + "  ·  " + tr("Nv %d") % ulvl
			var current_stage: Dictionary = Economy.current_district_stage(key, ulvl)
			var next_stage: Dictionary = Economy.next_district_stage(key, ulvl)
			var building_text := ""
			if current_stage.is_empty():
				building_text = tr("Primeira obra: %s no Nv %d") % [tr(str(next_stage["name"])), int(next_stage["level"])]
			elif next_stage.is_empty():
				building_text = tr("Obra atual: %s") % tr(str(current_stage["name"]))
			else:
				building_text = tr("%s · próxima obra: %s no Nv %d") % [tr(str(current_stage["name"])), tr(str(next_stage["name"])), int(next_stage["level"])]
			row["detail"].text = tr("Renda +%s/s") % projected_text + "  ·  " + building_text

	for key: String in _talent_rows:
		var tp: Dictionary = Economy.TALENTS[key]; var lvl := int(GameState.talents[key])
		# NOTE: named "trow" (not "tr") — "tr" would shadow the global tr()
		# translation function used two lines below.
		var trow: Dictionary = _talent_rows[key]
		var tbtn: Button = trow["btn"]
		if lvl >= int(tp["max"]):
			tbtn.text = tr("MÁX"); tbtn.disabled = true; tbtn.icon = null
		else:
			tbtn.text = str(GameState.talent_cost(key)); tbtn.disabled = not GameState.can_buy_talent(key)
		_afford(tbtn, not tbtn.disabled)
		# detail text only depends on lvl — skip the tr()+%-format rebuild on
		# frames where the talent level hasn't actually changed
		if trow.get("_lvl") != lvl:
			trow["_lvl"] = lvl
			var tdesc: String = _talent_effect_total(key, lvl) if lvl > 0 else str(tp["desc"])
			trow["detail"].text = tr("Nv %d/%d · %s") % [lvl, int(tp["max"]), tdesc]

	var gb: Dictionary = _gem_rows.get("boost", {})
	if not gb.is_empty():
		var bc := GameState.gem_boost_cost()
		var bbtn: Button = gb["btn"]
		bbtn.text = str(bc); bbtn.disabled = GameState.gems < bc; _afford(bbtn, not bbtn.disabled)
	for id: String in ["cash", "warp", "warp24", "drone_pack"]:
		var gr: Dictionary = _gem_rows.get(id, {})
		if not gr.is_empty():
			var c: int = int(Economy.GEM_SHOP[id]["cost"])
			var gbtn: Button = gr["btn"]
			gbtn.text = str(c); gbtn.disabled = GameState.gems < c; _afford(gbtn, not gbtn.disabled)
	for pid: String in _prestige_shop_rows:
		var prow: Dictionary = _prestige_shop_rows[pid]
		var pbtn: Button = prow["btn"]
		if not Prestige.has_shop(pid):
			# this button dims via its own "disabled" stylebox override (set
			# at construction) rather than the _afford()/_buy_btn() cached-
			# meta pattern used by _cbuy()-based buttons — no _afford() call
			# needed (calling it here crashed: this button never got the
			# sb_n/sb_a meta _afford() expects).
			pbtn.disabled = Prestige.pgems < int(prow["cost"])

	var gct: Dictionary = _gem_rows.get("combo_time", {})
	if not gct.is_empty():
		var ct_btn: Button = gct["btn"]
		if GameState.combo_window_bonus > 0.0:
			ct_btn.text = tr("Obtido"); ct_btn.disabled = true; ct_btn.icon = null
			_afford(ct_btn, false)
		else:
			var cc2: int = int(Economy.GEM_SHOP["combo_time"]["cost"])
			ct_btn.text = str(cc2); ct_btn.disabled = GameState.gems < cc2
			_afford(ct_btn, not ct_btn.disabled)

	for sid: String in _skin_rows:
		var sbtn: Button = _skin_rows[sid]["btn"]
		if GameState.skin_active == sid:
			sbtn.text = tr("Ativa"); sbtn.disabled = true; sbtn.icon = _opt_tex("ic_check")
			_afford(sbtn, false)
		elif GameState.has_skin(sid):
			sbtn.text = tr("Usar"); sbtn.disabled = false; sbtn.icon = null
			_afford(sbtn, true)
		else:
			var scost: int = int(Economy.SKINS[sid]["cost"])
			sbtn.text = str(scost); sbtn.icon = _opt_tex("ic_gems")
			sbtn.disabled = GameState.gems < scost
			_afford(sbtn, not sbtn.disabled)

	_progress_lbl.text = tr("%s — %d/%d cidades abertas.") % [country_nm, GameState.cities_unlocked, GameState.max_cities()]
	var ec := GameState.expand_cost()
	if ec < 0.0:
		_expand_btn.disabled = true; _expand_btn.text = tr("FIM")
		_expand_detail.text = tr("Chegaste ao último país. Parabéns!")
	elif not GameState.all_cities_unlocked():
		_expand_btn.disabled = true; _expand_btn.text = tr("Bloqueado")
		_expand_detail.text = tr("Abre todas as cidades de %s primeiro.") % Economy.country_name(GameState.current_country)
	else:
		_expand_btn.text = Fmt.short(ec); _expand_btn.disabled = GameState.credits < ec
		_expand_detail.text = (tr("Seguinte: %s · nova cidade · +%d Influência") % [Economy.country_name(GameState.current_country + 1), GameState.expansion_influence_reward()]) + _eta_suffix(ec, ips)
	_afford(_expand_btn, not _expand_btn.disabled and ec >= 0.0 and GameState.all_cities_unlocked())

	# prestige button — pgems_on_next_prestige() depends on current_country
	# even while ready stays true, so the BUTTON text stays unconditional;
	# but the INFO LABEL only actually changes when readiness flips (reaching
	# country 5, or a prestige just reset it below that) — the same
	# transition _prestige_ready_prev already detects for breathe() below —
	# so gate its tr()+%-format rebuild on that instead of every frame.
	# (`or _prestige_info_lbl.text == ""` forces the very first frame, since
	# ready and _prestige_ready_prev both start false and would otherwise
	# never differ before the player's first readiness transition.)
	var ready := Prestige.can_prestige()
	_prestige_btn.disabled = not ready
	if ready:
		_prestige_btn.text = tr("Prestige") + "  (+%d)" % Prestige.pgems_on_next_prestige()
	else:
		_prestige_btn.text = tr("Prestige (requer 5.º país)")
	if ready != _prestige_ready_prev or _prestige_info_lbl.text == "":
		if ready:
			_prestige_info_lbl.text = tr("Tier: %s · Prestige #%d · ×%.2f\nReinicias mantendo gemas e conquistas.") % [Prestige.tier_name(), Prestige.count + 1, Prestige.effective_mult() * 1.15]
		else:
			_prestige_info_lbl.text = tr("Chega ao 5.º país para fazer prestige.\nTier: %s · Prestige %d · ×%.2f") % [Prestige.tier_name(), Prestige.count, Prestige.effective_mult()]
		if ready != _prestige_ready_prev:
			Fx.breathe(_prestige_btn, ready)
		_prestige_ready_prev = ready

	_update_nav_dots()

	if Engine.get_frames_drawn() % 15 == 0:
		_refresh_city_income_labels(ips)
		_update_contracts()
	if Engine.get_frames_drawn() % 30 == 0 and _settings_stats_lbl != null:
		if is_instance_valid(_settings_stats_lbl):
			_settings_stats_lbl.text = _settings_stats_text()
		else:
			_settings_stats_lbl = null

	if Engine.get_frames_drawn() % 60 == 0:
		Achievements.check("income_1k",    ips >= 1000.0)
		Achievements.check("income_1m",    ips >= 1_000_000.0)
		Achievements.check("credits_1m",   GameState.credits >= 1_000_000.0)
		Achievements.check("credits_1b",   GameState.credits >= 1_000_000_000.0)
		Achievements.check("credits_1t",   GameState.credits >= 1_000_000_000_000.0)
		Achievements.check("earned_10b",   GameState.total_earned >= 10_000_000_000.0)
		Achievements.check("earned_1t",    GameState.total_earned >= 1_000_000_000_000.0)
		Achievements.check("influence_50", GameState.influence_total >= 50)
		Achievements.check("gems_100",     GameState.gems >= 100)
		_check_income_milestones(ips)
		for id: String in _achieve_prog_fills:
			if Achievements.is_done(id): continue
			# income_1k/income_1m would otherwise call Achievements.progress(),
			# which independently recomputes gs.income_per_sec() (an O(cities)
			# loop with pow() calls) — reuse the `ips` already computed above
			var prog := Vector2(ips, 1000.0) if id == "income_1k" else (Vector2(ips, 1_000_000.0) if id == "income_1m" else Achievements.progress(id))
			if prog.y > 0.0:
				_set_fill(_achieve_prog_fills[id] as Panel, clampf(prog.x / prog.y, 0.0, 1.0))
				(_achieve_prog_lbls[id] as Label).text = "%s / %s" % [Fmt.short(prog.x), Fmt.short(prog.y)]

## Hide near-zero fills: rounded corners + glow made sub-pixel fills render as
## floating glowing dots.
func _set_fill(p: Panel, pct: float) -> void:
	p.anchor_right = pct
	p.visible = pct >= 0.02

## Chooses the most useful action available now. Ready rewards and major
## progression beats outrank routine purchases; otherwise the advisor picks an
## affordable early-growth action before returning to the next unlock target.
func _smart_objective() -> Dictionary:
	# The opening chapter has exactly one job. Persisted contracts, daily state or
	# veteran-side systems must never compete with the guided courier card before
	# the player has completed that first meaningful action.
	if _progression_stage() == 0 and GameState.drones <= 1:
		return {"text": tr("Começa a tua primeira rota comercial"), "tab": 0,
			"focus": _focus_btn, "cost": GameState.drone_cost_multi(1), "progress": 0.0,
			"accent": UITheme.GOLD, "icon": "ic_drone"}
	if _progression_stage() == 0:
		return _courier_objective()
	# Finish the first two local construction chapters before unrelated rewards or
	# an already-affordable settlement can pull the player away. This repeats in
	# every fresh realm: rank 2 is the hand-off after routes and automation exist.
	if _opening_city_chapter_active():
		if GameState.drones < 4:
			return _courier_objective()
		return _prosperity_objective()
	# The first local improvement completes the capital-to-network hand-off. It is
	# part of the core loop, so a stored side reward must not steal focus during
	# this one teaching beat. Later city levels remain optional.
	var frontier_city := GameState.cities_unlocked
	if frontier_city > 0 and GameState.city_development_level(frontier_city) == 0:
		var frontier_cities := Economy.country_cities(GameState.current_country)
		return {"text": tr("Próximo: desenvolver %s") % frontier_cities[frontier_city]["name"],
			"city_index": frontier_city, "cost": GameState.city_development_cost(frontier_city),
			"progress": 0.0, "accent": UITheme.CYAN, "icon": "ic_range"}
	# Complete the first network lesson before side rewards resume: once Runenhafen
	# has been improved, its visible route leads directly to the next construction
	# site. The cost-driven objective remains useful throughout the saving period.
	if GameState.cities_unlocked == 1 and not GameState.all_cities_unlocked():
		var first_network_cities := Economy.country_cities(GameState.current_country)
		var first_frontier_idx := 2
		return {"text": tr("Próximo: abrir %s") % first_network_cities[first_frontier_idx]["name"],
			"city_index": first_frontier_idx, "cost": GameState.next_city_cost(), "progress": 0.0,
			"accent": UITheme.CYAN, "icon": "ic_city"}
	for i in range(Contracts.slots.size()):
		var contract: Dictionary = Contracts.slots[i]
		if contract.get("ready", false) and not contract.get("claimed", false):
			var claim_focus: Control = _mission_claim_btns[i] if i < _mission_claim_btns.size() else null
			return {"text": tr("REIVINDICAR") + " · " + tr("Missões"),
				"tab": 5, "focus": claim_focus, "cost": -1.0, "progress": 1.0,
				"accent": UITheme.GREEN, "icon": "ic_achieve"}
	if Prestige.can_prestige():
		return {"text": tr("Próximo: Prestige disponível!"), "tab": 0,
			"focus": _prestige_btn, "cost": -1.0, "progress": 1.0,
			"accent": UITheme.PRESTIGE, "icon": "ic_prestige"}
	if GameState.can_unlock_city():
		var ready_cities := Economy.country_cities(GameState.current_country)
		var ready_city_idx := clampi(GameState.cities_unlocked + 1, 1, ready_cities.size() - 1)
		return {"text": tr("Próximo: abrir %s") % ready_cities[ready_city_idx]["name"], "tab": 1,
			"focus": _city_rows.get(ready_city_idx), "cost": GameState.next_city_cost(), "progress": 1.0,
			"accent": UITheme.CYAN, "icon": "ic_city"}
	if GameState.can_expand():
		return {"text": tr("Próximo: expandir para %s") % Economy.country_name(GameState.current_country + 1),
			"tab": 1, "focus": _expand_btn, "cost": GameState.expand_cost(), "progress": 1.0,
			"accent": UITheme.GOLD, "icon": "ic_range"}
	# Keep the first few minutes simple: establish the courier loop before
	# suggesting one of four similarly-priced stat upgrades.
	if GameState.drones < 4:
		return _courier_objective()
	# The opening city is organised into short, visible construction chapters.
	# Point to the best immediate income gain per credit so the player has one
	# concrete, economically meaningful action instead of four equal choices.
	var prosperity_target: int = GameState.next_prosperity_threshold()
	if prosperity_target > 0:
		return _prosperity_objective()
	for key: String in Economy.TALENT_ORDER:
		if GameState.can_buy_talent(key):
			var talent_focus: Control = _talent_rows[key]["btn"] if _talent_rows.has(key) else null
			return {"text": tr(str(Economy.TALENTS[key]["name"])), "tab": 2,
				"focus": talent_focus, "cost": -1.0, "progress": 1.0,
				"accent": UITheme.CYAN, "icon": str(Economy.TALENTS[key].get("icon", "ic_prestige"))}
	for key: String in ["speed", "cargo", "value", "routes"]:
		var upgrade_cost := GameState.upgrade_cost_multi(key, 1)
		if GameState.credits >= upgrade_cost:
			var upgrade_focus: Control = _rows[key]["btn"] if _rows.has(key) else null
			return {"text": tr(str(Economy.UPGRADES[key]["name"])), "tab": 0,
				"focus": upgrade_focus, "cost": upgrade_cost, "progress": 1.0,
				"accent": UITheme.ACCENT, "icon": str(Economy.UPGRADES[key].get("icon", "ic_value"))}
	if not GameState.all_cities_unlocked():
		var pending_cities := Economy.country_cities(GameState.current_country)
		var pending_city_idx := clampi(GameState.cities_unlocked + 1, 1, pending_cities.size() - 1)
		return {"text": tr("Próximo: abrir %s") % pending_cities[pending_city_idx]["name"], "tab": 1,
			"focus": _city_rows.get(pending_city_idx), "cost": GameState.next_city_cost(), "progress": 0.0,
			"accent": UITheme.CYAN, "icon": "ic_city"}
	var expand_cost := GameState.expand_cost()
	if expand_cost >= 0.0:
		return {"text": tr("Próximo: expandir para %s") % Economy.country_name(GameState.current_country + 1),
			"tab": 1, "focus": _expand_btn, "cost": expand_cost, "progress": 0.0,
			"accent": UITheme.GOLD, "icon": "ic_range"}
	return {"text": tr("Próximo: 5.º país para Prestige"), "tab": 0,
		"focus": _prestige_btn, "cost": -1.0,
		"progress": clampf(float(GameState.current_country + 1) / float(Prestige.MIN_COUNTRY + 1), 0.0, 1.0),
		"accent": UITheme.PRESTIGE, "icon": "ic_prestige"}

func _opening_city_chapter_active() -> bool:
	return GameState.cities_unlocked == 1 and GameState.prosperity_rank < 2

func _courier_objective() -> Dictionary:
	const OPENING_FLEET_TARGET := 4
	return {"text": tr("Comprar Drones") + "  ·  %d/%d" % [GameState.drones, OPENING_FLEET_TARGET],
		"tab": 0, "focus": _drone_btn, "cost": GameState.drone_cost_multi(1),
		"progress": clampf(float(GameState.drones) / float(OPENING_FLEET_TARGET), 0.0, 1.0),
		"progress_override": true, "accent": UITheme.ACCENT, "icon": "ic_drone"}

func _prosperity_objective() -> Dictionary:
	var prosperity_target: int = GameState.next_prosperity_threshold()
	var recommended_key: String = GameState.recommended_upgrade_key()
	var recommended_cost: float = GameState.upgrade_cost_multi(recommended_key, 1)
	var reward: Dictionary = GameState.next_prosperity_reward()
	var reward_text := "+" + Fmt.short(float(reward.get("cash", 0.0)))
	var reward_gems := int(reward.get("gems", 0))
	if reward_gems > 0:
		reward_text += " +%d◆" % reward_gems
	var prosperity_focus: Control = _rows[recommended_key]["btn"] if _rows.has(recommended_key) else null
	var objective_text := tr("Cidade em construção %d/%d · Prémio: %s") % [GameState.investment_total(), prosperity_target, reward_text]
	var next_unlock := _next_prosperity_unlock_text()
	if not next_unlock.is_empty():
		objective_text = tr("Cidade em construção %d/%d · Próxima: %s") % [GameState.investment_total(), prosperity_target, next_unlock]
	return {"text": objective_text,
		"tab": 0, "focus": prosperity_focus, "cost": recommended_cost,
		"progress": GameState.prosperity_chapter_progress(),
		"progress_override": true, "accent": UITheme.GOLD,
		"upgrade_key": recommended_key,
		"icon": str(Economy.UPGRADES[recommended_key].get("icon", "ic_city"))}

func _next_prosperity_unlock_text() -> String:
	match GameState.prosperity_rank:
		0:
			return tr("Reisetempo") + " + " + tr("Handelswert")
		1:
			return tr("Handelsrouten") + " + " + tr("Gestor de Frota Automático")
	return ""

func _refresh_smart_objective() -> void:
	_objective_cache = _smart_objective()
	_map.set_recommended_investment(str(_objective_cache.get("upgrade_key", "")))
	var accent: Color = _objective_cache.get("accent", UITheme.ACCENT)
	_next_obj_lbl.text = "✦  " + str(_objective_cache.get("text", "")) + "   ›"
	_next_obj_lbl.icon = _opt_tex(str(_objective_cache.get("icon", "ic_range")))
	_next_obj_lbl.expand_icon = true
	_next_obj_lbl.add_theme_constant_override("icon_max_width", 17)
	_next_obj_lbl.add_theme_color_override("font_color", accent)
	_next_obj_lbl.tooltip_text = str(_objective_cache.get("text", ""))
	var accent_key := accent.to_html()
	if str(_ribbon_fill.get_meta("objective_accent", "")) != accent_key:
		_ribbon_fill.set_meta("objective_accent", accent_key)
		_ribbon_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(accent))

func _objective_progress() -> float:
	if _objective_cache.is_empty(): return 0.0
	if bool(_objective_cache.get("progress_override", false)):
		return clampf(float(_objective_cache.get("progress", 0.0)), 0.0, 1.0)
	var cost := float(_objective_cache.get("cost", -1.0))
	if cost > 0.0:
		return clampf(GameState.credits / cost, 0.0, 1.0)
	return clampf(float(_objective_cache.get("progress", 0.0)), 0.0, 1.0)

func _jump_to_objective() -> void:
	if _objective_cache.is_empty(): return
	Fx.press(_next_obj_lbl); Audio.play("tap")
	if _objective_cache.has("city_index"):
		var city_index := int(_objective_cache["city_index"])
		_map.focus_city(city_index)
		_show_city_inspector(city_index)
		return
	var tab := clampi(int(_objective_cache.get("tab", 0)), 0, _pages.size() - 1)
	_switch_tab(tab)
	var focus: Control = _objective_cache.get("focus", null)
	if is_instance_valid(focus):
		_show_control_page(_pages[tab] as ScrollContainer, focus)
		Fx.shimmer(focus, _objective_cache.get("accent", UITheme.ACCENT))
		Fx.ring_pulse(focus, focus.size * 0.5, _objective_cache.get("accent", UITheme.ACCENT), 1.4)
	_toast(str(_objective_cache.get("text", "")), _objective_cache.get("accent", UITheme.ACCENT),
		str(_objective_cache.get("icon", "ic_range")))

## Finds the discrete management page containing a nested button/card. This
## keeps smart-goal jumps correct even when page composition changes later.
func _show_control_page(sc: ScrollContainer, target: Control) -> void:
	if not _page_groups.has(sc): return
	var items := _available_page_items(sc)
	for i in range(items.size()):
		var item := items[i] as Node
		if item == target or item.is_ancestor_of(target):
			_show_management_page(sc, floori(float(i) / float(MANAGEMENT_PAGE_SIZE)))
			return

func _sync_upgrade_unlocks() -> void:
	_upgrade_unlock_rank = GameState.prosperity_rank
	for unlock_key: String in _rows:
		(_rows[unlock_key]["card"] as Control).set_meta("progression_hidden",
			not GameState.is_upgrade_unlocked(unlock_key))
	_show_management_page(_pages[0] as ScrollContainer, int(_page_indices.get(_pages[0], 0)))

func _reveal_prosperity_unlocks(rank: int) -> void:
	_sync_upgrade_unlocks()
	var unlocked := GameState.upgrade_keys_unlocked_at(rank)
	if unlocked.is_empty(): return
	# Rank 2 ends the capital tutorial. The advisor's next action now belongs to
	# the first satellite settlement, so highlighting the newly unlocked route card
	# sent camera, map and objective in three different directions. Hand the player
	# back to the world instead; routes and automation remain earned in management.
	if rank == 2 and GameState.cities_unlocked > 0:
		_refresh_smart_objective()
		_switch_tab(0)
		_map.guide_city(GameState.cities_unlocked)
		return
	if _active_tab == 0:
		var reveal_card := _rows[unlocked[0]]["card"] as Control
		_show_control_page(_pages[0] as ScrollContainer, reveal_card)
		Fx.shimmer(reveal_card, UITheme.GOLD)
		Fx.ring_pulse(reveal_card, reveal_card.size * 0.5, UITheme.GOLD, 1.7)

## The city is the primary game surface: tapping its highlighted construction
## site opens the exact decision card. Spending remains a second deliberate tap.
func _open_investment_from_map(key: String) -> void:
	if not _rows.has(key) or not GameState.is_upgrade_unlocked(key):
		return
	_switch_tab(0)
	var card := _rows[key]["card"] as Control
	_show_control_page(_pages[0] as ScrollContainer, card)
	Fx.shimmer(card, UITheme.GOLD)
	Fx.ring_pulse(card, card.size * 0.5, UITheme.GOLD, 1.5)

func _update_nav_dots() -> void:
	if _nav_dots.size() < 6: return
	# Fleet
	var fleet := GameState.credits >= GameState.drone_cost_multi(1) or Prestige.can_prestige()
	for key: String in _rows:
		if GameState.is_upgrade_unlocked(key) and not (_rows[key]["btn"] as Button).disabled: fleet = true
	_nav_dots[0].visible = fleet
	# Cities
	_nav_dots[1].visible = GameState.can_unlock_city() or GameState.can_expand()
	# Talents
	var tal := false
	for key: String in _talent_rows:
		if not (_talent_rows[key]["btn"] as Button).disabled: tal = true
	_nav_dots[2].visible = tal
	# Legado: affordable prestige shop
	var leg := false
	for id: String in Prestige.SHOP_ORDER:
		if not Prestige.has_shop(id) and Prestige.pgems >= int(Prestige.SHOP[id]["cost"]): leg = true
	_nav_dots[3].visible = leg
	# Shop: daily pending or gem boost affordable
	_nav_dots[4].visible = Daily.pending or GameState.gems >= GameState.gem_boost_cost()
	# Missões: any contract is ready to claim
	var mis := false
	for i in range(Contracts.SLOT_COUNT):
		if i < Contracts.slots.size() and Contracts.slots[i].get("ready", false) and not Contracts.slots[i].get("claimed", false):
			mis = true; break
	_nav_dots[5].visible = mis

func _effect(key: String) -> String:
	# tr() at return so these embedded (%s) effect strings follow the active
	# locale instead of staying Portuguese inside a translated template.
	match key:
		"speed":  return tr("+3%/nv velocidade")
		"cargo":  return tr("+0.25/nv carga")
		"value":  return tr("+4%/nv valor")
		"routes": return tr("+2.5%/nv eficiência de rota")
	return ""

## Cumulative total bonus at the given level (vs. the flat per-level rate in
## _effect) — much more useful once a few levels are owned.
func _effect_total(key: String, lvl: int) -> String:
	match key:
		"speed":  return tr("+%.0f%% total") % (3.0 * float(lvl))
		"cargo":  return tr("+%.0f%% total") % (25.0 * float(lvl))
		"value":  return tr("+%.0f%% total") % ((pow(1.04, float(lvl)) - 1.0) * 100.0)
		"routes": return tr("+%.0f%% total") % (2.5 * float(lvl))
	return ""

func _talent_effect_total(key: String, lvl: int) -> String:
	match key:
		"global": return tr("+%.0f%% lucros") % (6.0 * float(lvl))
		"speed":  return tr("+%.0f%% velocidade") % (4.0 * float(lvl))
		"value":  return tr("+%.0f%% valor") % (4.0 * float(lvl))
		"hangar": return tr("-%.0f%% custo drones") % (2.0 * float(lvl))
	return ""

# ── Signal handlers ──────────────────────────────────────────────────────────────

func _on_city_unlocked(i: int) -> void:
	_refresh_progressive_nav()
	var cities := Economy.country_cities(GameState.current_country)
	var city_index := clampi(i, 0, cities.size() - 1)
	var city_name := str(cities[city_index].get("name", tr("Cidade")))
	_toast(tr("%s desbloqueada · Renda +%s/s") % [city_name, Fmt.short(GameState.last_city_income_gain)],
		UITheme.CYAN, "ic_city")
	var c := Vector2(size.x * 0.5, size.y * 0.42)
	Fx.confetti(self, c, 22)
	Fx.ring_pulse(self, c, UITheme.CYAN, 2.2)
	Fx.screen_flash(self, UITheme.CYAN, 0.10)
	_map.focus_city(i)
	_sync_city_expansion_visibility(true)
	_rebuild_city_list()
	# The first settlement teaches missions. Talents wait for the first realm
	# completion, when influence is actually awarded and the page has a real
	# decision instead of four disabled cards.
	if GameState.current_country == 0 and i == 2:
		_toast(tr("%s desbloqueada!") % tr("Missões"), UITheme.CYAN, "ic_achieve")

func _on_city_developed(index: int, level: int, income_gain: float) -> void:
	var cities := Economy.country_cities(GameState.current_country)
	if index <= 0 or index >= cities.size():
		return
	var city_name := str(cities[index].get("name", tr("Cidade")))
	_toast(tr("%s desenvolvida · Nível %d · Renda +%s/s") % [
		city_name, level, Fmt.short(income_gain)], UITheme.CYAN, "ic_range")
	var centre := Vector2(size.x * 0.62, size.y * 0.44)
	Fx.confetti(self, centre, 16 + level * 4, [UITheme.CYAN, UITheme.GOLD, UITheme.GREEN])
	Fx.ring_pulse(self, centre, UITheme.CYAN, 1.8 + float(level) * 0.15)
	Fx.screen_flash(self, UITheme.CYAN, 0.06)
	Fx.vibrate(22 + level * 6)
	if GameState.cities_unlocked == 1 and index == 1 and level == 1 and not GameState.all_cities_unlocked():
		_refresh_smart_objective()
		_map.guide_city(2)
	else:
		_map.focus_city(index)
	_rebuild_city_list()

func _on_prosperity_advanced(rank: int, cash_reward: float, gem_reward: int) -> void:
	var reward_text := "+" + Fmt.short(cash_reward)
	if gem_reward > 0:
		reward_text += "  ·  +%d " % gem_reward + tr("Gemas")
	var unlock_text := _prosperity_unlock_summary(rank)
	var milestone_text := tr("Nível da cidade %d alcançado!") % rank + "  " + reward_text
	if not unlock_text.is_empty():
		milestone_text += "  ·  " + tr("Novo: %s") % unlock_text
	_toast(milestone_text, UITheme.GOLD, "ic_city")
	var centre := Vector2(size.x * 0.62, size.y * 0.45)
	Fx.confetti(self, centre, 20 + rank * 5, [UITheme.GOLD, UITheme.CYAN, UITheme.GREEN])
	Fx.ring_pulse(self, centre, UITheme.GOLD, 1.8 + float(rank) * 0.2)
	Fx.screen_flash(self, UITheme.GOLD, 0.08 + float(rank) * 0.02)
	call_deferred("_reveal_prosperity_unlocks", rank)
	Audio.play("milestone")
	Fx.vibrate(28 + rank * 8)
	if rank != 2:
		_map.focus_city(0)

func _prosperity_unlock_summary(rank: int) -> String:
	var names: Array[String] = []
	for key: String in GameState.upgrade_keys_unlocked_at(rank):
		names.append(tr(str(Economy.UPGRADES[key]["name"])))
	if rank == 2:
		names.append(tr("Gestor de Frota Automático"))
	return " + ".join(names)

func _on_country_changed(i: int) -> void:
	_refresh_progressive_nav()
	_rebuild_city_list()
	var c := Vector2(size.x * 0.5, size.y * 0.40)
	if i >= Economy.num_countries() - 1:
		_toast(tr("🏆 MISSÃO COMPLETA! Conquistaste o mundo!"), UITheme.GOLD, "ic_city")
		_banana_rain()
		Fx.confetti(self, c, 80, [UITheme.GOLD, UITheme.CYAN, UITheme.GREEN, UITheme.PINK, Color(1,0.9,0.1)])
		Fx.screen_flash(self, UITheme.GOLD, 0.30)
		Fx.screen_shake(_map, 14.0)
		for _r in range(4):
			Fx.ring_pulse(self, c, UITheme.GOLD, 3.2)
			Fx.ring_pulse(self, c, UITheme.CYAN, 2.6)
		Audio.play("prestige")
		Fx.vibrate(120)   # biggest milestone in the game — longest buzz
	else:
		_toast(tr("Bem-vindo a %s!") % Economy.country_name(i), UITheme.GOLD, "ic_city")
		Fx.confetti(self, c, 48, [UITheme.GOLD, UITheme.CYAN, UITheme.GREEN, UITheme.PINK])
		Fx.screen_flash(self, UITheme.GOLD, 0.18)
		Fx.screen_shake(_map, 9.0)
		Fx.ring_pulse(self, c, UITheme.GOLD, 2.8)
		Fx.ring_pulse(self, c, UITheme.CYAN, 2.2)
		Audio.play("milestone")
		Fx.vibrate(60)   # country expansion — stronger than a regular tap

## A world region was fully conquered — award celebration for its permanent bonus.
## Scales with the region's weight; the last region (Americas) is the grand finale.
func _on_region_completed(r: int) -> void:
	var reg: Dictionary = Economy.REGIONS[r]
	var pct := int(round(float(reg["bonus"]) * 100.0))
	var name: String = tr(str(reg["name_key"]))
	var c := Vector2(size.x * 0.5, size.y * 0.40)
	var final := r >= Economy.REGIONS.size() - 1
	_toast(tr("🌍 Região dominada: %s  ·  +%d%% lucros permanente") % [name, pct], UITheme.GREEN, "ic_city")
	Fx.confetti(self, c, 64 if final else 40, [UITheme.GREEN, UITheme.GOLD, UITheme.CYAN, UITheme.PINK])
	Fx.screen_flash(self, UITheme.GREEN, 0.22 if final else 0.14)
	if not Fx.reduce_motion:
		Fx.ring_pulse(self, c, UITheme.GREEN, 3.0 if final else 2.4)
		Fx.ring_pulse(self, c, UITheme.GOLD, 2.4)
	Audio.play("prestige" if final else "milestone")
	Fx.vibrate(100 if final else 55)

	_toast(tr("☁ Progresso restaurado da nuvem"), UITheme.CYAN, "ic_prestige")

func _banana_rain() -> void:
	var rng := RandomNumberGenerator.new(); rng.randomize()
	for i in range(50):
		var ban := Label.new()
		ban.text = "🍌"
		var sz := int(rng.randf_range(28.0, 72.0))
		ban.add_theme_font_size_override("font_size", sz)
		ban.position = Vector2(rng.randf() * size.x, -90.0)
		ban.rotation = rng.randf_range(-0.6, 0.6)
		add_child(ban)
		var dur := rng.randf_range(1.4, 3.2)
		var delay := rng.randf_range(0.0, 2.5)
		var tw := ban.create_tween()
		tw.tween_interval(delay)
		tw.set_parallel(true)
		tw.tween_property(ban, "position:y", size.y + 120.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(ban, "rotation", ban.rotation + rng.randf_range(-1.2, 1.2), dur)
		tw.chain().tween_callback(ban.queue_free)

func _on_achievement(id: String) -> void:
	var def: Dictionary = Achievements.DEFS.get(id, {})
	_toast(tr("%s desbloqueada!") % tr(str(def.get("name", id))), UITheme.GOLD, "ic_achieve")
	Fx.screen_flash(self, UITheme.GOLD, 0.08)
	# An achievement is a designed reward but landed weaker than a routine city
	# unlock (which gets a ring). Add a gold ring + sting — deliberately no
	# confetti, since achievements can fire in quick succession and would spam.
	Audio.play("milestone")
	if not Fx.reduce_motion:   # ring_pulse has no internal reduce gate
		Fx.ring_pulse(self, Vector2(size.x * 0.5, size.y * 0.30), UITheme.GOLD, 2.2)
	if _achieve_count_lbl != null and is_instance_valid(_achieve_count_lbl):
		_achieve_count_lbl.text = tr("Desbloqueadas: %d / %d") % [Achievements.done_count(), Achievements.total_count()]
	if _achieve_cells.has(id):
		_achieve_cells[id].add_theme_stylebox_override("panel", UITheme.achievement_card(true))
	if _achieve_prog_fills.has(id):
		(_achieve_prog_fills[id] as Panel).anchor_right = 1.0

func _on_event_start(id: String) -> void:
	var def: Dictionary = Events.DEFS.get(id, {})
	_event_name_lbl.text = str(def.get("name", "")) + " · " + str(def.get("desc", ""))
	_event_name_lbl.add_theme_color_override("font_color", Events.color())
	_event_icon.modulate = Events.color()
	# stylebox cached once per event (was allocated every frame in _process)
	_event_timer_bar.add_theme_stylebox_override("panel", UITheme.prog_fill(Events.color()))
	_event_row.visible = true
	_toast(str(def.get("name", "Evento")), Events.color(), "ic_event")
	_show_event_banner(def)

func _show_event_banner(def: Dictionary) -> void:
	var ev_col := Events.color()
	Fx.screen_flash(self, ev_col, 0.16, 0.12)
	if Fx.reduce_motion: return
	var bw := size.x * 0.86
	var banner := PanelContainer.new()
	banner.z_index = 90
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", UITheme.solid(
		Color(0.06, 0.09, 0.17, 0.94).lerp(ev_col, 0.18), 24))
	banner.size = Vector2(bw, 160)
	banner.position = Vector2((size.x - bw) * 0.5, -170)
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 5)
	banner.add_child(bv)
	var em := Label.new(); em.text = str(def.get("icon", "⚡"))
	em.add_theme_font_size_override("font_size", 44)
	em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(em)
	var nm := Label.new(); nm.text = str(def.get("name", "Evento"))
	nm.add_theme_font_size_override("font_size", 26)
	nm.add_theme_color_override("font_color", ev_col.lightened(0.25))
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bv.add_child(nm)
	var dc := Label.new(); dc.text = str(def.get("desc", ""))
	dc.add_theme_font_size_override("font_size", 17)
	dc.add_theme_color_override("font_color", Color(0.82, 0.86, 0.95))
	dc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; bv.add_child(dc)
	add_child(banner)
	var tw := banner.create_tween()
	tw.tween_property(banner, "position:y", 210.0, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(banner.queue_free)

func _on_prestige(_count: int) -> void:
	_disp_credits = 0.0
	_prev_gems = GameState.gems; _prev_infl = GameState.influence
	_toast(tr("PRESTIGE! Bem-vindo ao recomeço!"), UITheme.PRESTIGE, "ic_prestige")

# ── FX helpers ───────────────────────────────────────────────────────────────────

func _reward_fx(node: Control, color: Color, kind := "spark", n := 6) -> void:
	if not is_instance_valid(node): return
	var c := node.get_global_rect().get_center()
	Fx.burst(self, c, color, n, kind)

## Transient purchase feedback: the player immediately sees the exact permanent
## income gained without adding another persistent HUD widget. Reduced-motion
## mode keeps the confirmation stationary and only fades it out.
func _show_income_gain(before_income: float, source: Control) -> void:
	var gain := GameState.income_per_sec() - before_income
	if gain <= 0.0001 or not is_instance_valid(source):
		return
	Fx.chip_pop(_income_lbl, UITheme.GREEN)
	var gain_label := Label.new()
	gain_label.text = tr("Renda +%s/s") % Fmt.short(gain)
	gain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gain_label.add_theme_font_override("font", UITheme.font("Bold"))
	gain_label.add_theme_font_size_override("font_size", 19)
	gain_label.add_theme_color_override("font_color", UITheme.GREEN)
	gain_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.03, 0.88))
	gain_label.add_theme_constant_override("shadow_offset_x", 2)
	gain_label.add_theme_constant_override("shadow_offset_y", 2)
	gain_label.custom_minimum_size = Vector2(180, 30)
	gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(gain_label)
	var centre := source.get_global_rect().get_center() - get_global_rect().position
	gain_label.position = Vector2(clampf(centre.x - 90.0, 8.0, size.x - 188.0), centre.y - 42.0)
	var tw := gain_label.create_tween()
	if Fx.reduce_motion:
		tw.tween_interval(0.65)
	else:
		tw.tween_property(gain_label, "position:y", gain_label.position.y - 28.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(gain_label, "modulate:a", 0.0, 0.25)
	tw.tween_callback(gain_label.queue_free)

func _on_auto_bought(_kind: String) -> void:
	# Automation runs frequently, so acknowledge it with one quiet HUD pulse
	# rather than producing a stream of labels or toasts.
	Fx.chip_pop(_income_lbl, UITheme.GREEN)

# ── Popups ───────────────────────────────────────────────────────────────────────

## Compact [icon_name, short_text] for a daily reward cell (avoids text wrap).
func _daily_compact(r: Dictionary) -> Array:
	if r.has("hours"):     return ["ic_cash", "%dh" % int(r["hours"])]
	if r.has("boost"):     return ["ic_boost", "2×"]
	# checked BEFORE the pgems-only branch below: the day-7 reward has both
	# gems AND pgems (150 regular gems + 1 prestige gem) — the old order
	# matched "has pgems" first and showed the prestige-gem icon next to
	# "+150", implying 150 prestige gems instead of 150 regular gems.
	if r.has("gems") and r.has("pgems"): return ["ic_gems", "+%d" % int(r["gems"])]
	if r.has("pgems"):     return ["ic_prestige", "+%d" % int(r["pgems"])]
	if r.has("influence") and not r.has("gems"): return ["ic_prestige", "+%d🌐" % int(r["influence"])]
	if r.has("gems"):      return ["ic_gems", "+%d" % int(r["gems"])]
	return ["ic_gems", "?"]

func _show_daily_popup() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.GOLD)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_daily", 30)); hd.add_child(_lbl("Recompensa Diária", 30, UITheme.GOLD)); box.add_child(hd)
	var streak_info := _lbl(tr("Streak: %d dias consecutivos!") % Daily.streak, 19, UITheme.INK)
	streak_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(streak_info)
	var bonus_pct := int(round((Daily._streak_scale() - 1.0) * 100.0))
	if bonus_pct > 0:
		var sb := _lbl(tr("Bónus de sequência: +%d%%") % bonus_pct, 15, UITheme.GREEN)
		sb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(sb)

	var grid := GridContainer.new(); grid.columns = 7
	grid.add_theme_constant_override("h_separation", 5); grid.add_theme_constant_override("v_separation", 5); box.add_child(grid)
	var cur_idx := (Daily.streak - 1) % Daily.REWARDS.size()
	for i in Daily.REWARDS.size():
		var day_box := PanelContainer.new()
		day_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var claimed := (i < cur_idx)
		var current := (i == cur_idx) and Daily.pending
		day_box.add_theme_stylebox_override("panel", UITheme.daily_card(claimed, current))
		var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 3); day_box.add_child(dv)
		var dl := _lbl("D%d" % (i+1), 14, UITheme.MUTED if not current else UITheme.GOLD)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dv.add_child(dl)
		var cd := _daily_compact(Daily.REWARDS[i])
		var ic := _icon(cd[0], 20); ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; dv.add_child(ic)
		var rl := _lbl(cd[1], 14, UITheme.INK if not claimed else UITheme.GREEN)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dv.add_child(rl)
		if claimed:
			var ck := _icon("ic_check", 15); ck.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; dv.add_child(ck)
		if current:
			Fx.breathe(day_box, true)
		grid.add_child(day_box)

	if Daily.pending:
		if Daily.pending_restore:
			# One free recovery keeps the daily system friendly in the test build.
			var rs := Button.new(); rs.text = tr("Restaurar sequência (anúncio)")
			rs.icon = _opt_tex("ic_daily"); rs.expand_icon = true; rs.add_theme_constant_override("icon_max_width", 24)
			rs.add_theme_font_size_override("font_size", 18); rs.custom_minimum_size = Vector2(0, 62)
			rs.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GREEN.darkened(0.05)))
			rs.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			rs.pressed.connect(func():
				layer.queue_free()
				Daily.restore_streak()
				_toast(tr("Sequência restaurada!"), UITheme.GREEN, "ic_daily")
				_show_daily_popup()
			)
			box.add_child(rs)
			Fx.shimmer(rs, UITheme.GREEN, true)
		var claim_btn := _wide_btn(UITheme.GOLD.darkened(0.06))
		claim_btn.text = tr("Recolher")
		claim_btn.add_theme_color_override("font_color", Color(0.12, 0.08, 0.0))
		claim_btn.pressed.connect(func():
			Fx.press(claim_btn)
			var from := claim_btn.get_global_rect().get_center()
			Daily.claim(); _disp_credits = GameState.credits
			Fx.coin_fountain(self, from, _credits_chip.get_global_rect().get_center(), 10)
			Fx.chip_pop(_gems_chip, UITheme.CYAN)
			layer.queue_free()
		)
		box.add_child(claim_btn)
	var close := _close_btn(layer); box.add_child(close)

## Reward choice after tapping the rare golden griffin.
func _show_bonus_popup(reward: Dictionary) -> void:
	Audio.play("unlock", 1.0, -3.0)   # matches the volume city-unlock already uses for this sample
	if has_node("/root/Achievements"): Achievements.note_golden()
	var layer := _overlay(); var box := _popup_box(layer, UITheme.GOLD)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_drone", 30)); hd.add_child(_lbl(tr("Drone Bónus!"), 30, UITheme.GOLD)); box.add_child(hd)
	var kind: String = str(reward.get("kind", "cash"))
	var info := _lbl(tr(str(reward.get("label", "+3 minutos de lucros!"))), 25,
		UITheme.VIOLET if kind == "jackpot" else UITheme.GOLD)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)

	var rare_btn := _wide_btn(UITheme.GREEN)
	rare_btn.text = tr("Recolher")
	rare_btn.icon = _opt_tex("ic_gems"); rare_btn.expand_icon = true
	rare_btn.add_theme_constant_override("icon_max_width", 24)
	rare_btn.custom_minimum_size = Vector2(0, 70)
	rare_btn.pressed.connect(func():
		layer.queue_free()
		match kind:
			"jackpot":
				GameState.grant_gems(30); GameState.grant_cash_minutes(5.0)
				_disp_credits = GameState.credits
				Fx.chip_pop(_credits_chip, UITheme.GOLD); Fx.chip_pop(_gems_chip, UITheme.CYAN)
				Fx.confetti(self, Vector2(size.x * 0.5, size.y * 0.4), 40, [UITheme.VIOLET, UITheme.GOLD, UITheme.CYAN])
				_toast(tr("JACKPOT! +30 Gemas e 5 min de lucros!"), UITheme.VIOLET, "ic_gems")
			"boost":
				GameState.earn_boost_timer = 180.0
				_toast(tr("Lucros ×2 durante 3 minutos!"), UITheme.GREEN, "ic_boost")
			"gems":
				GameState.grant_gems(8); _toast(tr("+8 Gemas!"), UITheme.CYAN, "ic_gems")
			_:
				GameState.grant_cash_minutes(3.0); _disp_credits = GameState.credits
				Fx.chip_pop(_credits_chip, UITheme.GOLD)
				_toast(tr("+3 minutos de lucros!"), UITheme.GREEN, "ic_cash")
	)
	box.add_child(rare_btn)
	Fx.shimmer(rare_btn, UITheme.GREEN, true)

func _show_prestige_confirm() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.PRESTIGE)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_prestige", 28)); hd.add_child(_lbl("Confirmar Prestige", 28, UITheme.PRESTIGE)); box.add_child(hd)
	var gain := Prestige.pgems_on_next_prestige()
	var info := _lbl(tr("Vais ganhar  %d  Gemas Prestige\ne um multiplicador ×%.2f permanente.\n\nPerdes créditos, drones e upgrades.\nMantens gemas normais e conquistas.") % [gain, Prestige.effective_mult() * 1.15], 18, UITheme.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)
	var confirm := Button.new(); confirm.text = "SIM, FAZER PRESTIGE"
	confirm.add_theme_font_size_override("font_size", 22); confirm.custom_minimum_size = Vector2(0, 68)
	confirm.add_theme_stylebox_override("normal", UITheme.prestige_btn_ready())
	confirm.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	confirm.pressed.connect(func():
		layer.queue_free()
		Fx.prestige_ceremony(self, func(): Prestige.do_prestige())
	)
	box.add_child(confirm)
	var cancel := Button.new(); cancel.text = "Cancelar"; cancel.add_theme_font_size_override("font_size", 22)
	cancel.custom_minimum_size = Vector2(0, 62); cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cancel.pressed.connect(func(): layer.queue_free()); box.add_child(cancel)

func _show_expansion_confirm() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.GOLD)
	var next_realm := Economy.country_name(GameState.current_country + 1)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_city", 28)); hd.add_child(_lbl(tr("Novo reino: %s") % next_realm, 28, UITheme.GOLD)); box.add_child(hd)
	var info := _lbl(tr("Recomeças a cidade local com a frota base.\nManténs Influência, Talentos, Gemas e Vermächtnis.\n\nRecompensa: +%d Influência") % GameState.expansion_influence_reward(), 18, UITheme.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(info)
	var reward := PanelContainer.new()
	reward.set_meta("expansion_reward_card", true)
	reward.add_theme_stylebox_override("panel", UITheme.solid(UITheme.PANEL2.lerp(UITheme.GOLD, 0.10), 16))
	var reward_box := VBoxContainer.new(); reward_box.add_theme_constant_override("separation", 4)
	reward.add_child(reward_box)
	var influence_gain := GameState.expansion_influence_reward()
	var reward_value := _lbl("+%d  " % influence_gain + tr("Influência"), 29, UITheme.GOLD)
	reward_value.add_theme_font_override("font", UITheme.font("Bold"))
	reward_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; reward_box.add_child(reward_value)
	var before_reputation := GameState.influence_reputation_mult()
	var after_reputation := GameState.influence_reputation_mult(GameState.influence_total + influence_gain)
	var power := _lbl(tr("Reputação permanente ×%.2f → ×%.2f") % [before_reputation, after_reputation], 17, UITheme.GREEN)
	power.set_meta("expansion_power_label", true)
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; reward_box.add_child(power)
	if GameState.current_country == 0:
		var unlock := _lbl(tr("%s desbloqueada!") % tr("Talentos"), 16, UITheme.CYAN)
		unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; reward_box.add_child(unlock)
	box.add_child(reward)
	var confirm := Button.new(); confirm.text = tr("SIM, ABRIR REINO")
	confirm.add_theme_font_size_override("font_size", 22); confirm.custom_minimum_size = Vector2(0, 68)
	confirm.add_theme_stylebox_override("normal", UITheme.solid(UITheme.GOLD.darkened(0.10), 14))
	confirm.add_theme_stylebox_override("hover", UITheme.solid(UITheme.GOLD, 14))
	confirm.add_theme_stylebox_override("pressed", UITheme.solid(UITheme.GOLD.darkened(0.22), 14))
	confirm.add_theme_color_override("font_color", UITheme.BG0)
	confirm.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	confirm.pressed.connect(func():
		layer.queue_free()
		if GameState.expand_country():
			Audio.play("milestone")
			Fx.vibrate(52)
	)
	box.add_child(confirm)
	var cancel := Button.new(); cancel.text = tr("Cancelar"); cancel.add_theme_font_size_override("font_size", 22)
	cancel.custom_minimum_size = Vector2(0, 62); cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cancel.pressed.connect(func(): layer.queue_free()); box.add_child(cancel)

## Big, unmistakable settings toggle: the whole row is tappable and shows a
## large track+knob switch (green ON / grey OFF) that slides on change. Replaces
## the tiny default CheckButton switch the user disliked. Signature unchanged:
## (label, initial state, callback(on)).
func _settings_toggle(text: String, pressed: bool, cb: Callable) -> Control:
	var row := Button.new()
	row.toggle_mode = true
	row.button_pressed = pressed
	row.custom_minimum_size = Vector2(0, 92)
	var rowsb := UITheme.solid(UITheme.PANEL)   # R_BTN(14) — matches every other button/row of this weight
	row.add_theme_stylebox_override("normal",  rowsb)
	row.add_theme_stylebox_override("hover",   rowsb)
	row.add_theme_stylebox_override("pressed", rowsb)
	row.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 20; h.offset_right = -20
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)

	var lbl := _lbl(text, 20, UITheme.INK)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.max_lines_visible = 2
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(lbl)

	var pill := Panel.new()
	pill.custom_minimum_size = Vector2(104, 56)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pill)
	var knob := Panel.new()
	knob.size = Vector2(46, 46)
	knob.position = Vector2(52, 5) if pressed else Vector2(5, 5)
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kb := StyleBoxFlat.new(); kb.bg_color = Color.WHITE; kb.set_corner_radius_all(23)
	knob.add_theme_stylebox_override("panel", kb)
	pill.add_child(knob)

	var paint_track := func(on: bool) -> void:
		var track := StyleBoxFlat.new()
		track.bg_color = UITheme.GREEN if on else UITheme.PANEL2
		track.set_corner_radius_all(28)
		pill.add_theme_stylebox_override("panel", track)
	paint_track.call(pressed)

	row.toggled.connect(func(on: bool) -> void:
		paint_track.call(on)
		if Fx.reduce_motion:
			knob.position.x = 52.0 if on else 5.0
		else:
			var tw := knob.create_tween()
			tw.tween_property(knob, "position:x", 52.0 if on else 5.0, 0.16) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Fx.press(row)
		Audio.play("tap")
		cb.call(on)
	)
	return row

## Switch language WITHOUT reloading the scene. reload_current_scene() from a UI
## callback crashes natively on Android (render thread, mid-frame free). Godot
## live-retranslates every Control whose text is a translation key on locale
## change; the only labels that don't are the uppercased section headers, which
## _notification(NOTIFICATION_TRANSLATION_CHANGED) re-applies below.
func _set_language(l: String) -> void:
	if Fx.locale == l:
		return
	Fx.set_locale(l)
	SaveSystem.save_game()

## Keep every persistent control clear of camera cut-outs, rounded display
## corners and the Android gesture area. DisplayServer reports safe bounds in
## physical screen pixels, so convert them into this project's logical canvas
## before moving the anchored HUD/page stack. Desktop remains pixel-identical.
func _apply_safe_area() -> void:
	if not is_inside_tree():
		return
	var top_inset := 0.0
	var bottom_inset := 0.0
	if OS.has_feature("mobile"):
		var screen := DisplayServer.screen_get_size()
		var safe := DisplayServer.get_display_safe_area()
		var logical := get_viewport().get_visible_rect().size
		if screen.y > 0 and logical.y > 0.0:
			var scale_y := logical.y / float(screen.y)
			top_inset = float(maxi(0, safe.position.y)) * scale_y
			var bottom_px := maxi(0, screen.y - (safe.position.y + safe.size.y))
			bottom_inset = float(bottom_px) * scale_y
	_safe_top = clampf(top_inset, 0.0, 96.0)
	_safe_bottom = clampf(bottom_inset, 0.0, 96.0)

	if is_instance_valid(_hud):
		_hud.offset_top = 20.0 + _safe_top
	var nav_bottom := NAV_H + _safe_bottom
	var panel_top := LANDSCAPE_PANEL_TOP + _safe_top
	# Imported font metrics differ slightly between desktop and mobile/Linux.
	# Follow the measured HUD rather than assuming its nominal height, preserving
	# the compact 170px boundary wherever it fits and preventing overlap where a
	# locale or platform shapes the same row a few pixels taller.
	if is_instance_valid(_hud):
		panel_top = maxf(panel_top, _hud.position.y + _hud.size.y + 8.0)
	if is_instance_valid(_bottom_bg):
		_bottom_bg.anchor_left = 0.0; _bottom_bg.anchor_right = 0.0
		_bottom_bg.anchor_top = 0.0; _bottom_bg.anchor_bottom = 1.0
		_bottom_bg.offset_left = GUTTER
		_bottom_bg.offset_right = SIDE_PANEL_W
		_bottom_bg.offset_top = panel_top
		_bottom_bg.offset_bottom = -nav_bottom
	if is_instance_valid(_map_floor_anchor):
		_map_floor_anchor.offset_top = -nav_bottom
		_map_floor_anchor.offset_bottom = -nav_bottom
	for page in _pages:
		if is_instance_valid(page):
			page.anchor_left = 0.0; page.anchor_right = 0.0
			page.anchor_top = 0.0; page.anchor_bottom = 1.0
			page.offset_left = GUTTER + 6.0
			page.offset_right = SIDE_PANEL_W - 6.0
			page.offset_top = panel_top
			page.offset_bottom = -nav_bottom
	if is_instance_valid(_nav_sep):
		_nav_sep.offset_top = -nav_bottom - 1.0
		_nav_sep.offset_bottom = -nav_bottom
	if is_instance_valid(_nav_bar):
		_nav_bar.offset_top = -nav_bottom
		_nav_bar.offset_bottom = -_safe_bottom
	if is_instance_valid(_nav_ind):
		_nav_ind.offset_top = -nav_bottom - 2.0
		_nav_ind.offset_bottom = -nav_bottom + 4.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for nav_label: Label in _nav_labels:
			if is_instance_valid(nav_label):
				nav_label.text = tr(str(nav_label.get_meta("i18n", "")))
		for l: Label in _section_lbls:
			if is_instance_valid(l):
				l.text = tr(str(l.get_meta("i18n", ""))).to_upper()
		# Settings stats blurb otherwise only refreshes every 30 frames in
		# _process — up to half a second of stale-language text right after
		# tapping PT/EN, which is exactly the "still mixed" symptom reported.
		if _settings_stats_lbl != null and is_instance_valid(_settings_stats_lbl):
			_settings_stats_lbl.text = _settings_stats_text()
		# mission titles are similarly gated behind a progress/ready/claimed
		# change-detection cache (see _update_contracts) that a locale switch
		# alone doesn't trip — force the next _update_contracts() tick to do
		# a full rebuild so titles actually re-translate instead of staying
		# in whichever language was active when the contract was rolled
		for i in range(_mission_last_progress.size()):
			_mission_last_progress[i] = -1.0
		# _prestige_info_lbl is similarly gated behind a "ready" state-change
		# check in _process() — once readiness stops changing, a locale switch
		# alone never retriggers the tr()+%-format rebuild, leaving it stuck in
		# whichever language was active the last time readiness flipped.
		if _prestige_info_lbl != null and is_instance_valid(_prestige_info_lbl):
			_prestige_info_lbl.text = ""
		# Upgrade + talent detail strings are gated behind the _sig / _lvl
		# dirty-checks in _process (a perf optimization): they only rebuild when
		# level/cost move, so a locale switch alone left them stuck in the previous
		# language until the player next levelled that row. Invalidate both so the
		# next _process tick re-renders every detail in the new language.
		for key: String in _rows:
			_rows[key]["_sig"] = null
		for key: String in _talent_rows:
			_talent_rows[key]["_lvl"] = -1
	elif what == NOTIFICATION_RESIZED:
		# Multi-window, foldables and orientation/configuration changes can alter
		# the usable display rectangle while the game is already running.
		call_deferred("_apply_safe_area")
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android hardware/gesture Back: close the top popup instead of killing
		# the app; if nothing is open, ask before quitting. (Was unhandled — Back
		# instantly closed the whole game, even with a popup open.)
		var top: CanvasLayer = null
		for c in get_children():
			if c is CanvasLayer and (c as CanvasLayer).layer == 150:
				top = c
		if top != null:
			top.queue_free()
		else:
			_show_exit_confirm()

## Tap-credits panel: exact (grouped) credits + income/s, and every multiplier
## feeding income so the player can see WHY their rate is what it is.
func _show_income_breakdown() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.GOLD)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_credits", 30)); hd.add_child(_lbl(tr("Resumo de Rendimento"), 26, UITheme.INK)); box.add_child(hd)
	var cr := _lbl(tr("Créditos: %s") % Fmt.long(GameState.credits), 17, UITheme.GOLD)
	cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(cr)
	var inc := _lbl(tr("Rendimento: %s/s") % Fmt.long(GameState.income_per_sec()), 17, UITheme.GREEN)
	inc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(inc)
	box.add_child(_section("Multiplicadores", UITheme.ACCENT))
	var total := 1.0
	for row: Array in GameState.mult_breakdown():
		var val: float = float(row[1])
		if val <= 1.001:
			continue   # only show factors actually contributing
		total *= val
		var rr := HBoxContainer.new(); rr.add_theme_constant_override("separation", 6); box.add_child(rr)
		var nm := _lbl(tr(str(row[0])), 16, UITheme.MUTED); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rr.add_child(nm)
		var vl := _lbl("×%.2f" % val, 16, UITheme.INK); vl.add_theme_font_override("font", UITheme.font("Bold")); rr.add_child(vl)
	var tot := _lbl(tr("Total ×%.2f") % total, 19, UITheme.GOLD)
	tot.add_theme_font_override("font", UITheme.font("Bold"))
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(tot)
	box.add_child(_close_btn(layer))

## Compact map-first city inspector. It deliberately reuses existing translated
## vocabulary and the same city action as the management dashboard, so tapping
## the world never opens a dead-end information panel.
func _show_city_inspector(index: int) -> void:
	var cities := Economy.country_cities(GameState.current_country)
	if index < 0 or index >= cities.size():
		return
	var model := _city_inspector_model(index)
	Audio.play("tap")
	var is_capital := index == 0
	var is_active: bool = model["active"]
	var is_next: bool = model["next"]
	var accent := UITheme.GOLD if is_capital else (UITheme.CYAN if is_active else UITheme.ACCENT)
	var layer := _overlay()
	var box := _popup_box(layer, accent)
	box.add_theme_constant_override("separation", 8)

	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 12)
	head.add_child(_icon_badge("ic_city" if is_capital or is_next else "ic_range", accent, 56, 30))
	var titles := VBoxContainer.new(); titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _lbl(str(cities[index]["name"]), 28, UITheme.INK)
	title.add_theme_font_override("font", UITheme.font("Bold")); titles.add_child(title)
	titles.add_child(_lbl(Economy.country_name(GameState.current_country), 16, UITheme.MUTED))
	head.add_child(titles); box.add_child(head)

	var info := _card(accent)
	var iv := VBoxContainer.new(); iv.add_theme_constant_override("separation", 6); info.add_child(iv)
	var status := tr("SEDE") if is_capital else (tr("Obtido") if is_active else tr("Bloqueado"))
	var status_lbl := _lbl(status, 17, accent)
	status_lbl.name = "CityStatus"
	status_lbl.add_theme_font_override("font", UITheme.font("Bold")); iv.add_child(status_lbl)
	var progress_fill: Panel = null
	var progress_label: Label = null
	var next_cost_label: Label = null
	var next_detail_label: Label = null
	var development_cost_label: Label = null
	var development_detail_label: Label = null
	var can_develop := is_active and not is_capital \
		and int(model["development_level"]) < GameState.CITY_DEVELOPMENT_MAX
	if is_active:
		var realm_income: float = model["realm_income"]
		var city_income: float = model["city_income"]
		# Keep this map popup fully visible on 720p landscape. Ownership and income
		# are one status statement; the fleet count already lives in the persistent
		# HUD and only repeated information while pushing the close action offscreen.
		status_lbl.text = status + "  ·  " + tr("Rendimento: %s/s") % Fmt.short(city_income)
		if not is_capital:
			var share := 0 if realm_income <= 0.0 else int(round(city_income / realm_income * 100.0))
			iv.add_child(_lbl(tr("Contribuição para o reino: %d%%") % share, 15, UITheme.CYAN))
	elif is_next:
		var unlock_cost: float = model["next_cost"]
		var unlock_pct: float = model["progress"]
		iv.add_child(_lbl(tr("Custo: %s") % Fmt.short(unlock_cost), 20, UITheme.GOLD))
		next_detail_label = _lbl(tr("Renda +%s/s") % Fmt.short(float(model["next_gain"])), 16, UITheme.GREEN)
		next_detail_label.text += _eta_suffix(unlock_cost, float(model["realm_income"]))
		iv.add_child(next_detail_label)
		var prog_bg := Panel.new(); prog_bg.custom_minimum_size = Vector2(0, 9)
		prog_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); iv.add_child(prog_bg)
		progress_fill = Panel.new(); progress_fill.anchor_left = 0; progress_fill.anchor_right = unlock_pct
		progress_fill.name = "CityProgress"
		progress_fill.anchor_top = 0; progress_fill.anchor_bottom = 1
		progress_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(UITheme.ACCENT)); prog_bg.add_child(progress_fill)
		progress_label = _lbl(tr("Progresso: %d%%") % int(round(unlock_pct * 100.0)), 15, UITheme.MUTED)
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; iv.add_child(progress_label)
	box.add_child(info)

	if can_develop:
		var development_card := _card(UITheme.CYAN)
		development_card.name = "CityDevelopmentCard"
		var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", 6); development_card.add_child(dv)
		var development_head := HBoxContainer.new(); development_head.add_theme_constant_override("separation", 8); dv.add_child(development_head)
		development_head.add_child(_icon("ic_range", 22))
		var development_title := _lbl(tr("Desenvolver cidade"), 18, UITheme.INK)
		development_title.add_theme_font_override("font", UITheme.font("Bold")); development_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		development_head.add_child(development_title)
		development_cost_label = _lbl(Fmt.short(float(model["development_cost"])), 18, UITheme.GOLD)
		development_head.add_child(development_cost_label)
		development_detail_label = _lbl(tr("Nível de rota %d/%d · Renda +%s/s") % [
			int(model["development_level"]), GameState.CITY_DEVELOPMENT_MAX,
			Fmt.short(float(model["development_gain"]))], 15, UITheme.GREEN)
		development_detail_label.text += _eta_suffix(float(model["development_cost"]), float(model["realm_income"]))
		dv.add_child(development_detail_label)
		box.add_child(development_card)

	# One popup, one decision. A city with local development remaining focuses on
	# that investment alone; only a fully developed city may hand off to the next
	# network site. The frontier itself remains directly tappable on the map.
	if is_active and bool(model["has_next"]) and not can_develop:
		var next_card := _card(UITheme.ACCENT)
		next_card.name = "CityNextCard"
		var nv := VBoxContainer.new(); nv.add_theme_constant_override("separation", 6); next_card.add_child(nv)
		var next_head := HBoxContainer.new(); next_head.add_theme_constant_override("separation", 8); nv.add_child(next_head)
		next_head.add_child(_icon("ic_city", 22))
		var next_title := _lbl(tr("Próxima: %s") % model["next_name"], 18, UITheme.INK)
		next_title.add_theme_font_override("font", UITheme.font("Bold")); next_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_head.add_child(next_title)
		next_cost_label = _lbl(Fmt.short(float(model["next_cost"])), 18, UITheme.GOLD)
		next_head.add_child(next_cost_label)
		next_detail_label = _lbl(tr("Renda +%s/s") % Fmt.short(float(model["next_gain"])), 15, UITheme.GREEN)
		next_detail_label.text += _eta_suffix(float(model["next_cost"]), float(model["realm_income"]))
		nv.add_child(next_detail_label)
		box.add_child(next_card)

	var action := _buy_btn(accent)
	action.name = "CityAction"
	action.custom_minimum_size = Vector2(0, 72)
	if can_develop:
		var development_cost: float = model["development_cost"]
		action.text = tr("Desenvolver cidade") + "  ·  " + Fmt.short(development_cost)
		action.disabled = GameState.credits < development_cost
		action.pressed.connect(func():
			if GameState.buy_city_development(index):
				Fx.press(action); Audio.play("milestone"); _dismiss(layer)
			else:
				Fx.error_shake(action)
		)
	elif is_next or (is_active and bool(model["has_next"])):
		var cost: float = model["next_cost"]
		action.text = tr("Abrir") + "  ·  " + Fmt.short(cost)
		action.disabled = GameState.credits < cost
		action.pressed.connect(func():
			if GameState.unlock_city():
				Fx.press(action); Audio.play("unlock"); _dismiss(layer)
			else:
				Fx.error_shake(action)
		)
	elif is_active:
		action.text = tr("Cidades")
		action.pressed.connect(func():
			Fx.press(action); _dismiss(layer); _switch_tab(1)
		)
	else:
		action.text = tr("Bloqueado")
		action.disabled = true
	box.add_child(action)
	if can_develop:
		_bind_city_development_live(layer, action, index, development_cost_label, development_detail_label)
	elif is_next or (is_active and bool(model["has_next"])):
		_bind_city_unlock_live(layer, action, progress_fill, progress_label, next_cost_label,
			next_detail_label, status_lbl if is_next else null)
	box.add_child(_close_btn(layer))

func _bind_city_development_live(layer: Node, action: Button, city_index: int,
		cost_label: Label = null, detail_label: Label = null) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.one_shot = false
	layer.add_child(timer)
	var refresh := func() -> void:
		if not is_instance_valid(layer) or not is_instance_valid(action):
			return
		var cost := GameState.city_development_cost(city_index)
		var level := GameState.city_development_level(city_index)
		if cost < 0.0:
			action.text = tr("NÍVEL MÁXIMO")
			action.disabled = true
			return
		action.text = tr("Desenvolver cidade") + "  ·  " + Fmt.short(cost)
		action.disabled = GameState.credits < cost
		_afford(action, not action.disabled)
		if is_instance_valid(cost_label): cost_label.text = Fmt.short(cost)
		if is_instance_valid(detail_label):
			detail_label.text = tr("Nível de rota %d/%d · Renda +%s/s") % [
				level, GameState.CITY_DEVELOPMENT_MAX,
				Fmt.short(GameState.projected_city_development_gain(city_index))]
			detail_label.text += _eta_suffix(cost, GameState.income_per_sec())
	timer.timeout.connect(refresh)
	refresh.call()
	timer.start()

## Idle income continues while the inspector is open. Refreshing this small
## decision card four times a second makes waiting legible and, critically,
## enables the purchase the moment it becomes affordable without forcing the
## player to close and reopen the city.
func _bind_city_unlock_live(layer: Node, action: Button, progress_fill: Panel = null,
		progress_label: Label = null, cost_label: Label = null, detail_label: Label = null,
		status_label: Label = null) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.one_shot = false
	layer.add_child(timer)
	var refresh := func() -> void:
		if not is_instance_valid(layer) or not is_instance_valid(action):
			return
		var cost := GameState.next_city_cost()
		if cost < 0.0:
			action.text = tr("TODAS")
			action.disabled = true
			if is_instance_valid(progress_fill): progress_fill.anchor_right = 1.0
			if is_instance_valid(progress_label): progress_label.text = tr("Progresso: %d%%") % 100
			return
		var pct := clampf(GameState.credits / maxf(1.0, cost), 0.0, 1.0)
		var affordable := GameState.credits >= cost
		action.text = tr("Abrir") + "  ·  " + Fmt.short(cost)
		action.disabled = not affordable
		_afford(action, not action.disabled)
		if is_instance_valid(progress_fill):
			progress_fill.anchor_right = pct
			if int(progress_fill.get_meta("affordable", -1)) != int(affordable):
				progress_fill.set_meta("affordable", int(affordable))
				progress_fill.add_theme_stylebox_override("panel",
					UITheme.prog_fill(UITheme.GREEN if affordable else UITheme.ACCENT))
		if is_instance_valid(progress_label): progress_label.text = tr("Progresso: %d%%") % int(round(pct * 100.0))
		if is_instance_valid(cost_label): cost_label.text = Fmt.short(cost)
		if is_instance_valid(status_label) and int(status_label.get_meta("affordable", -1)) != int(affordable):
			var previous := int(status_label.get_meta("affordable", -1))
			status_label.set_meta("affordable", int(affordable))
			status_label.text = tr("Abrir") if affordable else tr("Bloqueado")
			status_label.add_theme_color_override("font_color", UITheme.GREEN if affordable else UITheme.ACCENT)
			if previous == 0 and affordable:
				Fx.shimmer(action, UITheme.GREEN)
				Fx.ring_pulse(action, action.size * 0.5, UITheme.GREEN, 1.5)
		if is_instance_valid(detail_label):
			detail_label.text = tr("Renda +%s/s") % Fmt.short(GameState.projected_city_income_gain())
			detail_label.text += _eta_suffix(cost, GameState.income_per_sec())
	timer.timeout.connect(refresh)
	refresh.call()
	timer.start()

## Pure presentation model for the city popup. Keeping progression math outside
## the controls makes the map interaction testable and prevents labels/actions
## from drifting apart as the economy is tuned.
func _city_inspector_model(index: int) -> Dictionary:
	var cities := Economy.country_cities(GameState.current_country)
	if index < 0 or index >= cities.size():
		return {}
	var active := index <= GameState.cities_unlocked
	var next := index == GameState.cities_unlocked + 1
	var realm_income := GameState.income_per_sec()
	var has_next := not GameState.all_cities_unlocked()
	var next_index := clampi(GameState.cities_unlocked + 1, 1, cities.size() - 1)
	var next_cost := GameState.next_city_cost() if has_next else -1.0
	return {
		"active": active,
		"next": next,
		"realm_income": realm_income,
		"city_income": realm_income if index == 0 else GameState.route_income_per_sec(index - 1),
		"has_next": has_next,
		"next_name": str(cities[next_index]["name"]) if has_next else "",
		"next_cost": next_cost,
		"next_gain": GameState.projected_city_income_gain(realm_income) if has_next else 0.0,
		"progress": clampf(GameState.credits / maxf(1.0, next_cost), 0.0, 1.0) if has_next else 1.0,
		"development_level": GameState.city_development_level(index),
		"development_cost": GameState.city_development_cost(index),
		"development_gain": GameState.projected_city_development_gain(index),
	}

## "Sair do jogo?" — only reached via the Android Back button with no popup open.
func _show_exit_confirm() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.ACCENT)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_gear", 30)); hd.add_child(_lbl(tr("Sair do jogo?"), 28, UITheme.INK)); box.add_child(hd)
	var yes := _wide_btn(UITheme.RED.darkened(0.2)); yes.text = tr("Sair")
	yes.custom_minimum_size = Vector2(0, 66)
	yes.pressed.connect(func(): get_tree().quit())
	box.add_child(yes)
	box.add_child(_close_btn(layer))

func _settings_stats_text() -> String:
	return tr("Entregas: %s  ·  Ganhos: %s\nRendimento: %s/s  ·  Combo: %d\nDrones: %d  ·  Países: %d/%d  ·  Streak: %dd\nPrestige: %d  ·  Conquistas: %d/%d") % [
		Fmt.short(float(GameState.total_deliveries)), Fmt.short(GameState.total_earned),
		Fmt.short(GameState.income_per_sec()), GameState.combo,
		GameState.drones, GameState.current_country + 1, Economy.num_countries(), Daily.streak,
		Prestige.count, Achievements.done_count(), Achievements.total_count()]

## Re-openable help uses the same one-screen tutorial as first launch, avoiding
## two competing explanations that gradually drift out of sync.
func _show_help() -> void:
	_show_welcome_popup()

func _show_settings() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.ACCENT)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 10)
	hd.add_child(_icon("ic_gear", 38)); hd.add_child(_lbl("Definições", 32, UITheme.INK)); box.add_child(hd)

	var help_btn := _wide_btn(UITheme.ACCENT.darkened(0.1)); help_btn.text = tr("Como jogar / Ajuda")
	help_btn.custom_minimum_size = Vector2(0, 60)
	help_btn.pressed.connect(func():
		Fx.press(help_btn)
		_dismiss(layer)
		# Let the Settings exit animation finish before the tutorial enters, so
		# two modal panels never stack or compete for Back/touch input.
		get_tree().create_timer(0.16).timeout.connect(_show_help)
	)
	box.add_child(help_btn)

	box.add_child(_settings_toggle("Som activado", not Audio.muted,
		func(on): Audio.muted = not on; SaveSystem.save_game()))
	box.add_child(_settings_toggle("Vibração", Fx.haptics,
		func(on):
			Fx.haptics = on
			if on: Fx.vibrate(60)   # immediate confirmation buzz so you can tell it works
			SaveSystem.save_game()))
	box.add_child(_settings_toggle("Reduzir animações", Fx.reduce_motion,
		func(on): Fx.set_reduce_motion(on); SaveSystem.save_game()))

	# Google UMP can require a permanent privacy-options entry point. It appears
	# only in a real AdMob build when the SDK says a form is available; desktop
	# and local-only builds keep the exact same compact settings layout.
	var ads_node := get_node_or_null("/root/Ads")
	if ads_node != null and bool(ads_node.call("privacy_options_available")):
		var privacy_btn := _wide_btn(UITheme.CYAN.darkened(0.18))
		privacy_btn.text = tr("Privacidade e anúncios")
		privacy_btn.custom_minimum_size = Vector2(0, 54)
		privacy_btn.pressed.connect(func():
			Fx.press(privacy_btn)
			ads_node.call("show_privacy_options")
		)
		box.add_child(privacy_btn)
	var lang_lbl := _lbl("Idioma / Language", 22, UITheme.INK); box.add_child(lang_lbl)
	# 9 languages don't fit one row, so wrap compact chips in a flow container.
	# Native short labels so speakers recognise their own language.
	var lang_flow := HFlowContainer.new(); lang_flow.add_theme_constant_override("h_separation", 6)
	lang_flow.add_theme_constant_override("v_separation", 6); box.add_child(lang_flow)
	var lang_btns := {}
	# Highlight tracks the CURRENT TranslationServer locale (not a build-time copy),
	# so it moves the moment a chip is pressed — matches every language, not just PT.
	var refresh_lang_btns := func():
		var cur := TranslationServer.get_locale().substr(0, 2)
		for code: String in lang_btns:
			var on: bool = (code == cur)
			var b: Button = lang_btns[code]
			b.add_theme_stylebox_override("normal", UITheme.seg(on))
			b.add_theme_stylebox_override("hover", UITheme.seg(on))
	for pair: Array in [["pt","PT"],["en","EN"],["es","ES"],["fr","FR"],["de","DE"],["it","IT"],["ru","RU"],["ja","日本語"],["zh","中文"]]:
		var code: String = pair[0]
		var lb := Button.new(); lb.text = pair[1]; lb.custom_minimum_size = Vector2(70, 56)
		lb.add_theme_font_size_override("font_size", 20)
		lb.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		lb.pressed.connect(func(): Fx.press(lb); _set_language(code); refresh_lang_btns.call())
		lang_flow.add_child(lb); lang_btns[code] = lb
	refresh_lang_btns.call()

	var rule := Panel.new(); rule.custom_minimum_size = Vector2(0, 2)
	rule.add_theme_stylebox_override("panel", UITheme.section_rule()); box.add_child(rule)

	var stats_card := PanelContainer.new()
	stats_card.add_theme_stylebox_override("panel", UITheme.solid(UITheme.PANEL, 14))
	box.add_child(stats_card)
	var stats := _lbl(_settings_stats_text(), 17, UITheme.MUTED)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_card.add_child(stats)
	_settings_stats_lbl = stats

	var attr := _lbl("Música: Eric Matyas · soundimage.org", 15, UITheme.MUTED)
	attr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(attr)

	# Read the version from ProjectSettings (single source of truth in
	# project.godot) rather than a hardcoded string — a hardcoded literal here
	# silently went stale across releases (showed an old version in Settings
	# even when the APK itself was current).
	var app_ver := str(ProjectSettings.get_setting("application/config/version", "?"))
	var ver := _lbl("Arcane Trade Empire · v%s" % app_ver, 15, UITheme.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(ver)

	var reset := Button.new(); reset.text = "Repor progresso"
	reset.add_theme_font_size_override("font_size", 20)
	reset.add_theme_color_override("font_color", UITheme.RED)
	reset.custom_minimum_size = Vector2(0, 56)
	reset.add_theme_stylebox_override("normal", UITheme.danger_outline())
	reset.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	reset.pressed.connect(func(): Fx.press(reset); _show_reset_confirm())
	box.add_child(reset)

	box.add_child(_close_btn(layer))

func _show_reset_confirm() -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.RED)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_gear", 26)); hd.add_child(_lbl("Repor progresso?", 28, UITheme.RED)); box.add_child(hd)
	var warn := _lbl("Apaga TODO o progresso: créditos, drones, países, prestige e conquistas.\nNão pode ser desfeito.", 18, UITheme.MUTED)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(warn)
	var confirm := Button.new(); confirm.text = "SIM, APAGAR TUDO"
	confirm.add_theme_font_size_override("font_size", 22); confirm.custom_minimum_size = Vector2(0, 66)
	confirm.add_theme_stylebox_override("normal", UITheme.danger_btn())
	confirm.add_theme_stylebox_override("focus",  StyleBoxEmpty.new())
	confirm.pressed.connect(func():
		layer.queue_free()
		_full_reset()
	)
	box.add_child(confirm)
	var cancel := Button.new(); cancel.text = "Cancelar"; cancel.add_theme_font_size_override("font_size", 22)
	cancel.custom_minimum_size = Vector2(0, 62); cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cancel.pressed.connect(func(): layer.queue_free()); box.add_child(cancel)

## Wipes progress WITHOUT reload_current_scene() — same native-crash-on-Android
## reason as the language switch (see _set_language). Resets the gameplay
## autoloads named in the confirm dialog (credits/drones/countries/prestige/
## achievements) in place, then rebuilds the UI pieces that don't already
## refresh every frame from that state.
func _full_reset() -> void:
	# The confirm dialog frees only ITS OWN layer — the Settings popup opened
	# underneath it is a separate CanvasLayer and would otherwise be left
	# floating on top of the freshly-reset game. Close every overlay so the
	# player lands cleanly back on the main view, same as the old (crashing)
	# reload_current_scene() effectively did by tearing down the whole scene.
	for c in get_children():
		if c is CanvasLayer:
			c.queue_free()
	GameState.reset()
	Prestige.reset()
	Achievements.reset()
	SaveSystem.save_game()
	_disp_credits = 0.0
	_prev_gems = GameState.gems; _prev_infl = GameState.influence
	_prev_combo_mult = 1.0
	_income_milestone_idx = 0
	_rebuild_city_list()
	_rebuild_prestige_shop()
	_rebuild_achievements()
	_switch_tab(0)
	_toast(tr("Progresso reposto."), UITheme.RED, "ic_gear")

func _show_offline_popup(amount: float, seconds: float) -> void:
	var layer := _overlay(); var box := _popup_box(layer, UITheme.ACCENT)
	var hd := HBoxContainer.new(); hd.alignment = BoxContainer.ALIGNMENT_CENTER; hd.add_theme_constant_override("separation", 8)
	hd.add_child(_icon("ic_income", 28)); hd.add_child(_lbl("Bem-vindo de volta!", 30, UITheme.INK)); box.add_child(hd)
	var m := _lbl(tr("Os drones entregaram durante %s:") % Fmt.duration(seconds), 19, UITheme.MUTED)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; m.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; box.add_child(m)
	var big := _lbl(Fmt.short(amount), 40, UITheme.GOLD)
	big.add_theme_font_override("font", UITheme.font("Bold"))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(big)
	# Rate and offline capacity are shown transparently without an upsell.
	var cap := GameState.offline_cap()
	var rate_lbl := _lbl(tr("Taxa: %s/s · limite offline %s") % [Fmt.short(GameState.income_per_sec()), Fmt.duration(cap)], 14, UITheme.MUTED)
	rate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; box.add_child(rate_lbl)
	if seconds >= cap - 1.0:
		var up := _lbl(tr("Armazém offline completamente cheio."), 15, UITheme.GOLD)
		up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; up.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(up)
	if not Fx.reduce_motion:
		var ctw := create_tween()
		# guard: a player who taps "Recolher" before the 0.9s count-up finishes
		# frees `big` (and the whole popup) while this tween is still stepping it
		var _set_big_text := func(v: float) -> void:
			if is_instance_valid(big):
				big.text = Fmt.short(v)
		ctw.tween_method(_set_big_text, 0.0, amount, 0.9) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var collect := Button.new(); collect.text = tr("Recolher")
	collect.add_theme_font_size_override("font_size", 24); collect.custom_minimum_size = Vector2(0, 70)
	collect.add_theme_stylebox_override("normal", UITheme.action_btn(UITheme.GREEN))
	collect.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	collect.pressed.connect(func():
		GameState.collect_offline(1.0)
		_disp_credits = GameState.credits
		Fx.coin_fountain(self, collect.get_global_rect().get_center(), _credits_chip.get_global_rect().get_center(), 12)
		Fx.chip_pop(_credits_chip, UITheme.GOLD)
		Audio.play("milestone")
		layer.queue_free()
	)
	box.add_child(collect)

## Keeps the return reward discoverable without stealing the first interaction.
## A stable signature avoids rebuilding the chip style every frame.
func _refresh_daily_hud() -> void:
	if not is_instance_valid(_streak_chip) or not is_instance_valid(_streak_lbl):
		return
	var sig := "%s:%d" % [str(Daily.pending), Daily.streak]
	if sig == _daily_hud_sig:
		return
	_daily_hud_sig = sig
	_streak_lbl.text = tr("Recolher") if Daily.pending else "%dd" % Daily.streak
	var accent := UITheme.GOLD if Daily.pending else UITheme.AMBER
	_streak_lbl.add_theme_color_override("font_color", accent)
	_streak_chip.add_theme_stylebox_override("panel", UITheme.stat_chip(accent))
	_streak_chip.modulate = UITheme.GOLD if not Daily.pending and Daily.streak >= 7 else Color.WHITE

func _overlay() -> CanvasLayer:
	var layer := CanvasLayer.new(); layer.layer = 150
	var dim := ColorRect.new(); dim.color = Color(0.02, 0.03, 0.07, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# tap the dimmed area (outside the panel) to dismiss — a mobile expectation.
	# Canceling a destructive confirm this way is harmless (nothing fires on close).
	dim.gui_input.connect(func(e: InputEvent):
		var tapped: bool = (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
			or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
		if tapped and is_instance_valid(layer):
			_dismiss(layer))
	layer.add_child(dim); add_child(layer)
	var tw := create_tween()
	tw.tween_property(dim, "color:a", 0.78, 0.2)
	return layer

func _popup_box(layer: CanvasLayer, accent := UITheme.ACCENT) -> VBoxContainer:
	# ScrollContainer anchored to a tall region with screen-edge margins, so the
	# popup always has a real (non-zero) height and scrolls if taller than screen.
	var sc := ScrollContainer.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 30; sc.offset_right = -30
	sc.offset_top = 64; sc.offset_bottom = -64
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(sc)
	# Center the panel vertically when the content is shorter than the viewport.
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size = Vector2(0, 1)
	sc.add_child(col)
	var pc := PanelContainer.new(); pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UITheme.popup_frame(accent)); col.add_child(pc)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 14); pc.add_child(box)
	# fade + tiny spring-in (modulate always ends at 1, even with reduce_motion)
	pc.modulate = Color(1, 1, 1, 0)
	if Fx.reduce_motion:
		pc.modulate = Color.WHITE
	else:
		pc.pivot_offset = Vector2(330, 90); pc.scale = Vector2(0.96, 0.96)
		var tw := pc.create_tween(); tw.set_parallel(true)
		tw.tween_property(pc, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(pc, "modulate:a", 1.0, 0.18)
	return box

func _close_btn(layer: CanvasLayer) -> Button:
	var close := Button.new(); close.text = "Fechar"; close.add_theme_font_size_override("font_size", 26)
	close.custom_minimum_size = Vector2(0, 64); close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(func(): Fx.press(close); _dismiss(layer))
	return close

## Symmetric close for popups: every popup springs IN (see _popup_box) but used to
## vanish on a hard queue_free(), a jump-cut exit undercutting a considered entrance.
## Fades the dim + panel over 0.13s, then frees. Snap under reduce_motion.
func _dismiss(layer: CanvasLayer) -> void:
	if not is_instance_valid(layer):
		return
	if Fx.reduce_motion:
		layer.queue_free(); return
	var tw := create_tween(); tw.set_parallel(true)
	for ch in layer.get_children():
		if ch is ColorRect:
			tw.tween_property(ch, "color:a", 0.0, 0.13).set_ease(Tween.EASE_IN)
		elif ch is CanvasItem:
			tw.tween_property(ch, "modulate:a", 0.0, 0.13).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(layer.queue_free)

# ── Primitives ───────────────────────────────────────────────────────────────────

func _lbl(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new(); l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color); return l

func _icon(n: String, sz := 30) -> TextureRect:
	var r := TextureRect.new(); r.texture = _opt_tex(n); r.custom_minimum_size = Vector2(sz, sz)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; return r

## Row icon in a small accent-tinted circular backdrop (see UITheme.icon_badge)
## — replaces a bare floating glyph with the "icon chip" look of AAA mobile UIs.
func _icon_badge(icon_name: String, accent: Color, sz := 44, icon_sz := 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(sz, sz)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UITheme.icon_badge(accent, sz, icon_sz))
	p.add_child(_icon(icon_name, icon_sz))
	return p

## Cached: the per-frame skins loop calls this ~5x/frame, and every call was 2
## String concats + ResourceLoader.exists() (mutex + path validation) + load()
## (LoadToken alloc + loader mutex even on a cache hit) — all discarded, since
## Button::set_icon early-outs on an identical texture. Art is static. Mirrors
## the same cache Fx._tex already uses.
var _tex_cache := {}

func _opt_tex(n: String) -> Texture2D:
	if _tex_cache.has(n):
		return _tex_cache[n] as Texture2D
	var path := ART + n + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[n] = tex
	return tex

# ── Floating delivery earnings ────────────────────────────────────────────────────

func _on_delivered(amount: float, _city_idx: int, _count: int) -> void:
	_delivery_fx_bank += amount
	var now_ms := Time.get_ticks_msec()
	# The label animation lasts 0.9s. A 1.05s gate guarantees that only one
	# earnings value can ever occupy the map, even in extreme late-game income.
	if now_ms - _last_delivery_fx_ms < 1050:
		return
	_last_delivery_fx_ms = now_ms
	var shown_amount := _delivery_fx_bank
	_delivery_fx_bank = 0.0
	var cx := size.x * 0.5 + randf_range(-80, 80)
	var cy := size.y * 0.42 + randf_range(-50, 50)
	Fx.floating_label(self, "+" + Fmt.short(shown_amount), Fx.GOLD, Vector2(cx, cy), 24)
	# every ~8th shown delivery, fly coins into the credits chip (it never
	# animated before — the core earn beat now lands on the HUD)
	_fountain_counter += 1
	if _fountain_counter % 8 == 0:
		Fx.coin_fountain(self, Vector2(cx, cy), _credits_chip.get_global_rect().get_center(), 6)
		Fx.chip_pop(_credits_chip, UITheme.GOLD)

# ── Contract signal handlers ──────────────────────────────────────────────────────

func _on_contract_completed(_slot: int) -> void:
	_toast(tr("Missão concluída! Recompensa recebida"), UITheme.CYAN, "ic_achieve")
	Fx.confetti(self, Vector2(size.x * 0.5, size.y * 0.45), 30, [UITheme.CYAN, UITheme.GREEN, UITheme.GOLD])
	Fx.screen_flash(self, UITheme.CYAN, 0.10)
	Audio.play("milestone")

# ── Income milestone celebration ──────────────────────────────────────────────────

func _check_income_milestones(ips: float) -> void:
	while _income_milestone_idx < INCOME_MILESTONES.size() and ips >= float(INCOME_MILESTONES[_income_milestone_idx]):
		var lbl: String = str(MILESTONE_LABELS[_income_milestone_idx])
		_toast(tr("Nova marca: %s/s!") % lbl, UITheme.GREEN, "ic_fleet")
		var c := Vector2(size.x * 0.5, size.y * 0.43)
		Fx.confetti(self, c, 36, [UITheme.GREEN, UITheme.GOLD, UITheme.CYAN])
		Fx.screen_flash(self, UITheme.GREEN, 0.12)
		Fx.ring_pulse(self, c, UITheme.GREEN, 2.6)
		_income_milestone_idx += 1

# ── Contract card UI updates ──────────────────────────────────────────────────────

func _update_contracts() -> void:
	_update_contract_visibility()
	for i in range(Contracts.SLOT_COUNT):
		if i >= _mission_title_lbls.size(): break
		var s: Dictionary = Contracts.slots[i] if i < Contracts.slots.size() else {}
		var claimed: bool = s.get("claimed", false)
		var ready: bool = s.get("ready", false) and not claimed
		var prog: float = float(s.get("progress", 0.0))

		# time remaining ticks continuously — always updated, never gated
		var rem := Contracts.time_remaining(i)
		var t_lbl := _mission_time_lbls[i] as Label
		if claimed:
			t_lbl.text = tr("Nova em %ds") % int(rem)
		elif i == 3:
			t_lbl.text = "%dd %dh" % [int(rem) / 86400, (int(rem) % 86400) / 3600]
		else:
			t_lbl.text = "%d:%02d" % [int(rem) / 60, int(rem) % 60]

		# everything below only actually changes when progress/ready/claimed
		# do — skip the tr()/Fmt.short() text rebuild + fill update otherwise
		# (this runs 4x/sec; most of those ticks nothing here has moved)
		if prog == _mission_last_progress[i] and ready == _mission_last_ready[i] and claimed == _mission_last_claimed[i]:
			continue
		_mission_last_progress[i] = prog; _mission_last_ready[i] = ready; _mission_last_claimed[i] = claimed

		(_mission_title_lbls[i] as Label).text = Contracts.format_label(s)
		_set_fill(_mission_prog_bars[i] as Panel, Contracts.progress_pct(i))
		var tgt := float(s.get("target", 1.0))
		var prg := minf(prog, tgt)
		(_mission_prog_lbls[i] as Label).text = Fmt.short(prg) + "/" + Fmt.short(tgt)
		var cbtn := _mission_claim_btns[i] as Button
		cbtn.disabled = not ready
		if ready:
			cbtn.text = tr("REIVINDICAR"); cbtn.icon = null
		elif claimed:
			cbtn.text = tr("Recebido"); cbtn.icon = _opt_tex("ic_check")
		else:
			cbtn.text = tr("Em curso"); cbtn.icon = null
		_afford(cbtn, ready)
		if i < _mission_x2_btns.size():
			# Teach the free claim loop before presenting a gem-spend alternative.
			(_mission_x2_btns[i] as Button).visible = ready and GameState.current_country >= 1
		if i < _mission_reroll_btns.size():
			(_mission_reroll_btns[i] as Button).visible = (i < 3) and _mission_visible_count >= 2 and not ready and not claimed
		var rc: float = float(s.get("reward_credits", 0.0))
		var rg: int = int(s.get("reward_gems", 0))
		(_mission_reward_lbls[i] as Label).text = "+" + Fmt.short(rc)
		if i < _mission_gem_lbls.size():
			(_mission_gem_icons[i] as TextureRect).visible = rg > 0
			var gl := _mission_gem_lbls[i] as Label
			gl.visible = rg > 0
			gl.text = "+%d" % rg
	# show "claim all" only when 2+ contracts are claimable at once
	if _claim_all_btn != null and is_instance_valid(_claim_all_btn):
		var ready_n := 0
		for i in range(mini(_mission_visible_count, Contracts.slots.size())):
			var s: Dictionary = Contracts.slots[i]
			if s.get("ready", false) and not s.get("claimed", false):
				ready_n += 1
		var claim_all_available := ready_n >= 2
		if claim_all_available != _claim_all_available:
			_claim_all_available = claim_all_available
			_claim_all_btn.set_meta("progression_hidden", not claim_all_available)
			_refresh_page_container(_claim_all_btn)

## Grow the contract board with the trade network instead of presenting the
## complete live-service stack on its first reveal. Existing contracts keep
## progressing in the background, so no earned progress or reward is lost.
func _available_contract_count() -> int:
	if GameState.current_country >= 1:
		return Contracts.SLOT_COUNT
	if GameState.cities_unlocked >= 5:
		return 3
	if GameState.cities_unlocked >= 4:
		return 2
	if GameState.cities_unlocked >= 2:
		return 1
	return 0

func _update_contract_visibility() -> void:
	var visible_count := _available_contract_count()
	if visible_count == _mission_visible_count:
		return
	_mission_visible_count = visible_count
	for i in range(_mission_cards.size()):
		(_mission_cards[i] as Control).set_meta("progression_hidden", i >= visible_count)
	if is_instance_valid(_mission_weekly_section):
		_mission_weekly_section.set_meta("progression_hidden", visible_count < Contracts.SLOT_COUNT)
	if not _mission_cards.is_empty():
		_refresh_page_container(_mission_cards[0] as Control)

# ── Missions tab ──────────────────────────────────────────────────────────────────

func _build_missions_tab() -> ScrollContainer:
	var r := _scroll("Missões"); var v: VBoxContainer = r[1]
	var info := _lbl("Completa missões para ganhar créditos e gemas bónus.", 16, UITheme.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(info)

	# "Reivindicar tudo" — appears when ≥2 slots are claimable (common after an
	# offline session); no more tapping each one individually
	_claim_all_btn = _wide_btn(UITheme.GREEN)
	_claim_all_btn.text = tr("Reivindicar tudo")
	_claim_all_btn.custom_minimum_size = Vector2(0, 58)
	_claim_all_btn.set_meta("progression_hidden", true)
	_claim_all_btn.visible = false
	_claim_all_btn.pressed.connect(func():
		if not _can_tap(): return
		Fx.press(_claim_all_btn)
		for i in range(Contracts.SLOT_COUNT):
			var s: Dictionary = Contracts.slots[i] if i < Contracts.slots.size() else {}
			if s.get("ready", false) and not s.get("claimed", false):
				Contracts.claim(i)
		_disp_credits = GameState.credits
		Fx.chip_pop(_credits_chip, UITheme.GOLD))
	v.add_child(_claim_all_btn)

	for i in range(Contracts.SLOT_COUNT):
		if i == 3:
			_mission_weekly_section = _section("Desafio Semanal", UITheme.GOLD, "ic_achieve")
			_mission_weekly_section.set_meta("progression_hidden", true)
			v.add_child(_mission_weekly_section)
		var slot_color: Color = UITheme.GOLD if i == 3 else UITheme.CYAN
		var s: Dictionary = Contracts.slots[i] if i < Contracts.slots.size() else {}
		var card := _card(slot_color)
		card.set_meta("progression_hidden", true)
		_mission_cards.append(card)
		v.add_child(card)
		var cv := VBoxContainer.new(); cv.add_theme_constant_override("separation", 8); card.add_child(cv)

		# Top row: title + time remaining
		var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 6); cv.add_child(top)
		var title := _lbl(Contracts.format_label(s), 18, UITheme.INK)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; top.add_child(title)
		_mission_title_lbls.append(title)
		var time_lbl := _lbl("--:--", 15, UITheme.MUTED); top.add_child(time_lbl)
		_mission_time_lbls.append(time_lbl)

		# Reroll rotating contracts directly; the weekly contract remains fixed.
		var ri := i
		var rbtn := Button.new(); rbtn.text = tr("Trocar")
		rbtn.icon = _opt_tex("ic_range"); rbtn.expand_icon = true
		rbtn.add_theme_constant_override("icon_max_width", 20)
		rbtn.add_theme_font_size_override("font_size", 16)
		rbtn.custom_minimum_size = Vector2(96, 44)
		rbtn.add_theme_stylebox_override("normal",  UITheme.solid(UITheme.PANEL2, 12))
		rbtn.add_theme_stylebox_override("hover",   UITheme.solid(UITheme.PANEL2.lightened(0.08), 12))
		rbtn.add_theme_stylebox_override("pressed", UITheme.solid(UITheme.PANEL2.darkened(0.12), 12))
		rbtn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
		rbtn.visible = (i < 3)
		rbtn.pressed.connect(func():
			if not _can_tap(): return
			Fx.press(rbtn)
			if Contracts.reroll(ri):
				_toast(tr("Missão substituída!"), UITheme.CYAN, "ic_achieve")
		)
		top.add_child(rbtn)
		_mission_reroll_btns.append(rbtn)

		# Progress bar
		var pb_bg := Panel.new(); pb_bg.custom_minimum_size = Vector2(0, 8)
		pb_bg.add_theme_stylebox_override("panel", UITheme.prog_bg()); cv.add_child(pb_bg)
		var pb_fill := Panel.new(); pb_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		pb_fill.anchor_right = 0.0
		pb_fill.add_theme_stylebox_override("panel", UITheme.prog_fill(slot_color))
		pb_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE; pb_bg.add_child(pb_fill)
		_mission_prog_bars.append(pb_fill)

		# Bottom row: progress text + reward label + claim button
		var bot := HBoxContainer.new(); bot.add_theme_constant_override("separation", 6); cv.add_child(bot)
		var prog_lbl := _lbl("0/0", 15, UITheme.MUTED)
		prog_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bot.add_child(prog_lbl)
		_mission_prog_lbls.append(prog_lbl)

		var rc: float = float(s.get("reward_credits", 0.0))
		var rg: int = int(s.get("reward_gems", 0))
		var rew_lbl := _lbl("+" + Fmt.short(rc), 15, UITheme.GREEN); bot.add_child(rew_lbl)
		_mission_reward_lbls.append(rew_lbl)
		var gic := _icon("ic_gems", 16); gic.visible = rg > 0; bot.add_child(gic)
		_mission_gem_icons.append(gic)
		var gem_lbl := _lbl("+%d" % rg, 15, UITheme.CYAN); gem_lbl.visible = rg > 0; bot.add_child(gem_lbl)
		_mission_gem_lbls.append(gem_lbl)

		var ci := i
		var cbtn := _buy_btn(slot_color.darkened(0.18))
		cbtn.text = tr("Em curso"); cbtn.disabled = true
		cbtn.expand_icon = true
		cbtn.add_theme_constant_override("icon_max_width", 20)
		cbtn.size_flags_horizontal = Control.SIZE_SHRINK_END
		cbtn.custom_minimum_size = Vector2(130, 52)
		cbtn.add_theme_font_size_override("font_size", 16)
		cbtn.pressed.connect(func():
			if not _can_tap(): return
			Fx.press(cbtn)
			if Contracts.claim(ci):
				Audio.play("buy")
				Fx.chip_pop(_credits_chip, UITheme.GOLD)
		)
		bot.add_child(cbtn)
		_mission_claim_btns.append(cbtn)

		# Optional gem investment for a doubled contract payout.
		var xbtn := _buy_btn(UITheme.GREEN_D)
		xbtn.text = "2× · 1"
		xbtn.icon = _opt_tex("ic_gems"); xbtn.expand_icon = true
		xbtn.add_theme_constant_override("icon_max_width", 20)
		xbtn.size_flags_horizontal = Control.SIZE_SHRINK_END
		xbtn.custom_minimum_size = Vector2(84, 52)
		xbtn.add_theme_font_size_override("font_size", 16)
		xbtn.visible = false
		xbtn.pressed.connect(func():
			if not _can_tap(): return
			Fx.press(xbtn)
			if GameState.gems < 1:
				Fx.error_shake(xbtn)
				return
			GameState.gems -= 1
			if Contracts.claim(ci, 2.0):
				Audio.play("milestone")
				Fx.chip_pop(_credits_chip, UITheme.GOLD)
				_toast(tr("Recompensa a DOBRAR!"), UITheme.GREEN, "ic_achieve")
		)
		bot.add_child(xbtn)
		_mission_x2_btns.append(xbtn)

	_update_contract_visibility()
	return r[0]
