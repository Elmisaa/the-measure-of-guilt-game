extends SceneTree
## Title screen -> settings (slider, back) -> new game (intro); pause in the hall: Esc pauses, Esc resumes.
## godot --path . -s res://tests/test_menu.gd [-- --shots]

const SAFETY_TIMEOUT: float = 60.0
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
	root.get_texture().get_image().save_png("res://art/previews/menu_" + name + ".png")


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


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
	var st: Node = root.get_node("Settings")
	var music0: float = st.music
	change_scene_to_file("res://scenes/menu/title.tscn")
	await _wait(1.0)
	var t: Node = current_scene
	await _shot("1_title")
	var focused: Control = root.gui_get_focus_owner()
	if focused == null or not (focused as Button).text.contains("Новая игра"):
		push_error("FAIL first item not focused"); ok = false
	await _key(KEY_S)
	await _wait(0.1)
	focused = root.gui_get_focus_owner()
	if focused == null or not (focused as Button).text.contains("Настройки"):
		push_error("FAIL S did not move the focus"); ok = false
	await _key(KEY_ENTER)
	await _wait(0.3)
	if not t._settings.is_open():
		push_error("FAIL settings did not open"); ok = false
	await _key(KEY_DOWN)  # -> music
	await _key(KEY_LEFT)
	await _wait(0.1)
	if st.music >= music0 and music0 > 0.0:
		push_error("FAIL music slider did not change: %.2f" % st.music); ok = false
	await _shot("2_settings")
	st.music = music0
	st.apply()
	st.save_settings()
	await _key(KEY_ESCAPE)
	await _wait(0.2)
	if t._settings.is_open():
		push_error("FAIL Esc did not close settings"); ok = false
	t._new_game()
	await _wait(1.0)
	if current_scene == null or current_scene.name != "Intro":
		push_error("FAIL new game did not start the intro: %s" % [current_scene]); ok = false
	# pause in the hall
	change_scene_to_file("res://scenes/s01/walk.tscn")
	await _wait(1.2)
	var hud: Node = root.get_node("Hud")
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	if not paused or not hud.is_paused():
		push_error("FAIL Esc did not pause"); ok = false
	await _shot("3_pause")
	await _key(KEY_ESCAPE)
	await _wait(0.3)
	if paused:
		push_error("FAIL Esc did not resume"); ok = false
	print("MENU: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)
