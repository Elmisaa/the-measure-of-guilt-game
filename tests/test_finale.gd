extends SceneTree

const ARENA: String = "res://scenes/s07/final_arena.tscn"

func _initialize() -> void:
	create_timer(65.0).timeout.connect(func() -> void: fail("timeout"))
	run.call_deferred()

func run() -> void:
	var state: Node = root.get_node("GameState")
	state.new_game()
	state.set_flag("factory_recorder_choice", 2)
	state.set_flag("factory_player_x", -3.6)
	state.add_item("dmitry_recorder")
	state.set_flag("argument_1", false)
	state.add_item("confession")
	if state.has_item("confession"):
		fail("a rejected argument should not be granted")
		return
	var old_save: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	old_save["items"].append("confession")
	old_save["dropped_items"]["journal"] = {"scene": ARENA, "position": []}
	old_save["flags"]["argument_2"] = false
	state.from_dict(old_save)
	if state.owns_item("confession") or state.owns_item("journal") or not state.has_item("dmitry_recorder"):
		fail("an old save must discard invalid evidence and keep evidence the player earned")
		return
	change_scene_to_file("res://scenes/s06/factory_present.tscn")
	await scene_changed
	var factory: Node = current_scene
	if not factory.has_node("WorkshopEntrance/FrontPier/Collision"):
		fail("the approach needs the factory gate's side wall")
		return
	await process_frame
	await process_frame
	var next: Button = factory.get("_continue_button")
	if not next.visible:
		fail("factory exit isn't available after interviewing Dmitry")
		return
	next.pressed.emit()
	while current_scene == factory:
		if bool(factory.get("_waiting")):
			factory.set("_waiting", false)
			factory.emit_signal("advanced")
		await process_frame
	if current_scene == null:
		await scene_changed
	var arena: Node = current_scene
	if arena.scene_file_path != ARENA:
		fail("factory did not lead to the finale")
		return
	await create_timer(1.1).timeout
	var button: Button = arena.get("_next")
	if button.text != "› В бой":
		fail("the opening dialogue must display the full fight label")
		return
	var boss: BossScales = arena.get_node("BossScales")
	var player: BossPlayer = arena.get_node("BossPlayer")
	var conveyor: OverheadConveyor = arena.get_node("OverheadConveyor")
	await _escape()
	if not paused:
		fail("Esc must pause the arena intro")
		return
	await _escape()
	if paused or root.gui_get_focus_owner() != button:
		fail("resuming the intro must restore dialogue focus")
		return
	if player.global_position.x <= 0.0 or boss.boss_x <= player.global_position.x or not arena.has_node("Factory/MainHall"):
		fail("fight should start in the factory's right-hand workshop")
		return
	button.pressed.emit()
	await process_frame
	var mount: MeshInstance3D = conveyor._attachment_targets[0].get_node("TargetVisual")
	var resistance: Panel = arena.get_node("BossHud/ResistancePanel")
	if not mount.is_visible_in_tree() or not root.get_visible_rect().encloses(resistance.get_global_rect()):
		fail("the cargo target and resistance indicator must be visible")
		return
	if boss.current_resistance != 100 or not player.combat_enabled:
		fail("the first phase didn't start")
		return
	await _escape()
	var attack_time: float = boss._attack_timer.time_left
	await create_timer(0.2).timeout
	if not paused or attack_time <= 0.0 or not is_equal_approx(attack_time, boss._attack_timer.time_left):
		fail("pausing the fight must freeze its attack timer")
		return
	await _escape()
	if paused:
		fail("Esc must resume the fight")
		return
	boss._attack_timer.stop()
	var wall: CollisionShape3D = arena.get_node("Factory/MainHall/EastWall/WallCollision")
	if wall.shape == null or wall.disabled:
		fail("the eastern wall needs a solid collision shape")
		return
	player.ammo_current = 1
	player.shoot()
	if player.ammo_current != 0 or not player.is_reloading:
		fail("the last shot should start automatic reload")
		return
	await create_timer(player.reload_time + 0.1).timeout
	if player.is_reloading or player.ammo_current != player.ammo_max:
		fail("automatic reload did not refill the magazine")
		return
	player.ammo_current -= 1
	player.reload()
	if not player.is_reloading:
		fail("manual reload must work with a partly loaded magazine")
		return
	await create_timer(player.reload_time + 0.1).timeout
	boss._attack_shockwave()
	await create_timer(1.45).timeout
	if player.health >= player.max_health:
		fail("an unavoided shockwave should hurt Alexei")
		return
	await process_frame
	conveyor._carriages[0].position.x = conveyor.boss_x - conveyor.position.x
	conveyor.speed = 0.0
	var target: Node3D = conveyor._attachment_targets[0]
	var camera: Camera3D = arena.get_node("Camera3D")
	root.warp_mouse(camera.unproject_position(target.global_position))
	player._spawn_bullet((target.global_position - Vector3(player.position.x, 1.15, player.position.z)).normalized(), target)
	await create_timer(1.1).timeout
	if boss.current_resistance != 50:
		fail("a projectile hitting the crane attachment should break 50 resistance (got %s)" % boss.current_resistance)
		return
	boss._attack_throw_barrel()
	var barrel: ExplosiveBarrel = boss._barrels.back()
	var origin: Vector3 = player.global_position + Vector3.UP * 1.15
	player._spawn_bullet((barrel.global_position - origin).normalized(), barrel)
	await create_timer(0.8).timeout
	if boss.current_resistance != 25:
		fail("a projectile hitting a suspended barrel should break 25 resistance")
		return
	boss.apply_environment_damage(25)
	await process_frame
	if button.text != "› Далее":
		fail("the focused continue button must display the full label")
		return
	button.release_focus()
	if button.text != "  Далее":
		fail("the continue button must keep its label on focus loss")
		return
	button.grab_focus()
	if player.combat_enabled or int(arena.get("_phase")) != 1:
		fail("the first argument should pause combat")
		return
	button.pressed.emit()
	await process_frame
	if boss.current_resistance != 75:
		fail("without Victor's evidence, phase 2 must be fought")
		return
	boss.apply_environment_damage(75)
	await process_frame
	button.pressed.emit()
	await process_frame
	if boss.current_resistance != 100:
		fail("without Ivan's journal, phase 3 must be fought")
		return
	boss.apply_environment_damage(100)
	await process_frame
	button.pressed.emit()
	await process_frame
	if player.combat_enabled:
		fail("Dmitry's recording should skip phase 4")
		return
	for i: int in 3:
		button.pressed.emit()
		await process_frame
	await create_timer(3.3).timeout
	for i: int in 3:
		button.pressed.emit()
		await process_frame
	await create_timer(4.1).timeout
	var last_line: Label = arena.get("_line")
	if not last_line.text.begins_with("Вот она — настоящая справедливость") or button.is_visible_in_tree():
		fail("the final dialogue must be shown without a continue button")
		return
	await create_timer(8.0).timeout
	if current_scene == null or current_scene.scene_file_path != "res://scenes/menu/title.tscn":
		fail("epilogue didn't return to the menu")
		return
	await create_timer(0.4).timeout
	if not await check_evidence_matrix(state):
		return
	print("FINALE: OK (all 8 evidence combinations)")
	quit()


