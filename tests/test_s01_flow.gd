extends SceneTree
## Smoke test for s01: speech lines -> button -> desk scene.
## godot --headless --path . -s res://tests/test_s01_flow.gd
## Optional: pass "--shots" after "--" (non-headless) to save screenshots to art/previews/.

var _shots: bool = "--shots" in OS.get_cmdline_user_args()


func _init() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("res://art/previews/s01_" + name + ".png")


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _run() -> void:
	var ok: bool = true
	change_scene_to_file("res://scenes/s01/exposition.tscn")
	await _wait(1.6)
	var expo: Node = current_scene
	var speaker: Label = expo.get_node("UI/Root/Speech/Speaker")
	if speaker.text != "Алексей":
		push_error("FAIL speaker label: '%s'" % speaker.text); ok = false
	await _wait(1.0)
	await _shot("1_speech")
	expo.get_node("UI/Root/Markers/Badge").activated.emit("badge")
	await _wait(0.5)
	await _shot("2_marker_thought")
	for i in 10:
		expo._advance()
		await _wait(0.1)
	var button: Button = expo.get_node("UI/Root/StudyButton")
	await _wait(0.5)
	if not button.visible:
		push_error("FAIL button not visible"); ok = false
	await _shot("3_button")
	button.pressed.emit()
	await _wait(2.0)
	if current_scene == null or current_scene.name != "Desk":
		push_error("FAIL not on desk: %s" % [current_scene]); ok = false
	await _wait(0.6)
	await _shot("4_desk")
	print("S01 FLOW: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
