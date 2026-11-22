class_name BossPlayer
extends CharacterBody3D
## Босс-арена: игрок с WASD, рывок (Space/Shift) и стрельба по 3D-мишеням.
## Капсула 1.7 м (ноги Y=0), Visual — BoxMesh 0.5×1.7×0.2 + ствол.
## Ввод: move_left/right/up/down (WASD), boss_dash (Space/Shift), combat_shoot (ЛКМ), combat_reload (R).
## Ходьба по X и Z (speed = 4.8), границы arena_min = (-10, -3.2), arena_max = (10, 3.2), гравитация по Y.
## Рывок: dash_speed = 13.5 на 0.22с, неуязвимость 0.3с (Visual мигает), КД 0.85с.
## Пистолет: max_health = 100, ammo_max = 6, перезарядка 1.5с (ReloadTimer).
## Прицел: PhysicsRay по слою 128 (BossTarget) — пуля летит в центр мишени; иначе — в Plane(Vector3.UP, 1.15).
## Пуля: scenes/gameplay/bullet.tscn, mask = 1|4|128. При попадании вызываем take_bullet_hit() у цели.
## Сигналы: died, health_changed, ammo_changed, reload_started, reload_finished, dash_started.

signal died
signal health_changed(health: int, max_health: int)
signal ammo_changed(current: int, max: int)
signal reload_started
signal reload_finished
signal dash_started

const BulletScene: PackedScene = preload("res://scenes/gameplay/bullet.tscn")

## Слои: 1 = World, 2 = Player, 4 = Cover, 128 = BossTarget
const STICK_TO_FLOOR: float = -0.1
const CHEST_HEIGHT: float = 1.15
const MUZZLE_OFFSET: float = 0.35

@export var speed: float = 4.8
@export var max_health: int = 100
@export var ammo_max: int = 6
@export var gravity: float = 18.0
@export var reload_time: float = 1.5
@export var dash_speed: float = 13.5
@export var dash_duration: float = 0.22
@export var dash_invuln_time: float = 0.3
@export var dash_cooldown: float = 0.85
@export var arena_min: Vector2 = Vector2(-10.0, -3.2)
@export var arena_max: Vector2 = Vector2(10.0, 3.2)

var health: int = 0
var ammo_current: int = 0
var is_reloading: bool = false
var is_dashing: bool = false
var is_invulnerable: bool = false

var _visual: Node3D
var _barrel: Node3D
var _aim_marker: Node3D
var _reload_timer: Timer
var _dash_timer: Timer
var _dash_cooldown_timer: Timer
var _invuln_timer: Timer
var _blink_timer: Timer
var _dash_direction: Vector3 = Vector3.ZERO

var _hovered_target: Node3D = null
const TARGET_LOCK_PIXELS: float = 60.0
var _aim_marker_original_color: Color

func _ready() -> void:
	add_to_group("player")
	_ensure_input_actions()
	_ensure_timers()
	_visual = get_node_or_null("Visual") as Node3D
	_barrel = get_node_or_null("Visual/Barrel") as Node3D
	_aim_marker = get_node_or_null("AimMarker") as Node3D
	if _aim_marker != null:
		_aim_marker.visible = true
		_aim_marker.top_level = true
		if _aim_marker.material_override is StandardMaterial3D:
			_aim_marker_original_color = (_aim_marker.material_override as StandardMaterial3D).albedo_color
	
	health = max_health
	health_changed.emit(health, max_health)
	ammo_current = ammo_max
	ammo_changed.emit(ammo_current, ammo_max)
	
	# Настройка коллизии капсулы
	var collision: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision.shape as CapsuleShape3D
		capsule.height = 1.7
		capsule.radius = 0.25

