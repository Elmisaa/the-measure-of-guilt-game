extends SceneTree

const SAFETY_TIMEOUT: float = 200.0
var _shots: bool = "--shots" in OS.get_cmdline_user_args()
var _choice: String = "2"


func _init() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--choice="):
			_choice = a.substr(9)
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
	root.get_texture().get_image().save_png("res://art/previews/s04_ivan_" + name + ".png")


func _drive_talk(t: Node, shots_at: Dictionary) -> Array[String]:
	var seen: Array[String] = []
	var guard: int = 0
	while current_scene == t and guard < 6000:
		guard += 1
		var n: String = str(t.get("step_name"))
		var i: int = int(t.get("_i"))
		if shots_at.has(i):
			shots_at.erase(i)
			await _wait(0.6)
			await _shot("talk_%d_%s" % [i, n.replace(":", "_")])
		if seen.is_empty() or seen[-1] != n:
			seen.append(n)
		if n == "choice" and t.get("_choice_box") != null and is_instance_valid(t.get("_choice_box")) and str(t.get("_choice_made")) == "":
			await _wait(0.4)
			await _shot("talk_choice")
			t.set("_choice_made", _choice)
		if bool(t.get("_wait_click")):
			var tw: Tween = t.get("_typing")
			if tw and tw.is_running():
				tw.kill()
				t.get("_text").visible_ratio = 1.0
			if n == "notebook":
				await _wait(0.4)
				await _shot("talk_notebook")
			await _wait(0.05)
			t.set("_wait_click", false)
		await process_frame
	return seen


func _run() -> void:
	var ok: bool = true
	var gs: Node = root.get_node("GameState")
	gs.new_game()
	gs.set_flag("coat_on", true)
	gs.set_flag("ivan_flat_slow_reveal", true)
	change_scene_to_file("res://scenes/s04/ivan_flat.tscn")
	await _wait(1.5)
	await _shot("0_reveal")
	await _wait(3.0)
	var f: Node = current_scene
	var pl: Node3D = f.get_node("Player")
	var sprite: Sprite3D = pl.get_node("AnimatedSprite")
	var camera: Camera3D = root.get_camera_3d()
	if not sprite.shaded or not is_equal_approx(camera.size, 5.6):
		push_error("FAIL sprite lighting and camera scale should match the Ivan playtest"); ok = false
	if not (f.get_node("Ivan") as Sprite3D).shaded:
		push_error("FAIL Ivan sprite has to respond to room lights"); ok = false
	for x: float in [-13.5, -4.4, 3.9, 11.0]:
		pl.position.x = x
		await _wait(0.4)
		var pr: Button = f.get("_prompt")
		if not pr.visible:
			push_error("FAIL no prompt at x=%.1f" % x); ok = false
		await _shot("x_%d" % int(x))
	pl.position.x = 3.9
	await _wait(0.3)
	f.call("_interact", "ivan")
	await _wait(1.6)
	var t: Node = current_scene
	if t == null or t.name != "IvanTalk":
		push_error("FAIL talk did not start: %s" % [t]); quit(1); return
	var seen: Array[String] = await _drive_talk(t, {3: 1, 6: 1, 12: 1, 27: 1, 29: 1, 45: 1, 47: 1, 50: 1, 51: 1, 52: 1})
	for need: String in ["choice", "punch"]:
		if not seen.has(need):
			push_error("FAIL talk skipped %s" % need); ok = false
	if (_choice == "2") != gs.has_item("journal") or (_choice == "2") != bool(gs.get_flag("argument_2", false)):
		push_error("FAIL journal item vs choice %s" % _choice); ok = false
	await _wait(1.6)
	var f2: Node = current_scene
	if f2 == null or f2.name != "IvanFlat" or not bool(f2.get("_after")):
		push_error("FAIL not back in Ivan's flat after the talk: %s" % [f2]); quit(1); return
	await _shot("after")
	await _wait(0.4)
	var leave_button: Button = f2.get("_leave_button")
	if current_scene != f2 or not leave_button.visible or leave_button.text != "Отправиться на завод":
		push_error("FAIL factory action missing after the dialogue"); quit(1); return
	leave_button.pressed.emit()
	await _wait(1.5)
	var flashback: Node = current_scene
	var letterbox: Node = root.get_node("Letterbox")
	if flashback == null or flashback.name != "FactoryFlashback" or letterbox.is_shown():
		push_error("FAIL factory action did not open a full-frame flashback"); quit(1); return
	var caption: Label = flashback.get_node("Fade/Caption")
	if not caption.visible or caption.visible_characters <= 0:
		push_error("FAIL flashback caption did not start typing"); ok = false
	await _shot("flashback_intro")
	var mikhail: Sprite3D = flashback.get_node("Mikhail")
	var fyodor: Sprite3D = flashback.get_node("Fyodor")
	var overhead: OmniLight3D = flashback.get_node("Overhead")
	var lit_lamp: Sprite3D = flashback.get_node("Room/Props/LampFarLeft")
	var saw_final_pose: bool = false
	var dialogue: Array[String] = []
	var last_speaker: String = ""
	while current_scene == flashback:
		if bool(flashback.get("_awaiting_dialogue")):
			var speaker: Label = flashback.get_node("UI/Speech/Speaker")
			var entity_speech: Control = flashback.get_node_or_null("UI/EntityOverlay/EntitySpeech")
			var current_speaker: String = "Сущность" if entity_speech != null else speaker.text
			if current_speaker != last_speaker:
				last_speaker = current_speaker
				dialogue.append(last_speaker)
				if dialogue.size() == 1 or last_speaker == "Сущность":
					await _wait(0.7)
					await _shot("flashback_" + str(dialogue.size()))
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			Input.parse_input_event(click)
			await _wait(0.08)
			click = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = false
			Input.parse_input_event(click)
		if not saw_final_pose and mikhail.frame == 7 and fyodor.frame == 1 and overhead.light_energy == 0.0 and lit_lamp.material_override == null:
			saw_final_pose = true
			await _wait(0.36)
			await _shot("flashback_end")
		await process_frame
	if not saw_final_pose:
		push_error("FAIL flashback did not reach the psychic strike under moonlight"); ok = false
	if dialogue != ["Дмитрий", "Отец", "Михаил", "Отец", "Дмитрий", "Сущность"]:
		push_error("FAIL flashback dialogue sequence: %s" % [dialogue]); ok = false
	await _wait(0.3)
	if current_scene == null or current_scene.name != "FactoryPresent":
		push_error("FAIL flashback did not lead to the present-time factory: %s" % [current_scene]); ok = false
	if letterbox.is_shown():
		push_error("FAIL flashback bars remained on the title"); ok = false
	print("S04 IVAN (%s): %s" % [_choice, "OK" if ok else "FAILED"])
	quit(0 if ok else 1)
