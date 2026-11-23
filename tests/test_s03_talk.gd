extends SceneTree

const SAFETY_TIMEOUT: float = 240.0
var _shots: bool = "--shots" in OS.get_cmdline_user_args()
var _choice: String = "b"


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
	root.get_texture().get_image().save_png("res://art/previews/s03_talk_%s_%s.png" % [_choice, name])


func _drive_talk(t: Node, shots_at: Dictionary) -> Array[String]:
	var seen: Array[String] = []
	var guard: int = 0
	var pressed_go: bool = false
	while current_scene == t and guard < 4000:
		guard += 1
		var n: String = str(t.get("step_name"))
		var i: int = int(t.get("_i"))
		if shots_at.has(i):
			shots_at.erase(i)
			await _wait(0.6)
			await _shot(str(i) + "_" + n.replace(":", "_"))
		if seen.is_empty() or seen[-1] != n:
			seen.append(n)
		if n == "end_call" and not pressed_go:
			var bt: Array = t.get("_ui").find_children("*", "Button", true, false)
			for b: Node in bt:
				if is_instance_valid(b) and (b as Button).text.contains("Ивану") and not (b as Button).disabled:
					pressed_go = true
					await _wait(0.5)
					await _shot("button")
					(b as Button).pressed.emit()
					break
		if n == "choice" and t.get("_choice_box") != null and is_instance_valid(t.get("_choice_box")) and str(t.get("_choice_made")) == "":
			await _wait(0.4)
			await _shot("choice")
			t.set("_choice_made", _choice)
		if bool(t.get("_wait_click")):
			var tw: Tween = t.get("_typing")
			if tw and tw.is_running():
				tw.kill()
				t.get("_text").visible_ratio = 1.0
			await _wait(0.05)
			t.set("_wait_click", false)
		await process_frame
	return seen


func _run() -> void:
	var ok: bool = true
	var gs: Node = root.get_node("GameState")
	gs.new_game()
	gs.set_flag("coat_on", true)
	gs.set_flag("penthouse_entered", true)
	change_scene_to_file("res://scenes/s03/penthouse.tscn")
	await _wait(3.4)
	var p: Node = current_scene
	p.call("_interact", "viktor")
	await _wait(0.5)
	if current_scene != p:
		push_error("FAIL talk started before the clues"); ok = false
	p.call("_interact", "shards")
	await _wait(0.2)
	p.call("_interact", "papers")
	await _wait(1.0)
	await _shot("0_papers")
	root.get_node("Hud").get("_closeup").close()
	await _wait(0.6)
	p.call("_interact", "viktor")
	await _wait(1.6)
	var t: Node = current_scene
	if t == null or t.name != "ViktorTalk":
		push_error("FAIL talk did not start: %s" % [t]); quit(1); return
	var seen: Array[String] = await _drive_talk(t, {5: 1, 13: 1, 16: 1, 23: 1, 27: 1, 34: 1, 51: 1, 56: 1, 60: 1, 64: 1, 67: 1, 70: 1, 73: 1, 74: 1})
	for need: String in ["choice", "entity_arrives", "gunshot", "viktor_falls"]:
		if not seen.has(need):
			push_error("FAIL talk skipped %s" % need); ok = false
	if bool(gs.get_flag("argument_1", false)) != (_choice == "b"):
		push_error("FAIL argument flag wrong"); ok = false
	if (_choice == "b") != gs.has_item("confession"):
		push_error("FAIL confession item after choice"); ok = false
	await _wait(1.6)
	var p2: Node = current_scene
	if p2 == null or p2.name != "Penthouse" or not bool(p2.get("_after")):
		push_error("FAIL not back in the dark penthouse: %s" % [p2]); quit(1); return
	await _shot("after_1")
	p2.call("_interact", "window")
	await _wait(1.8)
	var hud: Node = root.get_node("Hud")
	if hud.is_closeup_open():
		await _shot("after_view_down")
		hud.get("_closeup").close()
	await _wait(13.0 if _choice == "a" else 2.0)
	if not gs.has_item("confession"):
		push_error("FAIL no envelope after the window"); ok = false
	if not bool(p2.get("_ringing")):
		push_error("FAIL phone does not ring"); ok = false
	await _shot("after_2_ring")
	p2.call("_interact", "answer")
	await _wait(1.6)
	var c: Node = current_scene
	if c == null or c.name != "IvanCall":
		push_error("FAIL Ivan call did not start: %s" % [c]); quit(1); return
	await _drive_talk(c, {3: 1, 4: 1})
	await _wait(5.0)
	if current_scene == null or current_scene.name != "IvanFlat":
		push_error("FAIL call did not lead to Ivan's flat: %s" % [current_scene]); ok = false
	await _shot("ivan_reveal")
	print("S03 TALK (%s): %s" % [_choice, "OK" if ok else "FAILED"])
	quit(0 if ok else 1)
