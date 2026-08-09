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
				"HUD no longer matches reference frame at %s" % requested_size):
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
		print("UI_LAYOUT_SMOKE: PASS (reference frame + 4 landscape classes + 44px touch targets)")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
