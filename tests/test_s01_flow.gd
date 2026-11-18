extends SceneTree
## Smoke test for s01: speech lines -> button -> desk scene.
## godot --headless --path . -s res://tests/test_s01_flow.gd
## Optional: pass "--shots" after "--" (non-headless) to save screenshots to art/previews/.

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
	var hud: Node = root.get_node("Hud")
	if hud._log_box.get_child_count() < 2:
		push_error("FAIL history has %d entries" % hud._log_box.get_child_count()); ok = false
	if hud._objective.is_empty():
		push_error("FAIL no objective"); ok = false
	hud.open_history()
	await _wait(0.3)
	await _shot("7_history")
	hud.close_history()
	hud._show_task(5.0)
	await _wait(0.2)
	await _shot("8_task")
	if not button.visible:
		push_error("FAIL button not visible"); ok = false
	await _shot("3_button")
	button.pressed.emit()
	await _wait(2.0)
	if current_scene == null or current_scene.name != "Desk":
		push_error("FAIL not on desk: %s" % [current_scene]); ok = false
	await _wait(0.6)
	await _shot("4_desk")
	var desk: Node = current_scene
	var casefile: DeskDocument = desk.get_node("Documents/Casefile")
	casefile._animate(true)
	await _wait(0.5)
	await _shot("5_desk_hover")
	casefile._animate(false)
	casefile.clicked.emit("casefile")
	await _wait(0.4)
	var view: DocumentView = desk.get_node("DocumentView")
	if not view.is_open():
		push_error("FAIL close-up not open"); ok = false
	await _wait(1.0)
	await _shot("6_closeup")
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)  # Esc must not close before the thoughts are read
	await _wait(0.3)
	if not view.is_open():
		push_error("FAIL document closed before reading the thoughts"); ok = false
	if view._page != 0:
		push_error("FAIL Esc turned a dialogue page"); ok = false
	view._step()  # player presses Space -> next page
	await _wait(0.3)
	if view._pages.size() < 2:
		push_error("FAIL long reaction not paged: %d" % view._pages.size()); ok = false
	await _shot("6b_reaction")
	view.close()
	await _wait(0.5)
	if view.is_open() or not casefile.interactive:
		push_error("FAIL close-up did not close"); ok = false
	# remaining documents -> phone rings -> answer
	for id: String in ["papers", "note"]:
		desk.get_node("Documents/" + id.capitalize()).clicked.emit(id)
		await _wait(1.6)
		if id == "papers":
			await _shot("9_placeholder_doc")
		view.close()
		await _wait(0.5)
	await _wait(0.6)
	var answer: Button = desk.get_node("UI/Root/AnswerButton")
	var audio: Node = root.get_node("Audio")
	if answer.visible or audio._loop.playing:
		push_error("FAIL phone rang before the report"); ok = false
	# computer: database, cases, report with a choice
	var term: Terminal = desk.get_node("Terminal")
	if not term.report_unlocked:
		push_error("FAIL report not unlocked after reading all documents"); ok = false
	desk._open_terminal()
	await _wait(2.2)
	await _shot("11_terminal_menu")
	term._show_result("Коул")
	await _wait(0.3)
	await _shot("12_terminal_search")
	term._show_report_entry()
	await _wait(0.3)
	await _shot("13_terminal_report")
	term._choices = {"cause": "b", "wall": "b", "verdict": "b"}
	term._file_report()
	await _wait(0.3)
	term.close()
	await _wait(0.5)
	await _shot("14_report_thought")
	if root.get_node("GameState").get_flag("report_cole_closed", true) != false:
		push_error("FAIL report choice not stored"); ok = false
	await _wait(4.0)
	if current_scene == null or current_scene.name != "Walk":
		push_error("FAIL report did not lead to the walk hall: %s" % [current_scene]); ok = false
	print("S01 FLOW: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
	return
	await _shot("10_phone")
	answer.pressed.emit()
	await _wait(0.5)
	if audio._loop.playing:
		push_error("FAIL ring did not stop"); ok = false
	print("S01 FLOW: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
