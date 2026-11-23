extends SceneTree

const SAFETY_TIMEOUT: float = 30.0

var _ok: bool = true

func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))

func _fail(message: String) -> void:
	push_error("FAIL " + message)
	_ok = false

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _frames(count: int) -> void:
	for i in count:
		await process_frame

func _run() -> void:
	var arena_scene: PackedScene = load("res://scenes/gameplay/_test_arena_full.tscn") as PackedScene
	_check(arena_scene != null, "_test_arena_full.tscn did not load")
	if arena_scene == null:
		print("ARENA FULL TEST: FAILED")
		quit(1)

	var arena: Node = arena_scene.instantiate()
	_check(arena != null, "arena scene instantiation failed")
	root.add_child(arena)
	await _frames(4)

	var player: Node = arena.get_node_or_null("Player")
	_check(player != null, "arena has no Player")
	_check(player.is_in_group("player"), "Player not in 'player' group")

	var melee: Node = arena.get_node_or_null("EnemyMelee")
	_check(melee != null, "arena has no EnemyMelee")
	_check(melee.is_in_group("enemies"), "EnemyMelee not in 'enemies' group")

	var shooter1: Node = arena.get_node_or_null("EnemyShooter1")
	_check(shooter1 != null, "arena has no EnemyShooter1")
	_check(shooter1.is_in_group("enemies"), "EnemyShooter1 not in 'enemies' group")

	var shooter2: Node = arena.get_node_or_null("EnemyShooter2")
	_check(shooter2 != null, "arena has no EnemyShooter2")
	_check(shooter2.is_in_group("enemies"), "EnemyShooter2 not in 'enemies' group")

	var hud: Node = arena.get_node_or_null("CombatHud")
	_check(hud != null, "arena has no CombatHud")

	var covers: int = 0
	for child: Node in arena.get_children():
		if child is StaticBody3D and child.get("is_destructible") != null:
			covers += 1
	_check(covers >= 3, "arena has less than 3 covers: %d" % covers)

	var encounter_node: Node = arena.get_node_or_null("CombatEncounter")
	_check(encounter_node != null, "arena has no CombatEncounter node")
	var encounter_script: Script = encounter_node.get_script()
	_check(encounter_script != null and encounter_script.get_global_name() == "CombatEncounter",
		"CombatEncounter node does not have CombatEncounter script")

	var camera: Camera3D = arena.get_node_or_null("Camera3D") as Camera3D
	_check(camera != null, "arena has no Camera3D")
	var camera_script: Script = camera.get_script()
	_check(camera_script != null and camera_script.get_global_name() == "CombatCamera",
		"Camera3D does not have CombatCamera script")

	_check(player.flashlight_enabled == true, "Player.flashlight_enabled is not true")

	var initial_camera_x: float = camera.global_position.x
	var initial_player_x: float = player.global_position.x
	player.global_position.x = initial_player_x + 5.0
	await _frames(2)
	var camera_x_after_move: float = camera.global_position.x
	_check(camera_x_after_move > initial_camera_x, "Camera did not follow player right: %.2f -> %.2f" % [initial_camera_x, camera_x_after_move])

	player.health = 0
	player.died.emit()
	await _frames(4)
	var banner_found: bool = false
	if encounter_node != null:
		for child: Node in encounter_node.get_children():
			if child is CanvasLayer and child.layer == 60:
				banner_found = true
				break
	_check(banner_found, "Death banner CanvasLayer (layer 60) not found after player death")

	arena.queue_free()
	await _frames(2)

	print("ARENA FULL TEST: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)