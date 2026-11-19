extends SceneTree
## Smoke test for the player state machine.
## godot --headless --path . -s res://tests/test_player.gd

const PlayerScript: Script = preload("res://scripts/gameplay/player.gd")
const SAFETY_TIMEOUT: float = 30.0

var _ok: bool = true
var _died_count: int = 0


func _init() -> void:
	_run.call_deferred()
	create_timer(SAFETY_TIMEOUT).timeout.connect(func() -> void:
		push_error("TEST TIMEOUT")
		quit(2))


func _fail(message: String) -> void:
	push_error("FAIL " + message)
	_ok = false


## Process frames: input state is flushed by the main loop, not by physics_frame.
func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _key(keycode: Key, pressed: bool) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = keycode
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse(pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	Input.parse_input_event(event)


func _click() -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)


func _bullet_count(world: Node) -> int:
	var count: int = 0
	for child in world.get_children():
		if child is Area2D:
			count += 1
	return count


func _first_bullet(world: Node) -> Node2D:
	for child in world.get_children():
		if child is Area2D and child is Node2D:
			return child as Node2D
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _run() -> void:
	var world: Node2D = Node2D.new()
	world.name = "World"
	root.add_child(world)
	var scene: PackedScene = load("res://scenes/gameplay/player.tscn")
	var player: CharacterBody2D = scene.instantiate() as CharacterBody2D
	world.add_child(player)

	# Структура сцены
	_check(player.get_node_or_null("Visual/ColorRect") is ColorRect, "no ColorRect")
	_check(player.get_node_or_null("CollisionShape2D") is CollisionShape2D, "no CollisionShape2D")
	_check(player.get_node_or_null("Camera2D") is Camera2D, "no Camera2D")
	_check(player.max_health == 100, "max_health default is not 100")
	_check(player.health == 100, "health is not initialized to max")

	var visual: Node2D = player.get_node("Visual") as Node2D
	player.died.connect(func() -> void: _died_count += 1)

	# IDLE
	await _frames(3)
	_check(player.state == PlayerScript.State.IDLE, "expected IDLE, got %d" % player.state)

	# RUN влево: A
	_key(KEY_A, true)
	await _frames(4)
	_check(player.state == PlayerScript.State.RUN, "A did not switch to RUN")
	_check(player.velocity.x < 0.0, "A did not move left")
	_check(is_equal_approx(visual.scale.x, -1.0), "facing left is not scale.x = -1")
	_key(KEY_A, false)
	await _frames(5)
	_check(player.state == PlayerScript.State.IDLE, "release A did not return to IDLE")

	# RUN вправо: D (проверяем реальное перемещение тела, а не только velocity)
	var start_x: float = player.position.x
	_key(KEY_D, true)
	await _frames(10)
	_check(player.state == PlayerScript.State.RUN, "D did not switch to RUN")
	_check(player.velocity.x > 0.0, "D did not move right")
	_check(player.position.x > start_x + 4.0, "body did not move right: %.2f -> %.2f" % [start_x, player.position.x])
	_check(is_equal_approx(visual.scale.x, 1.0), "facing right is not scale.x = 1")

	# AIM по ПКМ (движение не отпускаем — но AIM приоритетнее)
	_mouse(true)
	await _frames(3)
	_check(player.state == PlayerScript.State.AIM, "RMB did not switch to AIM")
	var marker: Node2D = player.get_node("AimMarker") as Node2D
	var barrel: CanvasItem = player.get_node("Visual/Barrel") as CanvasItem
	_check(marker.visible, "aim marker is not visible in AIM")
	_check(barrel.visible, "barrel is not visible in AIM")
	_mouse(false)
	_key(KEY_D, false)
	await _frames(5)
	_check(player.state == PlayerScript.State.IDLE, "release RMB did not return to IDLE")
	_check(not marker.visible, "aim marker stayed visible after RMB release")
	_check(not barrel.visible, "barrel stayed visible after RMB release")

	# Стрелки работают так же, как A/D
	_key(KEY_RIGHT, true)
	await _frames(3)
	_check(player.state == PlayerScript.State.RUN, "RIGHT arrow did not switch to RUN")
	_key(KEY_RIGHT, false)
	_key(KEY_LEFT, true)
	await _frames(3)
	_check(player.state == PlayerScript.State.RUN, "LEFT arrow did not switch to RUN")
	_key(KEY_LEFT, false)
	await _frames(5)
	_check(player.state == PlayerScript.State.IDLE, "release LEFT arrow did not return to IDLE")

	# Клавиатурное «отпускание» не должно залипать в Input
	_check(not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT), "RMB stuck in Input")

	# Стрельба: ЛКМ тратит патрон, создаёт пулю и испускает shoot_fired
	_check(player.ammo_current == 17, "ammo_current default is not 17")
	var directions: Array[Vector2] = []
	player.shoot_fired.connect(func(direction: Vector2) -> void: directions.append(direction))
	_click()
	await _frames(3)
	_check(player.ammo_current == 16, "shot did not spend ammo")
	_check(directions.size() == 1, "shoot_fired emitted %d times" % directions.size())
	if directions.size() > 0:
		_check(is_equal_approx(directions[0].length(), 1.0), "shoot direction is not normalized")
	_check(_bullet_count(world) == 1, "bullet was not created")
	var bullet: Node2D = _first_bullet(world)
	if bullet != null:
		var bullet_start: Vector2 = bullet.position
		await _frames(6)
		_check(bullet.position.distance_to(bullet_start) > 1.0, "bullet does not fly")

	# Пустой магазин: выстрела и пули нет
	player.ammo_current = 0
	_click()
	await _frames(3)
	_check(player.ammo_current == 0, "shot fired with empty ammo")
	_check(_bullet_count(world) == 1, "bullet spawned with empty ammo")

	# Перезарядка по R: 1.5 с нельзя стрелять, потом полный магазин
	_key(KEY_R, true)
	_key(KEY_R, false)
	await _frames(2)
	_check(player.is_reloading, "R did not start reload")
	_click()
	await _frames(3)
	_check(player.ammo_current == 0, "shot during reload spent ammo")
	await create_timer(1.6).timeout
	_check(not player.is_reloading, "reload did not finish")
	_check(player.ammo_current == 17, "reload did not refill: %d" % player.ammo_current)

	# Пуля удаляется сама (lifetime 1.5 с)
	await create_timer(1.7).timeout
	_check(_bullet_count(world) == 0, "bullet did not free itself")

	# Урон и смерть
	player.take_damage(40)
	_check(player.health == 60, "take_damage: expected 60, got %d" % player.health)
	_check(_died_count == 0, "died fired too early")
	player.take_damage(60)
	_check(player.health == 0, "health did not reach 0")
	_check(_died_count == 1, "died fired %d times" % _died_count)
	player.take_damage(10)
	_check(_died_count == 1, "died fired again after death")

	print("PLAYER TEST: ", "OK" if _ok else "FAILED")
	player.queue_free()
	quit(0 if _ok else 1)
