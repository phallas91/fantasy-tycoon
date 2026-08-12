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
const REF_PANEL_TOP := 170.0
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
		# Headless Linux may restore the project default window size once when the
		# first full-rect scene enters the tree. Reassert the requested device frame
		# during layout settling; if a real control minimum prevents shrinking, the
		# strict canvas assertion below still fails with the measured dimensions.
		for _frame in range(5):
			get_tree().root.size = requested_size
			await get_tree().process_frame
		var map := main.get("_map") as Control
		GameState.cities_unlocked = 1
		GameState.prosperity_rank = 0
		var fresh_realm_fog := float(map.call("_growth_fog_strength"))
		GameState.cities_unlocked = 5
		GameState.prosperity_rank = 3
		var mature_realm_fog := float(map.call("_growth_fog_strength"))
		if not _check(fresh_realm_fog >= 0.65 and mature_realm_fog <= 0.25,
				"mature panorama is not progressively revealed through city growth"):
			break
		map.call("reveal_landmark", "cargo", tr("Armazéns da Guilda"))
		if not _check(str(map.get("_landmark_reveal_key")) == "cargo"
				and str(map.get("_landmark_reveal_name")) == tr("Armazéns da Guilda")
				and float(map.get("_landmark_reveal_time")) > 2.0,
				"completed landmark is not revealed at its world-space district"):
			break
		map.call("_process", 3.0)
		if not _check(str(map.get("_landmark_reveal_key")).is_empty()
				and str(map.get("_landmark_reveal_name")).is_empty(),
				"world-space landmark reveal does not clear after its ceremony"):
			break

		# A ready return reward must invite rather than interrupt. Even when the
		# pending flag is already true at boot, no blocking overlay may be created;
		# the reachable 44px HUD chip carries the claim state instead.
		Daily.pending = true
		GameState.pending_offline = 0.0
		GameState.pending_offline_seconds = 0.0
		main.call("_post_boot", true)
		main.call("_process", 0.0)
		await get_tree().process_frame
		var launch_reward_overlays := 0
		for launch_child in main.get_children():
			if launch_child is CanvasLayer and (launch_child as CanvasLayer).layer == 150:
				launch_reward_overlays += 1
		if not _check(launch_reward_overlays == 0
				and (main.get("_streak_chip") as Control).custom_minimum_size.y >= 44.0
				and (main.get("_streak_lbl") as Label).text == tr("Recolher"),
				"daily reward blocks launch instead of waiting in its HUD claim chip"):
			break
		Daily.pending = false
		main.call("_process", 0.0)

		# Data-authored economy labels must use the same locale pipeline as scene
		# copy. These were previously German literals in every non-German locale.
		var original_locale := TranslationServer.get_locale()
		for economy_locale: String in ["pt", "en", "es", "fr", "it", "ru", "ja", "zh"]:
			TranslationServer.set_locale(economy_locale)
			if not _check(tr("Reisetempo") != "Reisetempo"
					and tr("Große Handelsgilde") != "Große Handelsgilde"
					and (economy_locale == "pt" or tr("Caçador Dourado") != "Caçador Dourado")
					and (economy_locale == "pt" or tr("Reputação permanente ×%.2f → ×%.2f")
						!= "Reputação permanente ×%.2f → ×%.2f"),
					"economy data remains German in locale " + economy_locale):
				break
		TranslationServer.set_locale(original_locale)

		GameState.current_country = 0
		GameState.cities_unlocked = 1
		GameState.drones = 1
		for opening_key: String in GameState.levels:
			GameState.levels[opening_key] = 0
		var opening_objective: Dictionary = main.call("_smart_objective")
		if not _check(str(opening_objective.get("text", "")) == tr("Começa a tua primeira rota comercial")
				and opening_objective.get("focus") == main.get("_focus_btn"),
				"opening objective competes with the guided courier action"):
			break
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		if not _check(not (main.get("_ribbon_bg") as Control).visible
				and not (main.get("_next_obj_lbl") as Control).visible,
				"opening action is duplicated in the global objective ribbon"):
			break
		GameState.drones = 2
		GameState.prosperity_rank = 0
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		main.call("_refresh_focus_action")
		if not _check(not (main.get("_ribbon_bg") as Control).visible
				and not (main.get("_next_obj_lbl") as Control).visible
				and (main.get("_focus_card") as Control).visible
				and "2/4" in str((main.get("_focus_title") as Label).text),
				"dashboard opens before the four-griffin lesson is complete"):
			break
		var fleet_objective: Dictionary = main.call("_smart_objective")
		if not _check("2/4" in str(fleet_objective.get("text", ""))
				and is_equal_approx(float(fleet_objective.get("progress", 0.0)), 0.5)
				and bool(fleet_objective.get("progress_override", false))
				and fleet_objective.get("focus") == main.get("_drone_btn"),
				"courier lesson is not a concrete four-griffin mini-goal"):
			break
		# Even abundant credits must not skip the opening construction lesson.
		GameState.drones = 4
		GameState.credits = 1.0e12
		GameState.prosperity_rank = 0
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		main.call("_process", 0.0)
		if not _check((main.get("_ribbon_bg") as Control).visible
				and (main.get("_next_obj_lbl") as Control).visible
				and not (main.get("_focus_card") as Control).visible,
				"dashboard does not open after the four-griffin lesson"):
			break
		await get_tree().process_frame
		var fleet_page := (main.get("_pages") as Array)[0] as ScrollContainer
		var fleet_pager := fleet_page.get_meta("page_pager") as Control
		if not _check(not fleet_pager.visible and fleet_page.anchor_bottom == 0.0
				and fleet_page.offset_bottom < main.size.y - 70.0,
				"single-page opening dashboard leaves an empty pager panel (pager=%s, anchor=%.1f, bottom=%.1f, canvas=%.1f)" % [
					fleet_pager.visible, fleet_page.anchor_bottom, fleet_page.offset_bottom, main.size.y]):
			break
		var construction_objective: Dictionary = main.call("_smart_objective")
		if not _check(construction_objective.get("tab") == 0
				and construction_objective.get("upgrade_key") == "cargo"
				and tr("Reisetempo") in str(construction_objective.get("text", ""))
				and tr("Handelswert") in str(construction_objective.get("text", "")),
				"affordable settlement interrupts the opening construction chapter"):
			break
		GameState.prosperity_rank = 1
		var route_preview: String = str(main.call("_next_prosperity_unlock_text"))
		if not _check(tr("Handelsrouten") in route_preview
				and tr("Gestor de Frota Automático") in route_preview,
				"opening chapter does not preview routes and automation"):
			break
		GameState.prosperity_rank = 2
		var realm_objective: Dictionary = main.call("_smart_objective")
		if not _check(not bool(main.call("_opening_city_chapter_active"))
				and not realm_objective.has("upgrade_key"),
				"opening construction chapter does not hand off to realm growth"):
			break
		# A fresh later realm must not point at a stored meta reward while its city
		# is still an empty capital. The reward remains claimable after rank 2.
		var contract_was_ready := bool(Contracts.slots[0].get("ready", false))
		var contract_was_claimed := bool(Contracts.slots[0].get("claimed", false))
		Contracts.slots[0]["ready"] = true
		Contracts.slots[0]["claimed"] = false
		GameState.current_country = 1
		GameState.cities_unlocked = 1
		GameState.prosperity_rank = 0
		GameState.drones = 4
		var rebuilt_realm_objective: Dictionary = main.call("_smart_objective")
		Contracts.slots[0]["ready"] = contract_was_ready
		Contracts.slots[0]["claimed"] = contract_was_claimed
		if not _check(rebuilt_realm_objective.get("tab") == 0
				and rebuilt_realm_objective.get("upgrade_key") == "cargo",
				"stored contract reward interrupts a fresh realm's city chapter"):
			break
		GameState.current_country = 0
		GameState.prosperity_rank = 2
		# Realm growth introduces missions after the first new route. Talents wait
		# for the second realm where influence is actually awarded; shop and legacy
		# remain later realm beats instead of exposing disabled systems.
		GameState.cities_unlocked = 2
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		main.call("_update_contract_visibility")
		main.call("_update_contracts")
		var nav_buttons: Array = main.get("_nav_btns")
		var mission_cards: Array = main.get("_mission_cards")
		if not _check((nav_buttons[5] as Control).visible
				and not (nav_buttons[2] as Control).visible
				and not (nav_buttons[4] as Control).visible
				and not (nav_buttons[3] as Control).visible
				and not bool((mission_cards[0] as Control).get_meta("progression_hidden"))
				and bool((mission_cards[1] as Control).get_meta("progression_hidden"))
				and bool((mission_cards[3] as Control).get_meta("progression_hidden"))
				and bool((main.get("_claim_all_btn") as Control).get_meta("progression_hidden"))
				and not ((main.get("_mission_reroll_btns") as Array)[0] as Control).visible,
				"first settlement unlock exposes multiple advanced systems at once"):
			break
		GameState.cities_unlocked = 3
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		if not _check((nav_buttons[5] as Control).visible
				and not (nav_buttons[2] as Control).visible
				and not (nav_buttons[4] as Control).visible,
				"talents appear before the player can earn influence"):
			break
		GameState.cities_unlocked = 4
		main.call("_update_contract_visibility")
		if not _check(not bool((mission_cards[1] as Control).get_meta("progression_hidden"))
				and bool((mission_cards[2] as Control).get_meta("progression_hidden")),
				"contract board does not grow to a second focused mission with the network"):
			break
		GameState.current_country = 1
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		main.call("_update_contract_visibility")
		if not _check((nav_buttons[2] as Control).visible
				and not (nav_buttons[4] as Control).visible
				and not (nav_buttons[3] as Control).visible
				and not bool((mission_cards[3] as Control).get_meta("progression_hidden"))
				and not bool((main.get("_mission_weekly_section") as Control).get_meta("progression_hidden")),
				"second realm does not introduce funded talents and the weekly board alone"):
			break
		GameState.current_country = 2
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		if not _check((nav_buttons[4] as Control).visible and not (nav_buttons[3] as Control).visible,
				"shop does not wait until the third realm"):
			break
		GameState.current_country = 3
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		if not _check((nav_buttons[3] as Control).visible,
				"legacy does not remain a later realm system"):
			break
		GameState.current_country = 0
		GameState.cities_unlocked = 1
		GameState.drones = 1
		GameState.credits = 0.0

		# The automatic manager used to dominate the fresh fleet panel before the
		# player understood manual construction. Guard both sides of its rank gate.
		GameState.prosperity_rank = 0
		main.call("_process", 0.0)
		if not _check(not (main.get("_auto_mgr_section") as Control).visible
				and not (main.get("_auto_mgr_toggle") as Control).visible,
				"automatic manager visible in the opening chapter"):
			break
		var opening_rows: Dictionary = main.get("_rows")
		if not _check(not bool((opening_rows["cargo"]["card"] as Control).get_meta("progression_hidden"))
				and bool((opening_rows["speed"]["card"] as Control).get_meta("progression_hidden"))
				and bool((opening_rows["value"]["card"] as Control).get_meta("progression_hidden"))
				and bool((opening_rows["routes"]["card"] as Control).get_meta("progression_hidden")),
				"opening fleet panel exposes more than the cargo path"):
			break
		if not _check("/s" in str((opening_rows["cargo"]["detail"] as Label).text),
				"visible construction card does not preview its income gain"):
			break
		if not _check("/s" in str((main.get("_city_detail") as Label).text),
				"next settlement does not preview its network income gain"):
			break
		var city_income_labels: Dictionary = main.get("_city_income_labels")
		if not _check(not city_income_labels.is_empty()
				and "/s" in str((city_income_labels.values()[0] as Label).text),
				"active settlement list does not show live route production"):
			break
		GameState.prosperity_rank = 1
		main.call("_process", 0.0)
		if not _check(not bool((opening_rows["speed"]["card"] as Control).get_meta("progression_hidden"))
				and not bool((opening_rows["value"]["card"] as Control).get_meta("progression_hidden"))
				and bool((opening_rows["routes"]["card"] as Control).get_meta("progression_hidden")),
				"city rank 1 construction paths are not staged correctly"):
			break
		await get_tree().process_frame
		if not _check(fleet_pager.visible and fleet_pager.modulate.a >= 0.99
				and fleet_page.anchor_bottom == 0.0
				and fleet_page.offset_bottom <= main.size.y - REF_NAV_HEIGHT,
				"multi-page construction dashboard is not compact or its pager is delayed"):
			break
		GameState.prosperity_rank = 2
		main.call("_process", 0.0)
		if not _check(not bool((opening_rows["routes"]["card"] as Control).get_meta("progression_hidden"))
				and not bool((main.get("_auto_mgr_section") as Control).get_meta("progression_hidden", false))
				and not (main.get("_auto_mgr_section") as Control).visible
				and not (main.get("_auto_mgr_toggle") as Control).visible,
				"route network and automatic manager did not unlock at city rank 2"):
			break
		main.call("_show_control_page", fleet_page, main.get("_auto_mgr_toggle") as Control)
		if not _check((main.get("_auto_mgr_section") as Control).visible
				and (main.get("_auto_mgr_toggle") as Control).visible,
				"automatic manager cannot be reached on its earned management page"):
			break
		GameState.prosperity_rank = 0
		GameState.pending_offline = 12.0
		GameState.pending_offline_seconds = 14.0
		if not _check(not bool(main.call("_should_show_offline_popup")),
				"brief absence still triggers the full-screen offline popup"):
			break
		GameState.pending_offline_seconds = 61.0
		if not _check(bool(main.call("_should_show_offline_popup")),
				"meaningful offline session no longer receives its reward popup"):
			break
		GameState.pending_offline = 0.0
		GameState.pending_offline_seconds = 0.0

		# A manual purchase must communicate its exact economic consequence without
		# adding a permanent widget to the already compact landscape HUD.
		var feedback_before: float = GameState.income_per_sec()
		GameState.drones += 1
		main.call("_show_income_gain", feedback_before, main.get("_focus_btn") as Control)
		await get_tree().process_frame
		var feedback_prefix := tr("Renda +%s/s").split("%s")[0]
		var feedback_found := false
		for label_node in main.find_children("", "Label", true, false):
			if (label_node as Label).text.begins_with(feedback_prefix):
				feedback_found = true
				break
		GameState.drones -= 1
		if not _check(feedback_found, "manual purchase income feedback missing"):
			break

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
		# The first earned shop chapter is one calm, self-contained page: promise,
		# starter offer, and its nested restore action. Later IAPs, gem utilities,
		# cosmetics, and the duplicate daily card must not inflate it to nine pages.
		Prestige.count = 0; GameState.current_country = 2
		main.set("_nav_stage", -1)
		main.call("_refresh_progressive_nav")
		main.call("_switch_tab", 4)
		await get_tree().process_frame
		await get_tree().process_frame
		var shop_page := (main.get("_pages") as Array)[4] as ScrollContainer
		var shop_items: Array = main.call("_available_page_items", shop_page)
		var shop_pager := shop_page.get_meta("page_pager") as Control
		var compact_panel := main.get("_bottom_bg") as Control
		var visible_shop_bottom := shop_page.global_position.y
		for shop_item: Control in shop_items:
			if shop_item.is_visible_in_tree():
				visible_shop_bottom = maxf(visible_shop_bottom, shop_item.get_global_rect().end.y)
		if not _check(shop_items.size() == 3 and not shop_pager.visible,
				"first shop chapter is still an overloaded multi-page catalogue"):
			break
		if not _check(compact_panel.get_global_rect().end.y <= visible_shop_bottom + 18.0
				and compact_panel.get_global_rect().end.y < main.size.y - REF_NAV_HEIGHT - 60.0,
				"small shop leaves a large empty panel over the fantasy city"):
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
				and absf(hud.position.x + hud.size.x - (canvas.x - REF_GUTTER)) <= 1.0
				and hud.position.y + hud.size.y <= REF_PANEL_TOP - 4.0,
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
		var reward_cards := main.find_children("", "PanelContainer", true, false).filter(
			func(node: Node): return bool(node.get_meta("expansion_reward_card", false)))
		var power_labels := main.find_children("", "Label", true, false).filter(
			func(node: Node): return bool(node.get_meta("expansion_power_label", false)))
		if not _check(reward_cards.size() == 1 and power_labels.size() == 1
				and "×" in str((power_labels[0] as Label).text)
				and "→" in str((power_labels[0] as Label).text),
				"realm expansion does not preview its permanent power gain"):
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
