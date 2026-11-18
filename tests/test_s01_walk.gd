extends SceneTree
## Walk hall: move right, camera follows within bounds, coffee twice -> phone rings,
## answer at the desk -> call scene.  godot --headless --path . -s res://tests/test_s01_walk.gd

const SAFETY_TIMEOUT: float = 90.0  ## never leave a window hanging
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
	await _walk_to(w, 700.0)
	if w.get_node("World/Player").position.x <= x0 + 100.0:
		push_error("FAIL player did not move"); ok = false
	if cam.position.x < 320.0 or cam.position.x > 2012.0 - 320.0:
		push_error("FAIL camera out of bounds"); ok = false
	await _shot("2_walking")
	# walk to the coffee machine and use it
	await _walk_to(w, 1350.0)
	await _wait(0.2)
	if w._near != "coffee":
		push_error("FAIL not near coffee: %s" % w._near); ok = false
	await _shot("3_coffee")
	w._interact("coffee")
	await _wait(6.0)
	if w._state != "coffee2":
		push_error("FAIL state after first coffee: %s" % w._state); ok = false
	w._interact("coffee")
	await _wait(3.4)
	if w._state != "phone" or not root.get_node("Audio")._loop.playing:
		push_error("FAIL phone not ringing: %s" % w._state); ok = false
	await _shot("4_phone")
	await _walk_to(w, 420.0)
	await _wait(0.2)
	if w._near != "desk":
		push_error("FAIL not near desk: %s x=%.0f busy=%s frozen=%s" % [w._near, w.get_node("World/Player").position.x, w._busy, w.get_node("World/Player").frozen]); ok = false
	w._interact("desk")
	await _wait(2.5)
	if current_scene == null or current_scene.name != "Call":
		push_error("FAIL not in call scene"); ok = false
	print("S01 WALK: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
