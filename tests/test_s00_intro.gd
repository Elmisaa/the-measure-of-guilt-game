extends SceneTree
## Intro cutscene: plays to the end and lands in s01 with bars retracted; skip works.
## godot --headless --path . -s res://tests/test_s00_intro.gd   (add "-- --shots" without --headless for screenshots)

var _shots: bool = "--shots" in OS.get_cmdline_user_args()


const SAFETY_TIMEOUT: float = 90.0  ## never leave a window hanging


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))


func _shot(name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/s00_" + name + ".png")


func _press_accept() -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.physical_keycode = KEY_ENTER
	ev.pressed = true
	Input.parse_input_event(ev)
	var up: InputEventKey = ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _scene_name() -> String:
	return current_scene.name if current_scene else ""


func _run() -> void:
	var ok: bool = true
	var letterbox: Node = root.get_node("Letterbox")
	change_scene_to_file("res://scenes/s00/intro.tscn")
	await _wait(3.0)
	var quote: Label = current_scene.get_node("Fade/Quote")
	if quote.modulate.a < 0.9 or quote.text.is_empty():
		push_error("FAIL quote not shown"); ok = false
	await _shot("0_quote")
	_press_accept()
	await _wait(0.6)
	if quote.modulate.a > 0.05:
		push_error("FAIL quote not skipped"); ok = false
	await _wait(2.5)
	if not letterbox.is_shown():
		push_error("FAIL bars not shown"); ok = false
	await _shot("1_window")
	await _wait(5.0)
	await _shot("2_coffee")
	await _wait(1.6)
	await _shot("2b_coffee")
	await _wait(2.0)
	if _scene_name() != "Exposition":
		push_error("FAIL not in exposition: %s" % _scene_name()); ok = false
	await _shot("3_bars_retracting")
	await _wait(1.5)
	if letterbox.is_shown():
		push_error("FAIL bars still shown"); ok = false
	await _shot("4_exposition")
	# skip: first press skips the quote, second the cutscene
	change_scene_to_file("res://scenes/s00/intro.tscn")
	await _wait(1.0)
	_press_accept()
	await _wait(1.5)
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(1.5)
	if _scene_name() != "Exposition":
		push_error("FAIL skip did not go to exposition: %s" % _scene_name()); ok = false
	print("S00 INTRO: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
