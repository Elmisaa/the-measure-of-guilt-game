extends SceneTree

const SAFETY_TIMEOUT: float = 90.0
var _shots: bool = "--shots" in OS.get_cmdline_user_args()


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT, true, false, true).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))


func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout


func _shot(name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/saves_" + name + ".png")


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


func _run() -> void:
	var ok: bool = true
	var sg: Node = root.get_node("SaveGame")
	var gs: Node = root.get_node("GameState")
	var hud: Node = root.get_node("Hud")
	sg.wipe_test_saves()
	gs.new_game()
	hud.reset_journal()
	gs.set_flag("tutorial", "done")
	root.get_node("SceneRouter").go_to("res://scenes/s01/walk.tscn")
	await _wait(1.5)
	var w: Node = current_scene
	if not hud.controls_hint_visible():
		push_error("FAIL controls hint not shown on entering the hall"); ok = false
	await _shot("1_hint")
	if sg.info("auto").is_empty():
		push_error("FAIL no autosave on entering the hall"); ok = false
	(w.get_node("World/Player") as Node2D).position.x = 900.0
	await _wait(0.2)
	gs.add_item("keys")
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	if not hud.is_paused():
		push_error("FAIL Esc did not pause"); ok = false
	await _shot("2_pause")
	hud._open_tasks()
	await _wait(0.2)
	await _shot("3_tasks")
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	if hud._info.visible:
		push_error("FAIL Esc did not close tasks"); ok = false
	hud._open_controls()
	await _wait(0.2)
	await _shot("4_controls")
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	hud.open_history()
	await _wait(0.2)
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	if hud._history_open or not hud.is_paused():
		push_error("FAIL history from pause did not return to pause"); ok = false
	if not sg.save("1"):
		push_error("FAIL save to slot 1"); ok = false
	if not sg.save("1") or FileAccess.file_exists(sg.DIR + "1.json.tmp"):
		push_error("FAIL replacing an existing save"); ok = false
	hud._saves.open("load")
	await _wait(0.2)
	await _shot("5_load")
	hud._saves.close()
	hud.close_pause()
	var objective: String = hud.get_objective()
	gs.remove_item("keys")
	(w.get_node("World/Player") as Node2D).position.x = 300.0
	await _key(KEY_ESCAPE)
	var loaded_from_pause: bool = await sg.load_slot("1")
	if not loaded_from_pause or paused:
		push_error("FAIL loading from pause must reopen the game"); ok = false
	var w2: Node = current_scene
	if w2 == null or w2.name != "Walk" or w2 == w:
		push_error("FAIL load did not reopen the hall: %s" % [w2]); ok = false
	else:
		var x: float = (w2.get_node("World/Player") as Node2D).position.x
		if absf(x - 900.0) > 2.0:
			push_error("FAIL loaded x %.1f, expected 900" % x); ok = false
	if not gs.has_item("keys"):
		push_error("FAIL loaded inventory lost the keys"); ok = false
	if hud.get_objective() != objective:
		push_error("FAIL objective after load: '%s' vs '%s'" % [hud.get_objective(), objective]); ok = false
	change_scene_to_file("res://scenes/menu/title.tscn")
	await _wait(0.8)
	var f: Control = root.gui_get_focus_owner()
	if f == null or not (f as Button).text.contains("Продолжить"):
		push_error("FAIL title does not offer Продолжить"); ok = false
	await _shot("6_title")
	var invalid_save: Dictionary = sg.info("1")
	invalid_save["time"] = float(invalid_save["time"]) + 100.0
	invalid_save["scene"] = "res://scenes/missing_chapter.tscn"
	_write_slot(sg.DIR + "auto.json", invalid_save)
	if sg.latest() != "1":
		push_error("FAIL latest should skip an unavailable scene"); ok = false

	gs.set_flag("load_rejected_probe", true)
	root.get_node("SceneRouter").go_to("res://scenes/menu/title.tscn", 0.1)
	var loaded_while_busy: bool = await sg.load_slot("1")
	if loaded_while_busy or not gs.get_flag("load_rejected_probe", false):
		push_error("FAIL a busy transition must reject loading without changing game state"); ok = false
	await _wait(1.3)

	invalid_save = sg.info("1")
	var title: Node = current_scene
	var panel: SaveSlotsPanel = title.get("_saves")
	await panel.open("load")
	var slot_button: Button = panel.get("_buttons")[1]
	invalid_save["game"]["flags"] = []
	_write_slot(sg.DIR + "1.json", invalid_save)
	await panel._on_slot("1", slot_button)
	if not panel.is_open() or title.get("_starting") or not panel.get("_status").text.begins_with("Не удалось"):
		push_error("FAIL an invalid slot must leave the load panel usable"); ok = false
	panel.close()
	await title.call("_continue")
	if title.get("_starting") or not title.get("_status").visible or not gs.get_flag("load_rejected_probe", false):
		push_error("FAIL an invalid save must leave Continue usable and preserve state"); ok = false
	sg.wipe_test_saves()
	print("SAVES: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _write_slot(path: String, data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