func _ensure_input_actions() -> void:
	# move_left/right/up/down (WASD) — может уже существовать от других систем
	for pair: Array in [
		["move_left", [KEY_A, KEY_LEFT]],
		["move_right", [KEY_D, KEY_RIGHT]],
		["move_up", [KEY_W, KEY_UP]],
		["move_down", [KEY_S, KEY_DOWN]],
	]:
		var action: String = pair[0]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for code: int in pair[1]:
				var ev: InputEventKey = InputEventKey.new()
				ev.physical_keycode = code
				InputMap.action_add_event(action, ev)
	
	# boss_dash (Space/Shift)
	if not InputMap.has_action("boss_dash"):
		InputMap.add_action("boss_dash")
		for code: int in [KEY_SPACE, KEY_SHIFT]:
			var ev: InputEventKey = InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event("boss_dash", ev)
	
	# combat_shoot (ЛКМ), combat_reload (R)
	if not InputMap.has_action("combat_shoot"):
		InputMap.add_action("combat_shoot")
		var ev_mouse: InputEventMouseButton = InputEventMouseButton.new()
		ev_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("combat_shoot", ev_mouse)
	
	if not InputMap.has_action("combat_reload"):
		InputMap.add_action("combat_reload")
		var ev_r: InputEventKey = InputEventKey.new()
		ev_r.physical_keycode = KEY_R
		InputMap.action_add_event("combat_reload", ev_r)

func _ensure_timers() -> void:
	# ReloadTimer
	_reload_timer = get_node_or_null("ReloadTimer") as Timer
	if _reload_timer == null:
		_reload_timer = Timer.new()
		_reload_timer.name = "ReloadTimer"
		add_child(_reload_timer)
	_reload_timer.one_shot = true
	_reload_timer.wait_time = reload_time
	if not _reload_timer.timeout.is_connected(_on_reload_timeout):
		_reload_timer.timeout.connect(_on_reload_timeout)
	
	# DashTimer
	_dash_timer = get_node_or_null("DashTimer") as Timer
	if _dash_timer == null:
		_dash_timer = Timer.new()
		_dash_timer.name = "DashTimer"
		add_child(_dash_timer)
	_dash_timer.one_shot = true
	_dash_timer.wait_time = dash_duration
	if not _dash_timer.timeout.is_connected(_on_dash_timeout):
		_dash_timer.timeout.connect(_on_dash_timeout)
	
	# DashCooldownTimer
	_dash_cooldown_timer = get_node_or_null("DashCooldownTimer") as Timer
	if _dash_cooldown_timer == null:
		_dash_cooldown_timer = Timer.new()
		_dash_cooldown_timer.name = "DashCooldownTimer"
		add_child(_dash_cooldown_timer)
	_dash_cooldown_timer.one_shot = true
	_dash_cooldown_timer.wait_time = dash_cooldown
	if not _dash_cooldown_timer.timeout.is_connected(_on_dash_cooldown_timeout):
		_dash_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
	
	# InvulnTimer
	_invuln_timer = get_node_or_null("InvulnTimer") as Timer
	if _invuln_timer == null:
		_invuln_timer = Timer.new()
		_invuln_timer.name = "InvulnTimer"
		add_child(_invuln_timer)
	_invuln_timer.one_shot = true
	_invuln_timer.wait_time = dash_invuln_time
	if not _invuln_timer.timeout.is_connected(_on_invuln_timeout):
		_invuln_timer.timeout.connect(_on_invuln_timeout)
	
	# BlinkTimer (для мигания Visual во время неуязвимости)
	_blink_timer = get_node_or_null("BlinkTimer") as Timer
	if _blink_timer == null:
		_blink_timer = Timer.new()
		_blink_timer.name = "BlinkTimer"
		add_child(_blink_timer)
	_blink_timer.one_shot = false
	_blink_timer.wait_time = 0.05
	if not _blink_timer.timeout.is_connected(_on_blink_timeout):
		_blink_timer.timeout.connect(_on_blink_timeout)

func _physics_process(delta: float) -> void:
	if health <= 0:
		return
	
	var move_input: Vector2 = Vector2.ZERO
	if not is_dashing:
		move_input.x = Input.get_axis("move_left", "move_right")
		move_input.y = Input.get_axis("move_up", "move_down")  # W = -Z (вверх/вглубь), S = +Z (вниз/ближе)
	
	if is_dashing:
		velocity.x = _dash_direction.x * dash_speed
		velocity.z = _dash_direction.z * dash_speed
	else:
		velocity.x = move_input.x * speed
		velocity.z = move_input.y * speed
	
	# Гравитация
	if is_on_floor():
		velocity.y = STICK_TO_FLOOR
	else:
		velocity.y -= gravity * delta
	
	move_and_slide()
	
	# Ограничение арены
	var pos: Vector3 = global_position
	pos.x = clampf(pos.x, arena_min.x, arena_max.x)
	pos.z = clampf(pos.z, arena_min.y, arena_max.y)
	global_position = pos
	
	# Обновление прицела
	_update_aim()
	
	# Поворот визуала по направлению движения или прицелу
	if not is_dashing and move_input.length_squared() > 0.001:
		_face_direction(move_input.x, move_input.y)
	elif not is_dashing:
		_face_towards_aim()

