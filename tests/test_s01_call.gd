extends SceneTree
## Phone call: all lines -> knock -> hang-up (dial tone) -> thoughts -> leave button -> fade.
## godot --headless --path . -s res://tests/test_s01_call.gd  (add "-- --shots" without --headless)

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
	root.get_texture().get_image().save_png("res://art/previews/s01_call_" + name + ".png")


func c_after(c: Node) -> bool:
	return c._after_lines


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


## One player press: finish typing, or next page, or next line.
func _click() -> void:
	var c: Node = current_scene
	while c._busy and not c._after_lines:
		await create_timer(0.1).timeout
	if c._typing and c._typing.is_running():
		c._typing.kill()
		c._set_ratio(c._typing_node, 1.0)
	elif c._page < c._pages.size() - 1:
		c._page += 1
		c._show_page()
	else:
		c._next()


func _run() -> void:
	var ok: bool = true
	change_scene_to_file("res://scenes/s01/call.tscn")
	await _wait(1.6)
	var call: Node = current_scene
	var audio: Node = root.get_node("Audio")
	await _wait(1.5)
	await _shot("1_fyodor")
	var guard: int = 0
	while call._index < 9 and guard < 30:  # up to the knock event
		await _click()
		guard += 1
		await _wait(0.35)
		if call._index == 6:
			await _wait(1.0)
			await _shot("2_tension")
	await _wait(0.8)
	await _shot("3_knock")
	await _wait(2.0)
	if call._index != 10:
		push_error("FAIL after knock index=%d" % call._index); ok = false
	await _shot("4_scream")
	await _click()  # -> hangup event
	await _wait(3.6)
	if not audio._loop.playing:
		push_error("FAIL no dial tone"); ok = false
	await _shot("5_thought")
	if call._saturation < 0.95:
		push_error("FAIL colour did not return after the call: %.2f" % call._saturation); ok = false
	var g2: int = 0
	while not c_after(call) and g2 < 20:
		var btn0: Button = call.get_node("UI/Root/LeaveButton")
		if btn0.visible:
			push_error("FAIL button shown before thoughts ended"); ok = false
		await _click()
		await _wait(0.3)
		g2 += 1
	await _wait(0.6)
	var btn: Button = call.get_node("UI/Root/LeaveButton")
	if not btn.visible:
		push_error("FAIL leave button not shown"); ok = false
	await _shot("6_button")
	btn.pressed.emit()
	await _wait(2.0)
	await _shot("7_leave_thought")
	await _wait(6.0)
	if not call.get_node("Fade/End").visible:
		push_error("FAIL end not reached"); ok = false
	if audio._loop.playing:
		push_error("FAIL dial tone still playing"); ok = false
	print("S01 CALL: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