func check_evidence_matrix(state: Node) -> bool:
	var ids: Array[String] = ["confession", "journal", "dmitry_recorder"]
	var references: Array[String] = ["Виктор признался", "В журнале Ивана", "На записи Дмитрия"]
	for mask: int in range(8):
		state.new_game()
		for i: int in ids.size():
			# Also covers an earned document left on the ground.
			state.set_flag("argument_%d" % (i + 1), true)
			state.add_item(ids[i])
			if (mask & (1 << i)) == 0:
				state.drop_item(ids[i], ARENA, [2.0, 0.0, 0.0])
		change_scene_to_file(ARENA)
		await scene_changed
		await process_frame
		var room: Node = current_scene
		var next: Button = room.get("_next")
		var label: Label = room.get("_line")
		var boss: BossScales = room.get_node("BossScales")
		var player: BossPlayer = room.get_node("BossPlayer")
		next.pressed.emit()
		for i: int in ids.size():
			if player.combat_enabled:
				boss.apply_environment_damage(boss.current_resistance)
				await process_frame
			var evidence: bool = bool(mask & (1 << i))
			if player.combat_enabled or label.text.contains(references[i]) != evidence:
				fail("wrong dialogue for evidence %s in case %d" % [ids[i], mask])
				return false
			next.pressed.emit()
			await process_frame
			if player.combat_enabled == evidence:
				fail("wrong combat branch for %s in case %d" % [ids[i], mask])
				return false
		if player.combat_enabled:
			boss.apply_environment_damage(boss.current_resistance)
			await process_frame
		if not label.text.begins_with("Твоя цель"):
			fail("case %d did not reach the verdict" % mask)
			return false
	return true

func _escape() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release: InputEventKey = event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func fail(message: String) -> void:
	push_error("FINALE: " + message)
	quit(1)
