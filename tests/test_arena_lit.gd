extends SceneTree
## Smoke test for _test_arena_lit.tscn: loads scene, verifies no flashlight, bright enough.

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
	var arena_scene: PackedScene = load("res://scenes/gameplay/_test_arena_lit.tscn") as PackedScene
	_check(arena_scene != null, "_test_arena_lit.tscn did not load")
	if arena_scene == null:
		print("ARENA LIT TEST: FAILED")
		quit(1)

	var arena: Node = arena_scene.instantiate()
	_check(arena != null, "arena scene instantiation failed")
	root.add_child(arena)
	await _frames(4)

	# Check Player has flashlight_enabled = false
	var player: Node = arena.get_node_or_null("Player")
	_check(player != null, "arena has no Player")
	_check(player.flashlight_enabled == false, "Player.flashlight_enabled should be false")

	# Check DirectionalLight3D has light_energy = 1.6
	var sun: DirectionalLight3D = arena.get_node_or_null("Sun") as DirectionalLight3D
	_check(sun != null, "arena has no Sun")
	_check(is_equal_approx(sun.light_energy, 1.6), "Sun light_energy should be 1.6, got %.2f" % sun.light_energy)

	# Check WorldEnvironment ambient settings
	var world_env: WorldEnvironment = arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_check(world_env != null, "arena has no WorldEnvironment")
	if world_env != null and world_env.environment != null:
		var env: Environment = world_env.environment
		_check(env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "ambient_light_source should be Color (2)")
		_check(is_equal_approx(env.ambient_light_energy, 0.45), "ambient_light_energy should be 0.45, got %.2f" % env.ambient_light_energy)
		# Check background is brighter than dark version
		_check(env.background_color.r > 0.05, "background should be brighter")

	arena.queue_free()
	await _frames(2)

	print("ARENA LIT TEST: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)