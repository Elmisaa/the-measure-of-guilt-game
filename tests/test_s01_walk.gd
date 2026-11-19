extends SceneTree
## Walk hall: move right, camera follows within bounds, run (own sheet, spends stamina, recovers),
## inventory (I) blocks movement, radio stations, coffee twice (pour at the machine, drink from the
## inventory) -> pack -> phone rings, answer at the desk -> call scene.  godot --headless --path . -s res://tests/test_s01_walk.gd

const SAFETY_TIMEOUT: float = 180.0  ## never leave a window hanging
var _shots: bool = "--shots" in OS.get_cmdline_user_args()


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))


func _shot(name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/s01_walk_" + name + ".png")


func hud0() -> Node:
	return root.get_node("Hud")


func _key(code: Key) -> void:
	var e: InputEventKey = InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	var u: InputEventKey = e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)
	await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _walk_to(w: Node, x: float) -> void:
	var p: Node2D = w.get_node("World/Player")
	var act: String = "move_right" if x > p.position.x else "move_left"
	Input.action_press(act)
	var guard: int = 0
	while absf(p.position.x - x) > 8.0 and guard < 2000:
		await process_frame
		if (act == "move_right" and p.position.x >= x) or (act == "move_left" and p.position.x <= x):
			break
		guard += 1
		await _wait(0.02)
	Input.action_release(act)