func _unhandled_input(event: InputEvent) -> void:
	if health <= 0:
		return
	
	if event.is_action_pressed("boss_dash") and not is_dashing and _dash_cooldown_timer.is_stopped():
		_start_dash()
	elif event.is_action_pressed("combat_shoot"):
		shoot()
	elif event.is_action_pressed("combat_reload"):
		reload()

func _start_dash() -> void:
	var move_input: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	
	if move_input.length_squared() < 0.001:
		# Если не ходим — рвёмся в направлении прицела
		var aim_dir: Vector3 = _get_aim_direction_flat()
		_dash_direction = Vector3(aim_dir.x, 0.0, aim_dir.z).normalized()
	else:
		_dash_direction = Vector3(move_input.x, 0.0, move_input.y).normalized()
	
	is_dashing = true
	is_invulnerable = true
	_dash_timer.start(dash_duration)
	_invuln_timer.start(dash_invuln_time)
	_dash_cooldown_timer.start(dash_cooldown)
	_blink_timer.start()
	dash_started.emit()

func _on_dash_timeout() -> void:
	is_dashing = false
	if _blink_timer != null:
		_blink_timer.stop()

func _on_dash_cooldown_timeout() -> void:
	# Кулдаун истёк, можно рваться снова
	pass

func _on_invuln_timeout() -> void:
	is_invulnerable = false
	if _visual != null:
		_visual.visible = true

func _on_blink_timeout() -> void:
	if _visual != null and is_invulnerable:
		_visual.visible = not _visual.visible

func _update_aim() -> void:
	var aim_point: Vector3 = _get_aim_point()
	if _aim_marker != null:
		_aim_marker.global_position = aim_point
	if _barrel != null:
		_aim_barrel(aim_point)

func _get_aim_point() -> Vector3:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var mouse: Vector2 = get_viewport().get_mouse_position() if is_inside_tree() else Vector2.ZERO
	
	# 1) Проверяем цели в группе "boss_targets" через unproject_position
	if cam != null and is_inside_tree():
		var best_target: Node3D = null
		var best_dist: float = TARGET_LOCK_PIXELS
		
		for target in get_tree().get_nodes_in_group("boss_targets"):
			if not is_instance_valid(target) or target.is_queued_for_deletion():
				continue
			var target_3d: Node3D = target as Node3D
			var screen_pos: Vector2 = cam.unproject_position(target_3d.global_position)
			if screen_pos == Vector2(-1, -1):  # за камерой
				continue
			var dist: float = screen_pos.distance_to(mouse)
			if dist < best_dist:
				best_dist = dist
				best_target = target_3d
		
		if best_target != null:
			_set_hovered_target(best_target)
			return best_target.global_position
	
	# 2) Фоллбэк: луч с collide_with_areas=true по слою 128
	if cam != null:
		var origin: Vector3 = cam.project_ray_origin(mouse)
		var dir: Vector3 = cam.project_ray_normal(mouse)
		var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + dir * 100.0)
		query.collision_mask = 128
		query.collide_with_areas = true
		query.exclude = [get_rid()]
		var result: Dictionary = space_state.intersect_ray(query)
		if result:
			var hit_pos: Vector3 = result.position
			_clear_hovered_target()
			return hit_pos
		
		# 3) Плоскость Y = CHEST_HEIGHT
		var plane: Plane = Plane(Vector3.UP, CHEST_HEIGHT)
		var hit: Variant = plane.intersects_ray(origin, dir)
		if hit != null:
			var point: Vector3 = hit as Vector3
			point.y = CHEST_HEIGHT
			_clear_hovered_target()
			return point
	
	# Фоллбэк: перед игроком
	_clear_hovered_target()
	return global_position + Vector3(0.0, CHEST_HEIGHT, 0.0) + _get_facing_direction_3d() * 5.0

func _set_hovered_target(target: Node3D) -> void:
	if _hovered_target == target:
		return
	_hovered_target = target
	if _aim_marker != null and _aim_marker.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _aim_marker.material_override as StandardMaterial3D
		mat.albedo_color = Color(1, 0.0, 0.0, 1)
		mat.emission = Color(1, 0.0, 0.0, 1)
		mat.emission_energy_multiplier = 8.0

