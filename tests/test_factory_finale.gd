extends SceneTree

const APPROACH: String = "res://scenes/s06/factory_present.tscn"
const FINALE: String = "res://scenes/s07/factory_finale.tscn"

var _phase_history: Array[int] = []
var _deflected: int = 0
var _barrel_windows: int = 0
var _attacks: Array[int] = []
var _passed: bool = true
var _capture_directory: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			_capture_directory = argument.trim_prefix("--capture=")
	create_timer(220.0).timeout.connect(func() -> void:
		push_error("FACTORY FINALE: timed out")
		quit(2))
	_run.call_deferred()


func _run() -> void:
	var state: Node = root.get_node("GameState")
	for with_evidence: bool in [true, false]:
		state.new_game()
		state.set_flag("factory_recorder_choice", 2 if with_evidence else 0)
		state.set_flag("factory_fyodor_warned", true)
		state.set_flag("factory_player_x", -4.1)
		if with_evidence:
			state.add_item("confession")
			state.set_flag("argument_2", true)
			state.add_item("dmitry_recorder")
		change_scene_to_file(APPROACH)
		await scene_changed
		await process_frame
		await process_frame
		_check(current_scene.get("_at_hall"), "the hall entrance should be available")
		var interact: InputEventAction = InputEventAction.new()
		interact.action = "interact"
		interact.pressed = true
		current_scene.call("_unhandled_input", interact)
		await scene_changed
		_check(current_scene.scene_file_path == FINALE, "the entrance should load the final workshop")
		var finale: Node = current_scene
		var boss: BossScales = finale.get_node("BossScales")
		var player: BossPlayer = finale.get_node("BossPlayer")
		_phase_history.clear()
		_attacks.clear()
		_deflected = 0
		_barrel_windows = 0
		boss.phase_started.connect(func(phase: int) -> void: _phase_history.append(phase))
		boss.attack_executed.connect(func(_phase: int, attack: int) -> void: _attacks.append(attack))
		boss.bullet_deflected.connect(func(_position: Vector3) -> void: _deflected += 1)
		boss.counter_window_opened.connect(func() -> void: _barrel_windows += 1)
		while not boss.story_phase_active:
			await _advance(finale)
		_check(_phase_history == [1], "the first fight is mandatory")
		var camera: Camera3D = finale.get_node("Camera")
		_check(is_equal_approx(camera.rotation_degrees.x, -27.0), "the combat camera should tilt 27 degrees")
		_check(player.health == 100 and player.ammo_current == 6, "the fight starts with full health and six cartridges")
		if with_evidence:
			await _capture("arena")
		var start: Vector3 = player.position
		Input.action_press("move_down")
		await create_timer(0.2).timeout
		Input.action_release("move_down")
		_check(player.position.z > start.z, "movement must use the depth of the arena")
		var action: InputEventAction = InputEventAction.new()
		action.action = "boss_dash"
		action.pressed = true
		player._unhandled_input(action)
		_check(player.is_dashing, "the combat dash must be available")
		await create_timer(0.35).timeout
		player.is_invulnerable = true
		var shield: Node3D = boss.get_node("BossBase/HitArea")
		_shoot(player, shield)
		await create_timer(0.6).timeout
		_check(_deflected == 1 and boss.current_resistance == 100, "a direct shot must deflect without changing resistance")
		while _barrel_windows == 0:
			await process_frame
		_check(not _attacks.is_empty() and _attacks[0] == 0, "spikes must be the first attack")
		if not with_evidence:
			var missed: ExplosiveBarrel = _floating_barrel()
			await create_timer(2.35).timeout
			_check(is_instance_valid(missed) and not missed.near_boss and not missed.get_node("TargetRing").visible,
				"an unanswered counter window must close and the barrel must be thrown")
			while _barrel_windows < 2:
				await process_frame
		var barrel: ExplosiveBarrel = _floating_barrel()
		_check(barrel != null and barrel.get_node("TargetRing").visible, "a floating counterattack target must be highlighted")
		if with_evidence:
			await _capture("counter")
		_shoot(player, barrel)
		await create_timer(0.6).timeout
		_check(boss.current_resistance == 75, "a shot on the floating barrel must reduce resistance by 25")
		while boss.story_phase_active:
			await process_frame
			var target: ExplosiveBarrel = _floating_barrel()
			if target != null and not target._is_exploding:
				if player.ammo_current == 0:
					player.reload()
				else:
					_shoot(player, target)
					await create_timer(0.45).timeout
		_check(player.controls_locked, "a broken phase must block movement and shooting")
		_check(not boss._attack_timer or boss._attack_timer.is_stopped(), "a broken phase must stop attacks")
		_finish_followup_phases(finale, boss)
		while is_instance_valid(finale):
			await _advance(finale)
		_check(_phase_history == ([1] if with_evidence else [1, 2, 3, 4]), "evidence should skip only the corresponding combat phases")
		_check(current_scene != null and current_scene.scene_file_path == APPROACH, "the ending should return to Fyodor")
		while not state.get_flag("factory_case_closed", false):
			await _advance(current_scene)
		_check(state.get_flag("factory_finale_return", false), "the arrest should follow the workshop finale")
		for index: int in range(1, 4):
			_check(state.get_flag("factory_final_argument_%d" % index, false), "the ending requires all three arguments")
		await process_frame
	current_scene.queue_free()
	await process_frame
	print("FACTORY FINALE: %s" % ("OK" if _passed else "FAILED"))
	quit(0 if _passed else 1)


func _finish_followup_phases(finale: Node, boss: BossScales) -> void:
	while is_instance_valid(finale):
		await process_frame
		if is_instance_valid(boss) and boss.story_phase_active and boss.current_phase > 1:
			boss.apply_environment_damage(50)
			await create_timer(1.0).timeout
			if is_instance_valid(boss):
				boss.apply_environment_damage(50)


func _floating_barrel() -> ExplosiveBarrel:
	for target: Node in get_nodes_in_group("boss_targets"):
		if target is ExplosiveBarrel and target.near_boss and not target.is_queued_for_deletion():
			return target
	return null


func _shoot(player: BossPlayer, target: Node3D) -> void:
	if target != null and not player.is_reloading:
		player._set_hovered_target(target)
		player.shoot()


func _advance(scene: Node) -> void:
	if is_instance_valid(scene) and scene.get("_waiting"):
		var event: InputEventAction = InputEventAction.new()
		event.action = "ui_accept"
		event.pressed = true
		scene.call("_unhandled_input", event)
	await process_frame


func _capture(name: String) -> void:
	if _capture_directory.is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_capture_directory.path_join(name + ".png"))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_passed = false
		push_error("FACTORY FINALE: " + message)
