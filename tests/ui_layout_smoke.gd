extends SceneTree
## Exercises the premium no-scroll dashboard at representative portrait sizes.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const LAYOUTS := [
	Vector2i(720, 1280),  # compact 16:9 phone
	Vector2i(720, 1560),  # modern tall phone
	Vector2i(900, 1280),  # portrait tablet / foldable
]

var _failure := ""

func _initialize() -> void:
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
		get_root().size = requested_size
		await process_frame

		var main := MAIN_SCENE.instantiate() as Control
		get_root().add_child(main)
		for _frame in range(5):
			await process_frame

		var canvas: Vector2 = main.size
		if not _check(canvas.x >= 700.0 and canvas.y >= 1200.0,
				"invalid logical canvas %s for %s" % [canvas, requested_size]):
			break

		var nav := main.get("_nav_bar") as Control
		var pages: Array = main.get("_pages")
		if not _check(is_instance_valid(nav), "bottom navigation missing"):
			break
		if not _check(absf(nav.position.y + nav.size.y - canvas.y) <= 2.0,
				"navigation leaves the viewport at %s" % requested_size):
			break

		for page_node in pages:
			var page := page_node as ScrollContainer
			if not _check(page.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
					"vertical dashboard scrolling enabled at %s" % requested_size):
				break
			if not _check(page.position.y >= -1.0 and page.position.y + page.size.y <= nav.position.y + 2.0,
					"management panel overlaps navigation at %s" % requested_size):
				break
		if not _failure.is_empty():
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
		await process_frame
		await process_frame

	if _failure.is_empty():
		print("UI_LAYOUT_SMOKE: PASS (3 portrait classes, no vertical dashboard scroll, 44px touch targets)")
		quit(0)
	else:
		quit(1)
