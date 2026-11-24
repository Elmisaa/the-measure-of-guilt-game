extends SceneTree

const SCENE: String = "res://scenes/s06/factory_present.tscn"
const ITEM: String = "dmitry_recorder"

var _photo_directory: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_photo_directory = argument.trim_prefix("--capture=")
	create_timer(70.0).timeout.connect(func() -> void:
		push_error("S06 TEST TIMEOUT")
		quit(2))
	_run.call_deferred()


func _run() -> void:
	var state: Node = root.get_node("GameState")
	var saves: Node = root.get_node("SaveGame")
	var hud: Node = root.get_node("Hud")
	for index: int in 3:
		state.new_game()
		change_scene_to_file(SCENE)
		await scene_changed
		var scene: Node = current_scene
		var player: Node3D = scene.get_node("Player")
		var torch: Node3D = player.get_node("HandTorch")
		var beam: SpotLight3D = player.get_node("WarehouseBeam")
		var start_x: float = player.position.x
		var hand_at_rest: Vector3 = torch.position
		var beam_at_entry: Transform3D = beam.global_transform
		if index == 0:
			await create_timer(3.2).timeout
			await _capture("arrival")
		var flashlight_key: InputEventKey = InputEventKey.new()
		flashlight_key.physical_keycode = KEY_F
		flashlight_key.pressed = true
		scene.call("_unhandled_input", flashlight_key)
		if beam.visible:
			_fail("F did not switch the flashlight off")
			return
		scene.call("_unhandled_input", flashlight_key)
		if not beam.visible:
			_fail("F did not switch the flashlight back on")
			return
		if index == 2:
			await _inspect(scene, player, -10.4)
			if not state.get_flag("factory_mikhail_pulse_checked", false):
				_fail("checking Mikhail did not register")
				return
			await _inspect(scene, player, -7.15)
			if state.has_item("bandage") or not state.get_flag("factory_fyodor_bandaged", false):
				_fail("bandaging Fyodor did not consume one bandage")
				return
			if not _photo_directory.is_empty():
				await create_timer(0.3).timeout
				await _capture("bandaged")
		Input.action_press("move_right")
		Input.action_press("run")
		var animated_torch: bool = false
		while not bool(scene.get("_talking")):
			animated_torch = animated_torch or not torch.position.is_equal_approx(hand_at_rest)
			await process_frame
		Input.action_release("run")
		Input.action_release("move_right")
		if player.position.x <= start_x or not scene.get("_noticed_factory") or not scene.get("_noticed_mikhail") or not scene.get("_noticed_fyodor"):
			_fail("movement did not reach all three observations")
			return
		if not animated_torch or beam.global_transform.is_equal_approx(beam_at_entry):
			_fail("the torch and its light should travel with Alexei")
			return
		var focus: TextureRect = scene.get_node("UI/Root/RecorderFocus")
		var saw_recorder: bool = false
		var pressed_choice: bool = false
		while bool(scene.get("_talking")):
			if focus.visible and not saw_recorder:
				saw_recorder = true
				if index == 0:
					await create_timer(0.4).timeout
					await _capture("recorder")
			var choices: PanelContainer = scene.get_node_or_null("UI/Root/RecorderChoices")
			if choices != null and not pressed_choice:
				if index == 0:
					await create_timer(0.3).timeout
					await _capture("choices")
				var button: Button = choices.get_child(0).get_child(index)
				button.pressed.emit()
				pressed_choice = true
			if bool(scene.get("_waiting")):
				var event: InputEventAction = InputEventAction.new()
				event.action = "ui_accept"
				event.pressed = true
				scene.call("_unhandled_input", event)
			await process_frame
		var should_receive: bool = index == 2
		if not saw_recorder or not pressed_choice or bool(state.has_item(ITEM)) != should_receive or bool(state.get_flag("argument_3", false)) != should_receive:
			_fail("wrong outcome for choice %d" % (index + 1))
			return
		if should_receive:
			var toast_found: bool = false
			for label: Label in hud.get("_toasts").find_children("*", "Label", true, false):
				toast_found = toast_found or label.text == "Взято: Диктофон Дмитрия"
			if not toast_found:
				_fail("missing standard item pickup notification")
				return
			if not _photo_directory.is_empty():
				await create_timer(0.25).timeout
				await _capture("pickup")
		if not await saves.load_slot("auto"):
			_fail("could not reload the result")
			return
		if int(state.get_flag("factory_recorder_choice", -1)) != index or bool(state.has_item(ITEM)) != should_receive or bool(current_scene.get("_talking")):
			_fail("wrong restored result for choice %d" % (index + 1))
			return
		if bool(current_scene.get_node("Fyodor/Bandage").visible) != (index == 2):
			_fail("optional bandaging did not restore correctly")
			return
	print("S06 FACTORY: OK (all three choices and reload)")
	quit()


func _inspect(scene: Node, player: Node3D, x: float) -> void:
	player.position.x = x
	await process_frame
	await process_frame
	var action: InputEventAction = InputEventAction.new()
	action.action = "interact"
	action.pressed = true
	scene.call("_unhandled_input", action)
	while bool(scene.get("_interacting")):
		await process_frame


func _capture(name: String) -> void:
	if _photo_directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_photo_directory.path_join(name + ".png"))


func _fail(message: String) -> void:
	push_error("S06 FACTORY: " + message)
	quit(1)