func _run() -> void:
	var ok: bool = true
	change_scene_to_file("res://scenes/s01/walk.tscn")
	await _wait(1.2)
	var w: Node = current_scene
	var cam: Camera2D = w.get_node("World/Camera")
	await _shot("1_start")
	var x0: float = w.get_node("World/Player").position.x
	if not "A / D" in hud0().tutorial_text():
		push_error("FAIL tutorial: walk hint missing: '%s'" % hud0().tutorial_text()); ok = false
	await _walk_to(w, 700.0)
	if w.get_node("World/Player").position.x <= x0 + 100.0:
		push_error("FAIL player did not move"); ok = false
	if cam.position.x < 320.0 or cam.position.x > 2012.0 - 320.0:
		push_error("FAIL camera out of bounds"); ok = false
	await _shot("2_walking")
	if not "Shift" in hud0().tutorial_text():
		push_error("FAIL tutorial: run hint should follow walking: '%s'" % hud0().tutorial_text()); ok = false
	# run (Shift) is faster than walking, uses the run sheet and spends stamina
	var gs: Node = root.get_node("GameState")
	var hud: Node = root.get_node("Hud")
	var pl0: Node2D = w.get_node("World/Player")
	var p0: float = pl0.position.x
	Input.action_press("run"); Input.action_press("move_right")
	await _wait(0.5)
	var run_tex: bool = pl0._sprite.texture == pl0.run_sheet
	await _shot("2b_run")
	Input.action_release("move_right"); Input.action_release("run")
	if pl0.position.x - p0 < 120.0:
		push_error("FAIL run is not faster"); ok = false
	if not run_tex:
		push_error("FAIL run sheet not used while running"); ok = false
	if "Shift" in hud.tutorial_text() or str(gs.get_flag("tutorial")) != "interact":
		push_error("FAIL tutorial: run hint should be gone after running: %s" % gs.get_flag("tutorial")); ok = false
	if gs.stamina > 0.99:
		push_error("FAIL stamina not spent: %.2f" % gs.stamina); ok = false
	await _shot("2c_stamina")
	gs.stamina = 0.05
	await _wait(1.5)
	if gs.stamina <= 0.05:
		push_error("FAIL stamina does not recover"); ok = false
	# Space: no jump any more; it must not use the spot he stands at
	gs.stamina = 1.0
	var st0: String = w._state
	var sp: InputEventKey = InputEventKey.new()
	sp.physical_keycode = KEY_SPACE
	sp.keycode = KEY_SPACE
	sp.pressed = true
	Input.parse_input_event(sp)
	await _wait(0.1)
	var sp_up: InputEventKey = sp.duplicate()
	sp_up.pressed = false
	Input.parse_input_event(sp_up)
	await _wait(0.3)
	if pl0._sprite.position.y != 0.0 or w._state != st0:
		push_error("FAIL space should do nothing in the hall"); ok = false
	# inventory: I opens it, Alexei cannot walk while it is open
	hud.toggle_inventory()
	await _wait(0.3)
	var slot: Control = hud._inventory._grid.get_child(1)
	hud._inventory._show_tip("cup_empty", hud._inventory._grid.get_child(0))
	await _shot("2d_inventory")
	hud._inventory._tip.visible = false
	hud._inventory._open_menu("photo", hud._inventory._grid.get_child(4))
	await _shot("2d2_menu")
	hud._inventory._close_menu()
	# keyboard: arrows/WASD move the selection, Enter opens the menu, down + Enter picks an action
	await _key(KEY_D)
	await _key(KEY_RIGHT)
	if hud._inventory._sel != 2:
		push_error("FAIL inventory keys: sel=%d" % hud._inventory._sel); ok = false
	await _key(KEY_D)
	await _key(KEY_D)  # -> the cup: two actions
	await _key(KEY_ENTER)
	if not hud._inventory._menu.visible:
		push_error("FAIL Enter did not open the item menu"); ok = false
	await _key(KEY_S)
	if hud._inventory._menu_sel != 1:
		push_error("FAIL menu keys: %d" % hud._inventory._menu_sel); ok = false
	await _shot("2d3_keys")
	await _key(KEY_ESCAPE)
	if hud._inventory._menu.visible or not hud.is_inventory_open():
		push_error("FAIL Esc should close only the menu"); ok = false
	var px: float = pl0.position.x
	Input.action_press("move_left")
	await _wait(0.4)
	Input.action_release("move_left")
	if absf(pl0.position.x - px) > 0.5 or not hud.is_blocking():
		push_error("FAIL inventory should block walking"); ok = false
	if not gs.has_item("cup_old") or not gs.has_item("photo") or not gs.has_item("pistol"):
		push_error("FAIL start items missing: %s" % [gs.items]); ok = false
	hud._inventory.choose("photo", "look")
	await _wait(1.6)
	if not hud.is_closeup_open():
		push_error("FAIL photo close-up did not open"); ok = false
	await _shot("2e_photo")
	hud._closeup.close()
	await _wait(0.5)
	if not hud.is_inventory_open():
		push_error("FAIL inventory should stay open after looking"); ok = false
	hud.toggle_inventory()
	# close-ups and drawers in the hall
	w._interact("alexei_board")
	await _wait(1.6)
	if not hud.is_closeup_open():
		push_error("FAIL board close-up"); ok = false
	await _shot("2g_board")
	hud._closeup.close()
	await _wait(0.5)
	w._interact("alexei_locker")
	await _wait(0.3)
	if not hud.is_container_open():
		push_error("FAIL locker did not open"); ok = false
	await _shot("2h_locker")
	hud._container._take_all.pressed.emit()  # before the coffee: look, but don't take yet
	await _wait(0.3)
	if gs.has_item("keys"):
		push_error("FAIL locker things taken before the coffee"); ok = false
	hud._container.close()
	# old coffee: wash the cup in the restroom (new door), then the machine
	await _walk_to(w, 1820.0)
	await _wait(0.2)
	if w._near != "restroom":
		push_error("FAIL not near restroom door: %s" % w._near); ok = false
	await _shot("2i_door")
	w._interact("restroom")
	await _wait(1.8)
	var rr: Node = current_scene
	if rr == null or rr.name != "Restroom":
		push_error("FAIL not in restroom: %s" % [rr]); ok = false
	else:
		await _shot("2j_restroom")
		rr._interact("stall2")
		await _wait(0.3)
		rr._interact("sink")  # empty hands: only a hint
		await _wait(0.3)
		if not gs.has_item("cup_old"):
			push_error("FAIL sink without the cup in hand should not wash"); ok = false
		await _walk_to(rr, 205.0)
		await _wait(0.2)
		if rr._near != "sink":
			push_error("FAIL sink should win over the mirror: %s" % rr._near); ok = false
		hud.toggle_inventory()
		await _wait(0.2)
		hud._inventory.choose("cup_old", "hold")
		await _wait(0.2)
		if hud.held_item != "cup_old" or hud.is_inventory_open():
			push_error("FAIL cup not in hand"); ok = false
		await _shot("2j2_cup_in_hand")
		rr._interact("sink")
		await _wait(2.4)
		if hud.held_item != "":
			push_error("FAIL hand not emptied after washing"); ok = false
		await _shot("2k_washed")
		if not gs.has_item("cup_empty"):
			push_error("FAIL cup not washed: %s" % [gs.items]); ok = false
		rr._interact("door")
		await _wait(1.8)
	w = current_scene
	if w == null or w.name != "Walk" or w._state != "coffee1":
		push_error("FAIL back in hall with coffee1: %s" % [w._state if w else "none"]); ok = false
	pl0 = w.get_node("World/Player")
	if absf(pl0.position.x - 1820.0) > 40.0:
		push_error("FAIL should stand at the restroom door: %.0f" % pl0.position.x); ok = false
	# walk to the coffee machine and use it
	await _walk_to(w, 1350.0)
	await _wait(0.2)
	if w._near != "coffee":
		push_error("FAIL not near coffee: %s" % w._near); ok = false
	await _shot("3_coffee")
	w._interact("coffee")  # empty hands: hint only
	await _wait(0.3)
	if w._state != "coffee1":
		push_error("FAIL coffee without cup in hand"); ok = false
	hud.set_held("cup_empty")
	w._interact("coffee")
	await _wait(2.0)
	if w._state != "drink1" or not gs.has_item("cup_full"):
		push_error("FAIL cup not filled: %s %s" % [w._state, gs.items]); ok = false
	gs.stamina = 0.2
	hud.use_item("cup_full", "drink")
	await _wait(0.3)
	if w._state != "coffee2" or not gs.has_item("cup_empty") or gs.stamina < 0.99:
		push_error("FAIL drinking: %s %s stamina %.2f" % [w._state, gs.items, gs.stamina]); ok = false
	hud.set_held("cup_empty")
	w._interact("coffee")
	await _wait(2.0)
	hud.use_item("cup_full", "drink")
	await _wait(0.3)
	# radio on Kowalski's desk: stations then off
	await _walk_to(w, 1700.0)
	await _wait(0.2)
	if w._near != "radio":
		push_error("FAIL not near radio: %s" % w._near); ok = false
	w._interact("radio")
	await _wait(1.0)
	var radio: Node = w.get_node("World/Radio")
	if not radio.is_on() or not radio._player.playing:
		push_error("FAIL radio not playing"); ok = false
	await _shot("3b_radio")
	w._interact("radio"); w._interact("radio")
	await _wait(6.0)
	if radio.station() != 2 or not radio._player.playing:
		push_error("FAIL strange station: %d" % radio.station()); ok = false
	# Kowalski: notices, wanted copies, his drawer
	w._interact("notice_order")
	await _wait(1.6)
	await _shot("3d_order")
	hud._closeup.close()
	await _wait(0.5)
	w._interact("notice_vacancy")
	await _wait(1.6)
	await _shot("3e_vacancy")
	hud._closeup.close()
	await _wait(0.5)
	w._interact("wanted")
	await _wait(0.3)
	hud._container._take_all.pressed.emit()
	await _wait(0.4)
	await _shot("3f_wanted_taken")
	hud._container.close()
	if not gs.has_item("wanted_b"):
		push_error("FAIL wanted copies not taken"); ok = false
	hud.use_item("wanted_a", "look")
	await _wait(1.6)
	await _shot("3g_wanted_a")
	hud._closeup.close()
	await _wait(0.5)
	w._interact("kowalski_drawer")
	await _wait(0.3)
	hud._container.choose("kowalski_notes", "take")
	await _wait(0.3)
	hud._container.close()
	hud.use_item("kowalski_notes", "look")
	await _wait(1.6)
	await _shot("3h_kowalski_notes")
	hud._closeup.close()
	await _wait(0.5)
	await _walk_to(w, 1540.0)
	await _shot("3c_radio_view")
	# Sarah: photo, stickers, drawer (look only)
	await _walk_to(w, 1120.0)
	w._interact("sarah_stickers")
	await _wait(1.6)
	await _shot("3i_stickers")
	hud._closeup.close()
	await _wait(0.5)
	w._interact("sarah_photo")
	await _wait(1.6)
	await _shot("3j_sarah_photo")
	hud._closeup.close()
	await _wait(0.5)
	w._interact("sarah_drawer")
	await _wait(0.3)
	if hud._container._take_all.visible:
		push_error("FAIL Sarah's drawer should be look-only"); ok = false
	await _shot("3k_sarah_drawer")
	hud._container.choose("drawing", "look")
	await _wait(1.6)
	await _shot("3l_drawing")
	hud._closeup.close()
	await _wait(0.5)
	if not hud.is_container_open():
		push_error("FAIL drawer should stay open after looking"); ok = false
	hud._container.close()
	if w._state != "home" or root.get_node("Audio")._loop.playing:
		push_error("FAIL after second coffee should be free 'home' state, no ring: %s" % w._state); ok = false
	# depth: step toward the wall
	Input.action_press("move_up")
	await _wait(0.8)
	Input.action_release("move_up")
	var pl: Node2D = w.get_node("World/Player")
	if pl.depth_row() == 0:
		push_error("FAIL depth did not switch to a smaller row"); ok = false
	await _shot("4_depth")
	# home: things from the locker first, then the desk
	await _walk_to(w, 420.0)
	w._interact("desk")
	await _wait(0.3)
	if w._state != "home":
		push_error("FAIL desk should wait for the locker things: %s" % w._state); ok = false
	w._interact("alexei_locker")
	await _wait(0.3)
	hud._container._take_all.pressed.emit()
	await _wait(0.5)
	await _shot("4b_things_taken")
	for it: String in ["notebook", "cassette"]:
		hud.use_item(it, "look")
		await _wait(1.6)
		if not hud.is_closeup_open():
			push_error("FAIL close-up for " + it); ok = false
		await _shot("4c_" + it)
		hud._closeup.close()
		await _wait(0.5)
	hud._container.close()
	if w._state != "back_to_desk":
		push_error("FAIL locker things -> back_to_desk: %s" % w._state); ok = false
	await _wait(0.2)
	if w._near != "desk":
		push_error("FAIL not near desk (pack): %s" % w._near); ok = false
	w._interact("desk")
	await _wait(3.0)
	if w._state != "phone" or not root.get_node("Audio")._loop.playing:
		push_error("FAIL phone not ringing after packing: %s" % w._state); ok = false
	if radio.is_on():
		push_error("FAIL radio should go off when packing"); ok = false
	await _shot("5_phone")
	if w._near != "desk":
		push_error("FAIL not near desk: %s x=%.0f busy=%s frozen=%s" % [w._near, w.get_node("World/Player").position.x, w._busy, w.get_node("World/Player").frozen]); ok = false
	w._interact("desk")
	await _wait(2.5)
	if current_scene == null or current_scene.name != "Call":
		push_error("FAIL not in call scene"); ok = false
	print("S01 WALK: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
