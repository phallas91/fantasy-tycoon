extends Node
## Exercises the premium no-scroll dashboard at representative landscape sizes.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LAYOUTS := [
	Vector2i(1152, 648),  # exact reference screenshot (90% window scale)
	Vector2i(1280, 720),  # compact 16:9 phone
	Vector2i(1560, 720),  # wide modern phone
	Vector2i(1280, 900),  # landscape tablet / foldable
]

const REF_GUTTER := 12.0
const REF_HUD_TOP := 20.0
const REF_PANEL_RIGHT := 410.0
const REF_PANEL_TOP := 150.0
const REF_NAV_HEIGHT := 70.0

var _failure := ""

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failure = message
	push_error("UI_LAYOUT_SMOKE: " + message)
	return false

func _run() -> void:
	Fx.set_reduce_motion(true)
	for requested_size: Vector2i in LAYOUTS:
		get_tree().root.size = requested_size
		await get_tree().process_frame

		var main := MAIN_SCENE.instantiate() as Control
		get_tree().root.add_child(main)
		for _frame in range(5):
			await get_tree().process_frame

		# The automatic manager used to dominate the fresh fleet panel before the
		# player understood manual construction. Guard both sides of its rank gate.
		GameState.prosperity_rank = 0
		main.call("_process", 0.0)
		if not _check(not (main.get("_auto_mgr_section") as Control).visible
				and not (main.get("_auto_mgr_toggle") as Control).visible,
				"automatic manager visible in the opening chapter"):
			break
		GameState.prosperity_rank = 2
		main.call("_process", 0.0)
		if not _check((main.get("_auto_mgr_section") as Control).visible
				and (main.get("_auto_mgr_toggle") as Control).visible,
				"automatic manager did not unlock at city rank 2"):
			break
		GameState.prosperity_rank = 0

		# Monetization must follow player understanding instead of presenting an
		# eight-product wall on first launch. Exercise the pure catalogue gates at
		# every progression beat before restoring the normal fresh-save state.
		GameState.current_country = 0; Prestige.count = 0
		Billing.starter_owned = false; Billing.vip = false; Billing.perm_mult = 1.0
		if not _check(int(main.call("_shop_catalog_stage")) == 0,
				"paid catalogue visible before the core loop"):
			break
		GameState.current_country = 1
		if not _check(int(main.call("_shop_catalog_stage")) == 1
				and bool(main.call("_shop_product_unlocked", "starter", 1))
				and not bool(main.call("_shop_product_unlocked", "vip", 1)),
				"starter chapter exposes more than its single contextual offer"):
			break
		GameState.current_country = 3
		if not _check(int(main.call("_shop_catalog_stage")) == 2
				and bool(main.call("_shop_product_unlocked", "perm_x2", 2))
				and not bool(main.call("_shop_product_unlocked", "gems_xs", 2)),
				"permanent-offer chapter exposes consumable currency"):
			break
		Prestige.count = 1
		if not _check(int(main.call("_shop_catalog_stage")) == 3
				and bool(main.call("_shop_product_unlocked", "gems_m", 3))
				and not bool(main.call("_shop_product_unlocked", "gems_xl", 3)),
				"first prestige does not use a restrained gem catalogue"):
			break
		Prestige.count = 2
		if not _check(int(main.call("_shop_catalog_stage")) == 4
				and bool(main.call("_shop_product_unlocked", "gems_xl", 4)),
				"veteran catalogue never reaches its final stage"):
			break
		GameState.current_country = 0; Prestige.count = 0
		main.call("_refresh_progressive_nav")
		# A developer save may restore motion after this test disables it and start
		# the boot tween with the HUD above the screen. Layout assertions target the
		# settled frame, so apply the same final safe-area geometry deterministically.
		main.call("_apply_safe_area")

		var canvas: Vector2 = main.size
		if not _check(canvas.x >= 1200.0 and canvas.y >= 700.0,
				"invalid logical canvas %s for %s" % [canvas, requested_size]):
			break

		var nav := main.get("_nav_bar") as Control
		var hud := main.get("_hud") as Control
		var panel := main.get("_bottom_bg") as Control
		var pages: Array = main.get("_pages")
		if not _check(is_instance_valid(nav), "bottom navigation missing"):
			break
		if not _check(is_instance_valid(hud) and is_instance_valid(panel),
				"reference HUD or side panel missing"):
			break
		if not _check(absf(hud.position.x - REF_GUTTER) <= 1.0
				and absf(hud.position.y - REF_HUD_TOP) <= 1.0
				and absf(hud.position.x + hud.size.x - (canvas.x - REF_GUTTER)) <= 1.0,
				"HUD %s size %s no longer matches canvas %s reference frame at %s" % [hud.position, hud.size, canvas, requested_size]):
			break
		if not _check(absf(panel.position.x - REF_GUTTER) <= 1.0
				and absf(panel.position.y - REF_PANEL_TOP) <= 1.0
				and absf(panel.position.x + panel.size.x - REF_PANEL_RIGHT) <= 1.0,
				"side dashboard no longer matches reference frame at %s" % requested_size):
			break
		if not _check(absf(nav.size.y - REF_NAV_HEIGHT) <= 1.0,
				"navigation height no longer matches reference at %s" % requested_size):
			break
		if not _check(absf(nav.position.y + nav.size.y - canvas.y) <= 2.0,
				"navigation leaves the viewport at %s" % requested_size):
			break

		for page_node in pages:
			var page := page_node as ScrollContainer
			if not _check(page.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
					"vertical dashboard scrolling enabled at %s" % requested_size):
				break
			if not page.is_visible_in_tree():
				continue
			if not _check(page.position.y >= -1.0 and page.position.y + page.size.y <= nav.position.y + 2.0,
					"management panel %.1f..%.1f overlaps navigation at %.1f for %s" % [
						page.position.y, page.position.y + page.size.y, nav.position.y, requested_size]):
				break
		if not _failure.is_empty():
			break

		# Expansion now resets the local tycoon chapter, so its confirmation is a
		# release-critical mobile surface rather than an optional settings popup.
		main.call("_show_expansion_confirm")
		await get_tree().process_frame
		await get_tree().process_frame
		var overlays := main.find_children("", "CanvasLayer", false, false)
		if not _check(not overlays.is_empty(), "realm expansion confirmation missing"):
			break

		for button_node in main.find_children("", "Button", true, false):
			var button := button_node as Button
			if not button.is_visible_in_tree() or button.disabled:
				continue
			if not _check(button.size.y >= 44.0,
					"touch target '%s' is only %.1f px high at %s" % [button.text, button.size.y, requested_size]):
				break
		if not _failure.is_empty():
			break

		main.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame

	if _failure.is_empty():
		print("UI_LAYOUT_SMOKE: PASS (reference frame + staged shop + 4 landscape classes + 44px touch targets)")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
