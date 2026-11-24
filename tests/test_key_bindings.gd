extends SceneTree


func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void: _fail("timeout"))
	_run.call_deferred()


func _run() -> void:
	var settings: Node = root.get_node("Settings")
	settings.reset_bindings()
	change_scene_to_file("res://scenes/menu/title.tscn")
	await scene_changed
	var panel: Control = current_scene.get("_settings")
	panel.open()
	await process_frame
	await process_frame
	for row: Control in panel.get("_rows"):
		if row is Button and row.text.contains("Клавиши"):
			row.pressed.emit()
			break
	var bindings: Control = panel.get("_bindings")
	if not bindings.visible:
		_fail("keyboard settings are not accessible from the settings menu")
		return
	var buttons: Dictionary = bindings.get("_buttons")
	buttons["pickup_dropped"].pressed.emit()
	bindings.handle_input(_key(KEY_I))
	if settings.key_label("pickup_dropped") != "G":
		_fail("a conflicting key should be rejected")
		return
	bindings.handle_input(_key(KEY_J))
	if settings.key_label("pickup_dropped") != "J" or not _key(KEY_J).is_action_pressed("pickup_dropped") or _key(KEY_G).is_action_pressed("pickup_dropped"):
		_fail("only the new key should trigger pickup after rebinding")
		return
	var fresh: Node = settings.get_script().new()
	root.add_child(fresh)
	if fresh.key_label("pickup_dropped") != "J":
		_fail("restarting settings should restore the saved key")
		return
	fresh.queue_free()

	settings.reset_bindings()
	if not _key(KEY_G).is_action_pressed("pickup_dropped") or _key(KEY_J).is_action_pressed("pickup_dropped"):
		_fail("reset should restore the default key")
		return
	bindings.handle_input(_key(KEY_ESCAPE))
	if bindings.visible or not panel.is_open():
		_fail("back should return to settings")
		return
	print("KEY BINDINGS: OK")
	quit()


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = code
	event.keycode = code
	return event


func _fail(message: String) -> void:
	push_error("KEY BINDINGS: " + message)
	quit(1)