func _clear_hovered_target() -> void:
	if _hovered_target == null:
		return
	_hovered_target = null
	if _aim_marker != null and _aim_marker.material_override is StandardMaterial3D:
		var mat: StandardMaterial3D = _aim_marker.material_override as StandardMaterial3D
		mat.albedo_color = _aim_marker_original_color
		mat.emission = Color(1, 0.1, 0.1, 1)
		mat.emission_energy_multiplier = 3.0

func _get_aim_direction_flat() -> Vector3:
	var aim_point: Vector3 = _get_aim_point()
	var from: Vector3 = Vector3(global_position.x, CHEST_HEIGHT, global_position.z)
	var dir: Vector3 = (aim_point - from).normalized()
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = _get_facing_direction_3d()
	return dir

func _get_facing_direction_3d() -> Vector3:
	if _visual != null:
		var scale_x: float = _visual.scale.x
		if scale_x < 0:
			return Vector3.LEFT
	return Vector3.RIGHT

func _face_direction(move_x: float, move_z: float) -> void:
	if _visual == null:
		return
	if move_x != 0.0:
		_visual.scale.x = abs(_visual.scale.x) * (-1.0 if move_x < 0.0 else 1.0)
	# Z не влияет на scale.x, но можно добавить легкий наклон ствола

func _face_towards_aim() -> void:
	var aim_point: Vector3 = _get_aim_point()
	var dir_x: float = aim_point.x - global_position.x
	if _visual != null and not is_zero_approx(dir_x):
		_visual.scale.x = abs(_visual.scale.x) * (-1.0 if dir_x < 0.0 else 1.0)

func _aim_barrel(target_point: Vector3) -> void:
	if _barrel == null:
		return
	var from: Vector3 = _barrel.global_position
	var dir: Vector3 = (target_point - from).normalized()
	_barrel.look_at(from + dir, Vector3.UP)

func shoot() -> void:
	if health <= 0 or is_reloading or is_dashing:
		return
	if ammo_current <= 0:
		print("Click")
		return
	
	ammo_current -= 1
	ammo_changed.emit(ammo_current, ammo_max)
	
	var from: Vector3 = Vector3(global_position.x, CHEST_HEIGHT, global_position.z)
	var direction: Vector3
	var target: Node3D = null
	
	if _hovered_target != null and is_instance_valid(_hovered_target):
		target = _hovered_target
		direction = (target.global_position - from).normalized()
	else:
		var aim_point: Vector3 = _get_aim_point()
		direction = (aim_point - from).normalized()
	
	# Поворот к цели
	if _visual != null and not is_zero_approx(direction.x):
		_visual.scale.x = abs(_visual.scale.x) * (-1.0 if direction.x < 0.0 else 1.0)
	
	_spawn_bullet(direction, target)

func _spawn_bullet(direction: Vector3, target: Node3D = null) -> void:
	var world: Node = get_tree().current_scene
	if world == null:
		world = get_parent()
	if world == null:
		return
	
	var at: Vector3 = Vector3(global_position.x, CHEST_HEIGHT, global_position.z) + direction * MUZZLE_OFFSET
	var bullet: Node3D = BulletScene.instantiate() as Node3D
	var parent_3d: Node3D = world as Node3D
	if parent_3d != null:
		bullet.position = parent_3d.to_local(at)
	else:
		bullet.global_position = at
	
	# Настраиваем пулю: маска 1|4|128 = 133, передаём цель как intended_target
	if bullet.has_method("configure"):
		bullet.call("configure", direction, false, 25, 40.0, target)
	# Явно ставим маску для босс-арены (World|Cover|BossTarget)
	bullet.collision_mask = 1 | 4 | 128
	
	world.add_child(bullet)

func reload() -> void:
	if is_reloading or health <= 0 or ammo_current >= ammo_max:
		return
	is_reloading = true
	_reload_timer.start(reload_time)
	reload_started.emit()

func _on_reload_timeout() -> void:
	is_reloading = false
	if health <= 0:
		return
	ammo_current = ammo_max
	ammo_changed.emit(ammo_current, ammo_max)
	reload_finished.emit()

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0 or is_invulnerable:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health == 0:
		_die()

func _die() -> void:
	if _reload_timer != null:
		_reload_timer.stop()
	velocity = Vector3.ZERO
	died.emit()

func is_alive() -> bool:
	return health > 0