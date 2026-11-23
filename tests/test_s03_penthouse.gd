extends SceneTree

const SAFETY_TIMEOUT: float = 60.0
var _shots: bool = "--shots" in OS.get_cmdline_user_args()


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT, true, false, true).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _shot(name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art/previews/s03_penthouse_" + name + ".png")


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
	var gs: Node = root.get_node("GameState")
	gs.new_game()
	gs.set_flag("coat_on", true)
	change_scene_to_file("res://scenes/s03/penthouse.tscn")
	await _wait(0.6)
	var lb: Node = root.get_node("Letterbox")
	if not lb.is_shown():
		push_error("FAIL the cinema bars are not on at the start"); ok = false
	await _shot("0_bars")
	await _wait(2.6)
	if lb.is_shown():
		push_error("FAIL the bars did not slide away"); ok = false
	var p: Node = current_scene
	var pl: Node3D = p.get_node("Player")
	var cam: Camera3D = p.get("_cam")
	if cam == null or not cam.current:
		push_error("FAIL no current side camera"); ok = false
	await _shot("1_corridor")
	pl.position.x = -12.0
	await _wait(0.2)
	var x0: float = pl.position.x
	var c0: float = cam.position.x
	Input.action_press("move_right")
	await _wait(1.5)
	Input.action_release("move_right")
	if pl.position.x <= x0 + 1.0:
		push_error("FAIL Alexei did not walk right: %.2f -> %.2f" % [x0, pl.position.x]); ok = false
	if cam.position.x <= c0 + 0.5:
		push_error("FAIL camera did not follow"); ok = false
	await _shot("2_walking")
	pl.position.x = 3.1
	await _wait(0.3)
	var prompt: Button = p.get("_prompt")
	if not prompt.visible or not "Телескоп" in prompt.text:
		push_error("FAIL no telescope prompt: '%s'" % prompt.text); ok = false
	await _shot("3_telescope_prompt")
	await _key(KEY_E)
	await _wait(0.4)
	var th: ThoughtBox = p.get("_thought")
	if not "Телескоп" in th.get_text() and not "телескоп" in th.get_text().to_lower():
		push_error("FAIL no telescope thought: '%s'" % th.get_text()); ok = false
	await _shot("4_thought")
	pl.position.x = 2.1
	await _wait(0.3)
	if not "Виктор" in prompt.text:
		push_error("FAIL no Viktor prompt: '%s'" % prompt.text); ok = false
	await _shot("6_viktor")
	pl.position.x = 0.0
	await _wait(0.4)
	await _shot("5_room")
	var st: Dictionary = p.call("save_state")
	if absf(float(st["penthouse_x"])) > 0.01 or not (st["penthouse_seen"] as Array).has("telescope"):
		push_error("FAIL save_state: %s" % [st]); ok = false
	print("PENTHOUSE: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
